import 'dart:async';

import 'package:flutter/material.dart';
import 'package:polar/polar.dart';
import 'package:rexios_background_job/background_job/sensor_handler.dart';

/// Called from the background fetch plugin on iOS and the workmanager plugin on Android
///
/// It connects to the sensor and reads the sensor memory before sending its content
/// to the API
///
/// @pragma is mandatory if the App is obfuscated or using Flutter 3.1+
@pragma('vm:entry-point')
Future backgroundJobCallback({
  /// The periodic background fetch on iOS is time restricted to 30 seconds
  required bool timeRestricted,
  bool isTestJob = false,
}) async {
  const identifier = 'E985E828';
  final sensorHandler = BackgroundJobSensorHandlerPolar(identifier, Polar());

  try {
    final sensor = await sensorHandler.connect(const Duration(seconds: 30));

    debugPrint('Connect Completed');

    await sensor.sdkFeatureReady.firstWhere(
      (e) =>
          e.identifier == identifier &&
          e.feature == PolarSdkFeature.offlineRecording,
    );

    debugPrint('SDK Feature Ready Completed');

    await sensor.disconnectFromDevice(identifier);

    debugPrint('Disconnect Completed');
  } catch (e) {
    debugPrint('exception in background task: $e');
  } finally {
    await sensorHandler.disconnect();
  }
}
