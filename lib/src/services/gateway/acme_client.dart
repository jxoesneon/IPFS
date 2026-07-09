// lib/src/services/gateway/acme_client.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:pointycastle/asn1.dart' as asn1;
import 'package:pointycastle/export.dart' as pc;

import '../../utils/logger.dart';

/// A pending HTTP-01 challenge that the gateway must serve.
class AcmeHttp01Challenge {
  /// Creates a challenge descriptor.
  AcmeHttp01Challenge({
    required this.token,
    required this.keyAuthorization,
    required this.challengeUrl,
  });

  /// The challenge token provided by the ACME server.
  ///
  /// The gateway must serve [keyAuthorization] at
  /// `/.well-known/acme-challenge/$token`.
  final String token;

  /// The key authorization string to serve as the body of the challenge
  /// response.
  final String keyAuthorization;

  /// The ACME challenge URL to POST when ready for validation.
  final String challengeUrl;
}

/// Result of a successful ACME certificate issuance.
class AcmeCertificateResult {
  /// Creates a certificate result.
  AcmeCertificateResult({
    required this.certificatePem,
    required this.privateKeyPem,
    required this.notAfter,
  });

  /// PEM-encoded certificate chain (leaf + intermediates).
  final String certificatePem;

  /// PEM-encoded private key matching the certificate.
  final String privateKeyPem;

  /// Expiry date of the leaf certificate.
  final DateTime notAfter;
}

/// A functional ACME v2 (RFC 8555) client that performs HTTP-01 challenges.
///
/// This client implements the full certificate issuance flow:
/// 1. Fetch the ACME directory.
/// 2. Generate (or reuse) an RSA account key.
/// 3. Register the account with the ACME server.
/// 4. Create an order for the requested domain(s).
/// 5. Fetch the HTTP-01 challenge for each authorization.
/// 6. Expose the challenge token/key-auth so the gateway can serve it.
/// 7. Submit the challenge for validation.
/// 8. Poll for authorization and order completion.
/// 9. Generate a CSR, finalize the order, and download the certificate.
///
/// The caller is responsible for serving the HTTP-01 challenge response at
/// `/.well-known/acme-challenge/{token}` while [awaitChallengeValidation] is
/// in progress.
class AcmeClient {
  /// Creates an ACME client targeting the given [directoryUrl].
  ///
  /// When [accountKey] is supplied it is reused; otherwise a fresh 2048-bit
  /// RSA key is generated on first use.
  AcmeClient({
    required this.directoryUrl,
    pc.RSAPrivateKey? accountKey,
    http.Client? httpClient,
  }) : _accountKey = accountKey,
       _httpClient = httpClient ?? http.Client();

  /// The ACME directory URL (e.g. Let's Encrypt production or staging).
  final String directoryUrl;

  final Logger _logger = Logger('AcmeClient');
  final http.Client _httpClient;

  pc.RSAPrivateKey? _accountKey;
  pc.RSAPublicKey? _accountPublicKey;

  // Cached directory resources.
  Map<String, dynamic>? _directory;
  String? _newAccountUrl;
  String? _newNonceUrl;
  String? _newOrderUrl;
  String? _kid; // Key ID assigned by the ACME server

  /// Returns the RSA account private key, generating one if needed.
  pc.RSAPrivateKey get accountKey {
    if (_accountKey != null) return _accountKey!;
    _generateAccountKey();
    return _accountKey!;
  }

  /// Returns the RSA account public key.
  pc.RSAPublicKey get accountPublicKey {
    if (_accountPublicKey != null) return _accountPublicKey!;
    _generateAccountKey();
    return _accountPublicKey!;
  }

  void _generateAccountKey() {
    final keyGen = pc.RSAKeyGenerator()
      ..init(
        pc.ParametersWithRandom(
          pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
          _secureRandom(),
        ),
      );
    final pair = keyGen.generateKeyPair();
    _accountPublicKey = pair.publicKey;
    _accountKey = pair.privateKey;
  }

  static pc.SecureRandom _secureRandom() {
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    final secureRandom = pc.FortunaRandom();
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  /// Fetches and caches the ACME directory.
  Future<Map<String, dynamic>> _getDirectory() async {
    if (_directory != null) return _directory!;
    final resp = await _httpClient.get(Uri.parse(directoryUrl));
    if (resp.statusCode != 200) {
      throw AcmeException(
        'Failed to fetch ACME directory: ${resp.statusCode} ${resp.body}',
      );
    }
    _directory = jsonDecode(resp.body) as Map<String, dynamic>;
    _newNonceUrl = _directory!['newNonce'] as String?;
    _newAccountUrl = _directory!['newAccount'] as String?;
    _newOrderUrl = _directory!['newOrder'] as String?;
    return _directory!;
  }

  /// Fetches a nonce from the ACME server's newNonce endpoint.
  Future<String> _getNonce() async {
    await _getDirectory();
    final nonceUrl = _newNonceUrl!;
    final resp = await _httpClient.head(Uri.parse(nonceUrl));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      // Some servers use 204, others 200; treat anything 2xx as success.
      if (resp.statusCode != 204 && resp.statusCode != 200) {
        throw AcmeException('Failed to get nonce: ${resp.statusCode}');
      }
    }
    final nonce = resp.headers['replay-nonce'];
    if (nonce == null) {
      throw AcmeException('ACME server did not return a Replay-Nonce header');
    }
    return nonce;
  }

  // ---------------------------------------------------------------------------
  // JWS signing
  // ---------------------------------------------------------------------------

  /// Builds the JWK (JSON Web Key) object for the RSA account public key.
  Map<String, String> _jwk() {
    final pub = accountPublicKey;
    // RFC 7518: RSA public key JWK uses base64url-encoded modulus and exponent
    // without padding.
    final n = _base64UrlNoPad(_bigIntToBytes(pub.modulus!));
    final e = _base64UrlNoPad(_bigIntToBytes(pub.exponent!));
    return {'kty': 'RSA', 'n': n, 'e': e};
  }

  /// Computes the RFC 7638 JWK thumbprint (SHA-256 hash of canonical JWK JSON).
  String _jwkThumbprint() {
    final jwk = _jwk();
    // Canonical order: e, kty, n (lexicographic key order per RFC 7638).
    final canonical = jsonEncode({
      'e': jwk['e'],
      'kty': jwk['kty'],
      'n': jwk['n'],
    });
    final hash = crypto.sha256.convert(utf8.encode(canonical));
    return _base64UrlNoPad(Uint8List.fromList(hash.bytes));
  }

  /// Signs a JWS payload and POSTs it to [url].
  ///
  /// When [kid] is null (account creation), the JWS protected header includes
  /// the JWK. Otherwise it includes the [kid].
  Future<http.Response> _post(
    String url,
    Map<String, dynamic> payload, {
    String? kid,
  }) async {
    final nonce = await _getNonce();
    final protectedHeader = <String, dynamic>{
      'alg': 'RS256',
      'nonce': nonce,
      'url': url,
    };
    if (kid != null) {
      protectedHeader['kid'] = kid;
    } else {
      protectedHeader['jwk'] = _jwk();
    }

    final protectedJson = jsonEncode(protectedHeader);
    final protectedB64 = _base64UrlNoPad(utf8.encode(protectedJson));

    final payloadJson = jsonEncode(payload);
    final payloadB64 = _base64UrlNoPad(utf8.encode(payloadJson));

    final signingInput = utf8.encode('$protectedB64.$payloadB64');
    final signature = _rs256Sign(Uint8List.fromList(signingInput));

    final body = jsonEncode({
      'protected': protectedB64,
      'payload': payloadB64,
      'signature': _base64UrlNoPad(signature),
    });

    final resp = await _httpClient.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/jose+json'},
      body: body,
    );

    // Capture the KID from the Location header on newAccount.
    if (url == _newAccountUrl && resp.statusCode == 201) {
      _kid = resp.headers['location'];
    }

    return resp;
  }

  /// Signs [data] with RS256 (RSASSA-PKCS1-v1_5 using SHA-256).
  Uint8List _rs256Sign(Uint8List data) {
    // SHA-256 digest identifier hex per RFC 8017 / pointycastle registry.
    final signer = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201');
    final priv = accountKey;
    final params = pc.PrivateKeyParameter<pc.RSAPrivateKey>(priv);
    signer.init(true, params);
    final sig = signer.generateSignature(data);
    return sig.bytes;
  }

  // ---------------------------------------------------------------------------
  // Account registration
  // ---------------------------------------------------------------------------

  /// Registers a new ACME account (or retrieves the existing account URL).
  Future<String> registerAccount({
    required String email,
    required bool termsOfServiceAgreed,
  }) async {
    await _getDirectory();
    final contact = 'mailto:$email';
    final resp = await _post(_newAccountUrl!, {
      'termsOfServiceAgreed': termsOfServiceAgreed,
      'contact': [contact],
    });

    if (resp.statusCode == 201) {
      // New account created.
      _kid = resp.headers['location'];
      _logger.info('ACME account registered: $_kid');
      return _kid!;
    } else if (resp.statusCode == 200) {
      // Account already exists.
      _kid = resp.headers['location'];
      _logger.info('ACME account already exists: $_kid');
      return _kid!;
    } else {
      throw AcmeException(
        'Account registration failed: ${resp.statusCode} ${resp.body}',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Order creation
  // ---------------------------------------------------------------------------

  /// Creates a new order for the given [domains].
  ///
  /// Returns the order URL and the parsed order object.
  Future<AcmeOrder> createOrder(List<String> domains) async {
    await _getDirectory();
    final identifiers = domains
        .map((d) => {'type': 'dns', 'value': d})
        .toList();

    final resp = await _post(_newOrderUrl!, {'identifiers': identifiers});

    if (resp.statusCode != 201) {
      throw AcmeException(
        'Order creation failed: ${resp.statusCode} ${resp.body}',
      );
    }

    final orderUrl = resp.headers['location']!;
    final order = jsonDecode(resp.body) as Map<String, dynamic>;
    return AcmeOrder(
      url: orderUrl,
      status: order['status'] as String,
      authorizations: (order['authorizations'] as List).cast<String>(),
      finalize: order['finalize'] as String,
      certificate: order['certificate'] as String?,
    );
  }

  // ---------------------------------------------------------------------------
  // Authorization and challenge
  // ---------------------------------------------------------------------------

  /// Fetches the authorization object at [authzUrl] and extracts the
  /// HTTP-01 challenge.
  Future<AcmeHttp01Challenge> getHttp01Challenge(String authzUrl) async {
    // POST-as-GET: empty payload to fetch the authorization.
    final resp = await _post(authzUrl, {}, kid: _kid);

    if (resp.statusCode != 200) {
      throw AcmeException(
        'Failed to fetch authorization: ${resp.statusCode} ${resp.body}',
      );
    }

    final authz = jsonDecode(resp.body) as Map<String, dynamic>;
    final challenges = authz['challenges'] as List;

    Map<String, dynamic>? httpChallenge;
    for (final ch in challenges) {
      final chMap = ch as Map<String, dynamic>;
      if (chMap['type'] == 'http-01') {
        httpChallenge = chMap;
        break;
      }
    }

    if (httpChallenge == null) {
      throw AcmeException(
        'No HTTP-01 challenge available for authorization $authzUrl',
      );
    }

    final token = httpChallenge['token'] as String;
    final keyAuth = '$token.${_jwkThumbprint()}';
    final challengeUrl = httpChallenge['url'] as String;

    return AcmeHttp01Challenge(
      token: token,
      keyAuthorization: keyAuth,
      challengeUrl: challengeUrl,
    );
  }

  /// Submits the challenge for validation by the ACME server.
  Future<void> submitChallenge(AcmeHttp01Challenge challenge) async {
    final resp = await _post(challenge.challengeUrl, {}, kid: _kid);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw AcmeException(
        'Challenge submission failed: ${resp.statusCode} ${resp.body}',
      );
    }
    _logger.info('ACME challenge submitted for validation: ${challenge.token}');
  }

  /// Polls the authorization status until it is no longer pending.
  ///
  /// Returns `true` if the authorization is valid, `false` if invalid.
  Future<bool> awaitAuthorization(
    String authzUrl, {
    Duration timeout = const Duration(seconds: 60),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      final resp = await _post(authzUrl, {}, kid: _kid);
      if (resp.statusCode != 200) {
        _logger.warning('Authorization poll returned ${resp.statusCode}');
        continue;
      }
      final authz = jsonDecode(resp.body) as Map<String, dynamic>;
      final status = authz['status'] as String;
      if (status == 'valid') return true;
      if (status == 'invalid' ||
          status == 'deactivated' ||
          status == 'revoked') {
        _logger.error('Authorization $authzUrl status: $status');
        return false;
      }
    }
    throw AcmeException('Authorization polling timed out for $authzUrl');
  }

  // ---------------------------------------------------------------------------
  // CSR generation and finalization
  // ---------------------------------------------------------------------------

  /// Generates a PKCS#10 Certificate Signing Request for [domains] using a
  /// new RSA key pair, and returns the CSR bytes along with the private key.
  ({Uint8List csrBytes, pc.RSAPrivateKey certKey}) _generateCsr(
    List<String> domains,
  ) {
    // Generate a new key pair for the certificate (separate from account key).
    final keyGen = pc.RSAKeyGenerator()
      ..init(
        pc.ParametersWithRandom(
          pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
          _secureRandom(),
        ),
      );
    final pair = keyGen.generateKeyPair();
    final certPubKey = pair.publicKey;
    final certPrivKey = pair.privateKey;

    // Build the CSR using ASN.1.
    // CertificationRequest ::= SEQUENCE {
    //   certificationRequestInfo CertificationRequestInfo,
    //   signatureAlgorithm AlgorithmIdentifier,
    //   signature BIT STRING
    // }
    //
    // CertificationRequestInfo ::= SEQUENCE {
    //   version INTEGER (v1(0)),
    //   subject Name,
    //   subjectPKInfo SubjectPublicKeyInfo,
    //   attributes [0] IMPLICIT SET OF Attribute
    // }

    final subject = _buildSubjectName(domains.first);
    final subjectPublicKeyInfo = _buildSubjectPublicKeyInfo(certPubKey);
    final extensionsAttribute = _buildExtensionsAttribute(domains);

    final csrInfo = asn1.ASN1Sequence();
    csrInfo.add(asn1.ASN1Integer(BigInt.zero)); // version
    csrInfo.add(subject);
    csrInfo.add(subjectPublicKeyInfo);
    csrInfo.add(extensionsAttribute);

    // Sign the CSR info with SHA-256.
    final csrInfoBytes = csrInfo.encode();
    final signer = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201');
    signer.init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(certPrivKey));
    final signature = signer.generateSignature(csrInfoBytes);

    final signatureAlgorithm = asn1.ASN1Sequence();
    signatureAlgorithm.add(
      asn1.ASN1ObjectIdentifier.fromName('sha256WithRSAEncryption'),
    );
    signatureAlgorithm.add(asn1.ASN1Null());

    final csr = asn1.ASN1Sequence();
    csr.add(csrInfo);
    csr.add(signatureAlgorithm);
    csr.add(asn1.ASN1BitString(stringValues: signature.bytes.toList()));

    return (csrBytes: csr.encode(), certKey: certPrivKey);
  }

  asn1.ASN1Sequence _buildSubjectName(String cn) {
    final seq = asn1.ASN1Sequence();
    final rdn = asn1.ASN1Set();
    final attr = asn1.ASN1Sequence();
    attr.add(asn1.ASN1ObjectIdentifier.fromName('commonName'));
    attr.add(asn1.ASN1UTF8String(utf8StringValue: cn));
    rdn.add(attr);
    seq.add(rdn);
    return seq;
  }

  asn1.ASN1Sequence _buildSubjectPublicKeyInfo(pc.RSAPublicKey pubKey) {
    // SubjectPublicKeyInfo ::= SEQUENCE {
    //   algorithm AlgorithmIdentifier,
    //   subjectPublicKey BIT STRING
    // }
    final algorithm = asn1.ASN1Sequence();
    algorithm.add(asn1.ASN1ObjectIdentifier.fromName('rsaEncryption'));
    algorithm.add(asn1.ASN1Null());

    // RSA public key is DER-encoded RSAPublicKey ::= SEQUENCE { modulus, publicExponent }
    final rsaKey = asn1.ASN1Sequence();
    rsaKey.add(asn1.ASN1Integer(pubKey.modulus!));
    rsaKey.add(asn1.ASN1Integer(pubKey.exponent!));

    final spki = asn1.ASN1Sequence();
    spki.add(algorithm);
    spki.add(asn1.ASN1BitString(stringValues: rsaKey.encode().toList()));
    return spki;
  }

  asn1.ASN1Set _buildExtensionsAttribute(List<String> domains) {
    // [0] IMPLICIT SET OF Attribute
    // Attribute ::= SEQUENCE { type OID, values SET OF ANY }
    // Extension request OID: 1.2.840.113549.1.9.14
    final extAttr = asn1.ASN1Sequence();
    extAttr.add(
      asn1.ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.9.14'),
    );

    // Extensions ::= SEQUENCE OF Extension
    // Extension ::= SEQUENCE { extnID OID, critical BOOLEAN OPTIONAL, extnValue OCTET STRING }
    final extensionsSeq = asn1.ASN1Sequence();

    // Subject Alternative Name extension (OID 2.5.29.17)
    final sanExt = asn1.ASN1Sequence();
    sanExt.add(asn1.ASN1ObjectIdentifier.fromIdentifierString('2.5.29.17'));

    // GeneralNames ::= SEQUENCE OF GeneralName
    // For DNS names: [2] IMPLICIT IA5String — context-specific tag 0x82
    final generalNames = asn1.ASN1Sequence();
    for (final domain in domains) {
      final dnsName = asn1.ASN1IA5String(stringValue: domain, tag: 0x82);
      generalNames.add(dnsName);
    }

    // extnValue is OCTET STRING containing DER-encoded GeneralNames
    final sanValue = asn1.ASN1OctetString(
      octets: Uint8List.fromList(generalNames.encode()),
    );
    sanExt.add(sanValue);
    extensionsSeq.add(sanExt);

    final extValueSet = asn1.ASN1Set();
    extValueSet.add(extensionsSeq);
    extAttr.add(extValueSet);

    // Wrap in [0] context-specific tag (0xA0 = constructed context-specific 0)
    final attrSet = asn1.ASN1Set(tag: 0xA0);
    attrSet.add(extAttr);
    return attrSet;
  }

  /// Finalizes the order by submitting the CSR.
  Future<void> finalizeOrder(AcmeOrder order, List<String> domains) async {
    final (:csrBytes, :certKey) = _generateCsr(domains);
    _certPrivateKey = certKey;

    final csrB64 = _base64UrlNoPad(csrBytes);
    final resp = await _post(order.finalize, {'csr': csrB64}, kid: _kid);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw AcmeException(
        'Order finalization failed: ${resp.statusCode} ${resp.body}',
      );
    }
    _logger.info('ACME order finalized for domains: $domains');
  }

  pc.RSAPrivateKey? _certPrivateKey;

  /// Polls the order status until it is ready, then downloads the certificate.
  Future<AcmeCertificateResult> awaitOrderAndDownload(
    AcmeOrder order, {
    Duration timeout = const Duration(seconds: 60),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    String? certUrl = order.certificate;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(pollInterval);
      final resp = await _post(order.url, {}, kid: _kid);
      if (resp.statusCode != 200) {
        _logger.warning('Order poll returned ${resp.statusCode}');
        continue;
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final status = body['status'] as String;
      certUrl = body['certificate'] as String? ?? certUrl;

      if (status == 'valid' && certUrl != null) {
        // Download the certificate chain.
        final certResp = await _post(certUrl, {}, kid: _kid);
        if (certResp.statusCode != 200) {
          throw AcmeException(
            'Certificate download failed: ${certResp.statusCode}',
          );
        }
        final certPem = _pemEncode(certResp.body, 'CERTIFICATE');
        final keyPem = _rsaPrivateKeyToPem(_certPrivateKey!);
        final notAfter = _extractCertExpiry(certResp.body);
        return AcmeCertificateResult(
          certificatePem: certPem,
          privateKeyPem: keyPem,
          notAfter: notAfter,
        );
      }
      if (status == 'invalid') {
        throw AcmeException('Order is invalid: ${resp.body}');
      }
    }
    throw AcmeException('Order polling timed out');
  }

  // ---------------------------------------------------------------------------
  // Full issuance flow
  // ---------------------------------------------------------------------------

  /// Runs the complete ACME HTTP-01 issuance flow for [domains].
  ///
  /// [serveChallenge] is called for each HTTP-01 challenge so the caller can
  /// arrange for the challenge response to be served (e.g. by the gateway).
  /// [removeChallenge] is called after validation to clean up.
  Future<AcmeCertificateResult> issueCertificate({
    required List<String> domains,
    required String email,
    required bool termsOfServiceAgreed,
    required Future<void> Function(AcmeHttp01Challenge challenge)
    serveChallenge,
    required Future<void> Function(AcmeHttp01Challenge challenge)
    removeChallenge,
  }) async {
    // 1. Register account.
    await registerAccount(
      email: email,
      termsOfServiceAgreed: termsOfServiceAgreed,
    );

    // 2. Create order.
    final order = await createOrder(domains);

    // 3. For each authorization, get the HTTP-01 challenge, serve it, and
    //    submit for validation.
    for (final authzUrl in order.authorizations) {
      final challenge = await getHttp01Challenge(authzUrl);
      await serveChallenge(challenge);
      try {
        await submitChallenge(challenge);
        final valid = await awaitAuthorization(authzUrl);
        if (!valid) {
          throw AcmeException('Authorization failed for $authzUrl');
        }
      } finally {
        await removeChallenge(challenge);
      }
    }

    // 4. Finalize the order with a CSR.
    await finalizeOrder(order, domains);

    // 5. Download the certificate.
    final result = await awaitOrderAndDownload(order);
    _logger.info('ACME certificate issued for $domains');
    return result;
  }

  /// Releases the HTTP client and clears cached state.
  void dispose() {
    _httpClient.close();
    _directory = null;
    _accountKey = null;
    _accountPublicKey = null;
    _certPrivateKey = null;
    _kid = null;
  }

  /// Exports the account key as PEM-encoded string.
  String exportAccountKeyPem() {
    return _rsaPrivateKeyToPem(accountKey);
  }

  // ---------------------------------------------------------------------------
  // Encoding helpers
  // ---------------------------------------------------------------------------

  static String _base64UrlNoPad(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Uint8List _bigIntToBytes(BigInt value) {
    final byteCount = (value.bitLength + 7) ~/ 8;
    final bytes = Uint8List(byteCount);
    var v = value;
    for (var i = byteCount - 1; i >= 0; i--) {
      bytes[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return bytes;
  }

  /// Wraps raw DER or PEM certificate bytes into a PEM string.
  String _pemEncode(String raw, String label) {
    // If already PEM, return as-is.
    if (raw.contains('-----BEGIN $label-----')) return raw;
    // Otherwise assume it's raw certificate data that needs base64 wrapping.
    final b64 = base64.encode(utf8.encode(raw));
    final lines = <String>[];
    for (var i = 0; i < b64.length; i += 64) {
      lines.add(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
    }
    return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n';
  }

  /// Converts an RSA private key to PEM format.
  String _rsaPrivateKeyToPem(pc.RSAPrivateKey key) {
    // RSAPrivateKey ::= SEQUENCE {
    //   version INTEGER (0),
    //   modulus INTEGER,
    //   publicExponent INTEGER,
    //   privateExponent INTEGER,
    //   prime1 INTEGER,
    //   prime2 INTEGER,
    //   exponent1 INTEGER,
    //   exponent2 INTEGER,
    //   coefficient INTEGER
    // }
    final seq = asn1.ASN1Sequence();
    seq.add(asn1.ASN1Integer(BigInt.zero));
    seq.add(asn1.ASN1Integer(key.modulus!));
    seq.add(asn1.ASN1Integer(key.exponent!));
    seq.add(asn1.ASN1Integer(key.privateExponent!));
    seq.add(asn1.ASN1Integer(key.p!));
    seq.add(asn1.ASN1Integer(key.q!));
    // Compute exponents and coefficient.
    final exp1 = key.privateExponent! % (key.p! - BigInt.one);
    final exp2 = key.privateExponent! % (key.q! - BigInt.one);
    final coeff = key.q!.modInverse(key.p!);
    seq.add(asn1.ASN1Integer(exp1));
    seq.add(asn1.ASN1Integer(exp2));
    seq.add(asn1.ASN1Integer(coeff));

    final der = seq.encode();
    final b64 = base64.encode(der);
    final lines = <String>[];
    for (var i = 0; i < b64.length; i += 64) {
      lines.add(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
    }
    return '-----BEGIN RSA PRIVATE KEY-----\n${lines.join('\n')}\n-----END RSA PRIVATE KEY-----\n';
  }

  DateTime _extractCertExpiry(String certBody) {
    // Try to parse the certificate's notAfter from the DER.
    // If the body is PEM, decode it first.
    try {
      Uint8List derBytes;
      if (certBody.contains('-----BEGIN')) {
        final b64 = certBody
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && !l.startsWith('-----'))
            .join();
        derBytes = base64.decode(b64);
      } else {
        derBytes = Uint8List.fromList(certBody.codeUnits);
      }
      final parser = asn1.ASN1Parser(derBytes);
      final sequence = parser.nextObject() as asn1.ASN1Sequence;
      final elements = sequence.elements!;
      final tbsCertificate = elements[0] as asn1.ASN1Sequence;
      final tbsElements = tbsCertificate.elements!;
      final validity = tbsElements[4] as asn1.ASN1Sequence;
      final validityElements = validity.elements!;
      final notAfter = validityElements[1];
      if (notAfter is asn1.ASN1UtcTime) {
        return notAfter.time!;
      } else if (notAfter is asn1.ASN1GeneralizedTime) {
        return notAfter.dateTimeValue!;
      }
    } catch (e) {
      _logger.warning('Failed to parse certificate expiry: $e');
    }
    // Default to 90 days from now if parsing fails.
    return DateTime.now().add(const Duration(days: 90));
  }
}

/// An ACME order as returned by the server.
class AcmeOrder {
  /// Creates an order descriptor.
  AcmeOrder({
    required this.url,
    required this.status,
    required this.authorizations,
    required this.finalize,
    this.certificate,
  });

  /// The order URL.
  final String url;

  /// Current order status (e.g. `pending`, `ready`, `valid`).
  final String status;

  /// Authorization URLs for each identifier.
  final List<String> authorizations;

  /// The finalize URL for submitting the CSR.
  final String finalize;

  /// The certificate download URL (available when status is `valid`).
  final String? certificate;
}

/// Exception thrown for ACME protocol errors.
class AcmeException implements Exception {
  /// Creates an ACME exception with a [message].
  AcmeException(this.message);

  /// Human-readable error message.
  final String message;

  @override
  String toString() => 'AcmeException: $message';
}
