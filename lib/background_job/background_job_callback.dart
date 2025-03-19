import 'dart:async';
import 'dart:isolate';

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
  // Start measuring time
  final stopwatch = Stopwatch()..start();
  debugPrint('⏱️ BACKGROUND JOB STARTED');

  // Create an isolate completer to track when we're done
  final completer = Completer<void>();

  // Add error handling for uncaught errors - important for RxJava errors
  Isolate.current.addErrorListener(RawReceivePort((pair) {
    debugPrint('❌ Uncaught error in background job: $pair');
    if (!completer.isCompleted) {
      completer.complete();
    }
  }).sendPort);

  const identifier = 'E49E872C';
  try {
    final sensorHandler = BackgroundJobSensorHandlerPolar(identifier, Polar());

    final sensor = await sensorHandler.connect(const Duration(seconds: 30));
    debugPrint('Connect Completed');

    try {
      await sensor.sdkFeatureReady.firstWhere(
        (e) =>
            e.identifier == identifier &&
            e.feature == PolarSdkFeature.offlineRecording,
      );

      debugPrint('SDK Feature Ready Completed');

      final offlineRecordingsType =
          await sensor.getOfflineRecordingStatus(identifier);

      if (offlineRecordingsType.isEmpty) {
        debugPrint('Ingen offline status att stoppa');
      }

      for (final recordingType in offlineRecordingsType) {
        if (recordingType == PolarDataType.ppi) {
          await sensor.stopOfflineRecording(
            identifier,
            PolarDataType.ppi,
          );
          debugPrint('Stoppade PPI data');
        }
      }

      var recordings = await sensor.listOfflineRecordings(identifier);

      debugPrint('recordings: ${recordings.length}');

      for (final record in recordings) {
        debugPrint(
          'Processing offline data: ${record.path}, size: ${record.size}',
        );
        if (record.type == PolarDataType.ppi && record.size > 40) {
          try {
            final ppiData = await sensor.getOfflinePpiRecord(
              identifier,
              record,
            );

            if (ppiData != null) {
              debugPrint('ppiOfflineListLength ${record.path}');

              // Use a for loop instead of forEach
              for (int i = 0; i < ppiData.data.samples.length; i++) {
                final s = ppiData.data.samples[i];
                // Only log every 60th value (approximately one per minute)
                debugPrint(
                  'PPI: ${s.ppi}, HR: ${s.hr}, Time: ${s.timeStamp.toIso8601String()}',
                );
              }
            }
            // Delete the record after successful processing
            await sensor.removeOfflineRecord(identifier, record);
          } catch (e) {
            debugPrint('Error processing record: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('exception in background task inner try: $e');
    } finally {
      await sensor.startOfflineRecording(
        identifier,
        PolarDataType.ppi,
        settings: PolarSensorSetting(<PolarSettingType, int>{}),
      );
      await sensorHandler.disconnect();
      debugPrint('Disconnect Completed');

      // Complete our isolate tracker
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  } catch (e) {
    debugPrint('exception in background task last try: $e');

    // Complete our isolate tracker on error
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  // Stop the stopwatch and print total time
  stopwatch.stop();
  final totalTimeSeconds = stopwatch.elapsedMilliseconds / 1000;
  debugPrint(
      '⏱️ BACKGROUND JOB COMPLETED in ${totalTimeSeconds.toStringAsFixed(2)} seconds');
}
