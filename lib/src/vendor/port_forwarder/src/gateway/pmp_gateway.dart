import 'dart:async';
import 'dart:io';

import '../../port_forwarder.dart';

final class PmpGateway extends Gateway {
  PmpGateway._internal();

  static Future<PmpGateway?> discover() async {
    return null;
  }

  @override
  GatewayType get type => GatewayType.pmp;

  @override
  Future<bool> openPort({
    required PortType protocol,
    required int externalPort,
    int? internalPort,
    String portDescription = "DartUPnP",
    int leaseDuration = 0
  }) {
    // TODO: implement openPort
    throw UnimplementedError();
  }

  @override
  Future<bool> closePort({
    required PortType protocol,
    required int externalPort
  }) {
    // TODO: implement closePort
    throw UnimplementedError();
  }

  @override
  Future<bool> isMapped({
    required PortType protocol,
    required int externalPort
  }) {
    // TODO: implement isMapped
    throw UnimplementedError();
  }

  @override
  // TODO: implement externalAddress
  Future<InternetAddress> get externalAddress => throw UnimplementedError();

  @override
  // TODO: implement internalAddress
  InternetAddress get internalAddress => throw UnimplementedError();
}