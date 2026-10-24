// coverage:ignore-file

import 'dart:async';
import 'dart:io';

import '../../port_forwarder.dart';

abstract class Gateway {
  static Future<Gateway?> discover({
    Set<GatewayType> protocols = const {GatewayType.upnp, GatewayType.pmp, GatewayType.pcp}
  }) {
    var available = protocols.length;
    if(available == 0) {
      return Future.value(null);
    }

    final completer = Completer<Gateway?>();
    
    void onData(Gateway? result) {
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

    void onError(Object? error) {
      if (--available == 0 && !completer.isCompleted) {
        completer.complete(null);
      }
    }

    if(protocols.contains(GatewayType.upnp)) {
      UPnPGateway.discover()
          .then(onData, onError: onError);
    }
    if(protocols.contains(GatewayType.pcp)) {
      PcpGateway.discover()
          .then(onData, onError: onError);
    }
    if(protocols.contains(GatewayType.pmp)) {
      PmpGateway.discover()
          .then(onData, onError: onError);
    }
    
    return completer.future;
  }
  
  GatewayType get type;

  Future<bool> openPort({
    required PortType protocol,
    required int externalPort,
    int? internalPort,
    String portDescription = "DartUPnP",
    int leaseDuration = 0
  });

  Future<bool> closePort({
    required PortType protocol,
    required int externalPort
  });

  Future<bool> isMapped({
    required PortType protocol,
    required int externalPort
  });

  InternetAddress get internalAddress;

  Future<InternetAddress> get externalAddress;
}