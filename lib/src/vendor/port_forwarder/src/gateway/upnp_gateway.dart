import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import '../../port_forwarder.dart';
import 'package:xml/xml.dart';

final class UPnPGateway extends Gateway {
  static final InternetAddress _broadcastAddress = InternetAddress("239.255.255.250");
  static const _broadcastPort = 1900;
  static final Set<String> _broadcastAdverts = {
    _newAdvert("urn:schemas-upnp-org:device:InternetGatewayDevice:1"),
    _newAdvert("urn:schemas-upnp-org:device:InternetGatewayDevice:2"),
  };
  static String _newAdvert(String advert) => "M-SEARCH * HTTP/1.1\r\nHOST: ${_broadcastAddress.host}:$_broadcastPort\r\nST: $advert\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\n\r\n";
  static final Set<String> _acceptableServiceTypes = {
    "urn:schemas-upnp-org:service:WANIPConnection:1",
    "urn:schemas-upnp-org:service:WANIPConnection:2",
    "urn:schemas-upnp-org:service:WANPPPConnection:1",
    "urn:schemas-upnp-org:service:WANPPPConnection:2"
  };

  static const int _space = 32; //
  static const int _n = 10; // \n
  static const int _r = 13; // \r
  static const int _doubleColumn = 58; // :

  final InternetAddress _address;
  final String _serviceType;
  final Uri _controlURL;

  UPnPGateway._internal({required InternetAddress address, required String serviceType, required Uri controlURL})
      : _controlURL = controlURL, _serviceType = serviceType, _address = address;

  static Future<UPnPGateway?> discover() async {
    final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.any
    );

    var available = 0;
    for(final interface in interfaces) {
      available += interface.addresses.length;
    }

    final completer = Completer<UPnPGateway?>();

    void onSocketCreated(RawDatagramSocket socket) {
      void onBroadcastResult(UPnPGateway? result) {
        if (result == null) {
          if (--available == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        } else {
          if (!completer.isCompleted) {
            completer.complete(result);
          }
          available--;
        }
      }

      void onBroadcastError(Object error) {
        if (--available == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      }

      completer.future.then((_) => socket.close());

      for(final message in _broadcastAdverts) {
        final encoded = utf8.encode(message);
        socket.send(encoded, _broadcastAddress, _broadcastPort);
      }
      socket.timeout(const Duration(seconds: 10))
          .asyncMap((event) => _handleMessage(event, socket))
          .firstWhere((test) => test != null)
          .then(onBroadcastResult, onError: onBroadcastError);
    }

    void onSocketFailure(Object error) {
      // Ignore the error
    }

    for(final interface in interfaces) {
      for(final address in interface.addresses) {
        RawDatagramSocket.bind(address, 0)
            .then(onSocketCreated, onError: onSocketFailure);
      }
    }

    return completer.future;
  }

  static Future<UPnPGateway?> _handleMessage(RawSocketEvent event, RawDatagramSocket socket) async {
    if(event != RawSocketEvent.read) {
      return null;
    }

    // Read a datagram
    final datagram = socket.receive();
    if(datagram == null) {
      return null;
    }

    // Start reading the output
    final data = datagram.data;
    var position = 0;
    final limit = data.length;

    // Skip HTTP response header
    // Some modems might send a partially corrupted HTTP response
    // This is a best effort to ignore it and parse the headers to find the LOCATION header
    var r = false;
    while(position < limit) {
      final current = data[position++];
      if(current == _r) {
        r = true;
      }else if(r && current == _n) {
        break;
      }else {
        r = false;
      }
    }

    // Start reading headers
    while(position - 1 < limit) {
      // Check if headers are done
      if(data[position] == _r && data[position + 1] == _n) {
        break;
      }

      // Read header key
      final headerKeyStart = position;
      while(position < limit) {
        final current = data[position++];
        if(current == _doubleColumn) {
          break;
        }
      }
      final headerKey = utf8.decode(Uint8List.sublistView(data, headerKeyStart, position - 1));

      // Skip space if present
      if(position < limit && data[position] == _space) {
        position++;
      }

      // Read header value
      var headerValueStart = position;
      r = false;
      while(position < limit) {
        final current = data[position++];
        if(current == _r) {
          r = true;
        }else if(r && current == _n) {
          break;
        }else {
          r = false;
        }
      }

      // Skip if this is not a LOCATION header
      if(headerKey.toUpperCase() != "LOCATION") {
        continue;
      }

      // Read location
      final location = Uri.parse(utf8.decode(Uint8List.sublistView(data, headerValueStart, position - 2)));

      // Navigate to location
      final response = await http.get(location);

      // Parse xml response
      final document = XmlDocument.parse(response.body);

      // Find all services
      for(final service in document.findAllElements("service")) {
        // Read service type
        final serviceType = service.getElement("serviceType")?.innerText;
        if(serviceType == null || !_acceptableServiceTypes.contains(serviceType)) {
          continue;
        }

        // Read control url location
        final controlUrl = service.getElement("controlURL")?.innerText;
        if(controlUrl == null) {
          continue;
        }

        // Parse the absolute control url location
        final controlUrlLocation = Uri.parse(controlUrl);
        final absoluteControlURL = Uri(
            scheme: location.scheme,
            userInfo: location.userInfo,
            host: location.host,
            port: location.port,
            path: controlUrlLocation.path,
            query: controlUrlLocation.query
        );

        // Return the gateway
        return UPnPGateway._internal(
            address: socket.address,
            serviceType: serviceType,
            controlURL: absoluteControlURL
        );
      }
    }

    // No gateway found
    return null;
  }

  Future<T> _send<T>({
    required String action,
    required Map<String, String> params,
    required T? Function(XmlElement?) handler,
    bool handleErrors = true
  }) async {
    // Build soap payload
    final soap = "<?xml version=\"1.0\"?>"
        "<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" SOAP-ENV:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">"
        "<SOAP-ENV:Body>"
        "<m:$action xmlns:m=\"$_serviceType\">"
        "${params.entries.map((entry) => "<${entry.key}>${entry.value}</${entry.key}>").join("")}"
        "</m:$action>"
        "</SOAP-ENV:Body>"
        "</SOAP-ENV:Envelope>";

    // Send the HTTP request
    final response = await http.post(
        _controlURL,
        headers: {
          "Content-Type": "text/xml",
          "SOAPAction": "\"$_serviceType#$action\"",
          "Connection": "Close"
        },
        body: soap
    );

    // Read xml response
    final body = XmlDocument.parse(response.body)
        .getElement("s:Envelope")
        ?.getElement("s:Body")
        ?.firstElementChild;

    // Check if there is an error
    if(handleErrors && body != null && body.localName.toLowerCase() == "fault") {
      final faultCode = body.getElement("faultcode")?.innerText;
      final faultString = body.getElement("faultstring")?.innerText;
      final detail = body.getElement("detail");
      if(detail == null) {
        throw UPnPError(
            description: faultString,
            statusCode: faultCode != null ? int.tryParse(faultCode) : null,
            response: response.body
        );
      }

      final faultDetail = faultString != null
          ? (detail.getElement(faultString) ?? detail.firstElementChild)
          : detail.firstElementChild;
      final detailCode = faultDetail?.getElement("errorCode")?.innerText ?? faultCode;
      final detailDescription = faultDetail?.getElement("errorDescription")?.innerText ?? faultString;
      throw UPnPError(
          description: detailDescription,
          statusCode: detailCode != null ? int.tryParse(detailCode) : null,
          response: response.body
      );
    }

    // Handle the body
    final result = handler(body);

    // If the body can't be handled, error out
    // By using a callback we can retain the response body in the error's metadata
    if(result == null) {
      throw UPnPError(
          description: "Cannot parse response for action $action",
          statusCode: null,
          response: response.body
      );
    }

    // Return the result
    return result;
  }

  @override
  GatewayType get type => GatewayType.upnp;
  
  @override
  Future<bool> openPort({
    required PortType protocol,
    required int externalPort,
    int? internalPort,
    String portDescription = "DartUPnP",
    int leaseDuration = 0
  }) => _send(
      action: "AddPortMapping",
      params: {
        "NewRemoteHost": "",
        "NewProtocol": protocol.name.toUpperCase(),
        "NewInternalClient": _address.address,
        "NewInternalPort": (internalPort ?? externalPort).toString(),
        "NewExternalPort": externalPort.toString(),
        "NewEnabled": "1",
        "NewPortMappingDescription": portDescription,
        "NewLeaseDuration": leaseDuration.toString()
      },
      handler: (response) => response != null
  );

  @override
  Future<bool> closePort({
    required PortType protocol,
    required int externalPort
  }) => _send(
      action: "DeletePortMapping",
      params: {
        "NewRemoteHost": "",
        "NewProtocol": protocol.name.toUpperCase(),
        "NewExternalPort": externalPort.toString()
      },
      handler: (response) => response != null
  );

  @override
  Future<bool> isMapped({
    required PortType protocol,
    required int externalPort
  }) => _send(
      action: "GetSpecificPortMappingEntry",
      params: {
        "NewRemoteHost": "",
        "NewProtocol": protocol.name.toUpperCase(),
        "NewExternalPort": externalPort.toString()
      },
      handleErrors: false,
      handler: (response) {
        final mappedPort = response?.getElement("NewInternalPort")
            ?.innerText
            .trim();
        return mappedPort == externalPort.toString();
      }
  );

  @override
  InternetAddress get internalAddress => _address;

  @override
  Future<InternetAddress> get externalAddress => _send(
      action: "GetExternalIPAddress",
      params: {},
      handler: (response) {
        final address = response?.getElement("NewExternalIPAddress")
            ?.innerText
            .trim();
        return address == null ? null : InternetAddress(address);
      }
  );
}