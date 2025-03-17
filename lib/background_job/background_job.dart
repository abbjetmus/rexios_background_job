import 'dart:io';

import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/foundation.dart';
import 'package:rexios_background_job/background_job/background_job_callback.dart';
import 'package:workmanager/workmanager.dart';

const _testTaskName = 'testTaskName';

// @pragma is mandatory if the App is obfuscated or using Flutter 3.1+
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('Background job - Native called background task: $taskName');

    // A test job may be executed in debug or development
    final isTestJob = taskName == _testTaskName;

    await backgroundJobCallback(isTestJob: isTestJob, timeRestricted: false);

    // Return true to signal success of the background task, i.e., no retries
    return true;
  });
}

Future initializeBackgroundJob() async {
  if (Platform.isAndroid || Platform.isIOS) {
    await Workmanager().initialize(
      // The top level function, aka callbackDispatcher
      callbackDispatcher,
      // If enabled it will post a notification whenever the task is running.
      // However, we post our own debug notifications
      isInDebugMode: false,
    );
  }

  if (Platform.isAndroid) {
    // Register a periodic task which will run every 15 minutes
    // It will get the connection status and device address from shared preferences
    await Workmanager().registerPeriodicTask(
      'periodicTaskUniqueName',
      'periodicTaskName',
    );
  }

  if (Platform.isIOS) {
    int status = await BackgroundFetch.configure(
      BackgroundFetchConfig(
        // Sole iOS configuration option
        // Defaults to 15 (but still a required parameter!?)
        minimumFetchInterval: 15,
      ),
      (String taskId) async {
        debugPrint('[BackgroundFetch] Event callback $taskId');

        await backgroundJobCallback(timeRestricted: true);

        await BackgroundFetch.finish(taskId);
      },
      (String taskId) async {
        debugPrint('[BackgroundFetch] Event timed out $taskId');

        await BackgroundFetch.finish(taskId);
      },
    );

    debugPrint('[BackgroundFetch] configured $status');
  }
}

/// Register a one-off task which will run after 30 seconds
///
/// Issued on iOS to run a less time restricted background job when the
/// logbook is full or its reading was timed out
Future startLongRunningBackgroundJob() async {
  debugPrint('******* register long running background job *********');

  var uniqueName = 'ai.zmartrest.long-running-unique';
  var nonUniqueName = 'ai.zmartrest.long-running';

  await Workmanager().cancelByUniqueName(uniqueName);

  await Workmanager().registerOneOffTask(
    uniqueName,
    nonUniqueName,
    initialDelay: const Duration(seconds: 30),
  );
}

Future startTestBackgroundJob() async {
  debugPrint('******* register test background job *********');

  // Execute the background job immediately
  await Workmanager().registerOneOffTask(
    'test@${DateTime.now()}',
    _testTaskName,
  );
}
