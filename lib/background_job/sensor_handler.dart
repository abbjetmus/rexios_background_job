import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:polar/polar.dart';

class BackgroundJobSensorHandlerPolar {
  BackgroundJobSensorHandlerPolar(this.sensorAddress, this.polar);

  final String sensorAddress;
  final Polar polar;

  // State management
  bool _isConnecting = false;
  StreamSubscription? _connectionSubscription;
  Completer<Polar>? _connectCompleter;

  void _setupListeners() {
    _connectionSubscription = polar.deviceConnected.listen(
      (onData) async {
        debugPrint('Background job - Sensor@$sensorAddress connected');
        if (_connectCompleter?.isCompleted == false) {
          _connectCompleter?.complete(polar);
          _isConnecting = false;
        }
      },
      onError: (error) {
        debugPrint('Connection error: $error');
        if (_connectCompleter?.isCompleted == false) {
          _connectCompleter?.completeError(error);
        }
        _isConnecting = false;
      },
    );
  }

  Future<Polar> connect(Duration timeLimit) async {
    if (_isConnecting) {
      throw StateError('Connection already in progress');
    }

    _isConnecting = true;
    _connectCompleter = Completer<Polar>();

    try {
      _setupListeners();

      await polar.connectToDevice(sensorAddress, requestPermissions: false);

      return await _connectCompleter!.future.timeout(
        timeLimit,
        onTimeout: () {
          _isConnecting = false;
          _connectionSubscription?.cancel();
          throw TimeoutException(
            'Connecting to sensor@$sensorAddress timed out',
            timeLimit,
          );
        },
      );
    } catch (e) {
      _isConnecting = false;
      await _connectionSubscription?.cancel();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      await polar.disconnectFromDevice(sensorAddress);
    } finally {
      await _connectionSubscription?.cancel();
    }
  }
}
