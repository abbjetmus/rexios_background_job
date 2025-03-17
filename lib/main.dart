import 'package:flutter/material.dart';
import 'package:polar/polar.dart';
import 'package:rexios_background_job/background_job/background_job.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeBackgroundJob();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const identifier = 'E985E828';

  final polar = Polar();
  final logs = ['Service started'];
  bool allPermissionsGranted = false;

  @override
  void initState() {
    super.initState();

    polar.batteryLevel.listen((e) => log('Battery: ${e.level}'));
    polar.deviceConnecting.listen((_) => log('Device connecting'));
    polar.deviceConnected.listen((_) => log('Device connected'));
    polar.deviceDisconnected.listen((_) => log('Device disconnected'));

    // Request permissions when app starts
    _requestPermissions();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Polar example app'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Request Permissions',
              onPressed: _requestPermissions,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Clear logs',
              onPressed: () {
                setState(() {
                  logs.clear();
                  logs.add('Logs cleared');
                });
              },
            ),
          ],
        ),
        body: SizedBox(
          height: size.height,
          child: Column(
            children: [
              Container(
                color: allPermissionsGranted
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                child: Text(
                  allPermissionsGranted
                      ? 'All permissions granted'
                      : 'Missing permissions - check console for details',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: allPermissionsGranted
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
                  children: [
                    ElevatedButton.icon(
                      label: const Text('Scan'),
                      onPressed: () async {
                        // Request permissions before scanning
                        await _requestPermissions();

                        log('Starting device scan...');
                        polar.searchForDevice().listen((e) {
                          log('Found device: ${e.deviceId} (${e.name})');
                        }, onError: (e) {
                          log('Error scanning: $e');
                        });
                      },
                    ),
                    ElevatedButton.icon(
                      label: const Text('Connect'),
                      onPressed: () async {
                        // Request permissions before connecting
                        await _requestPermissions();
                        log('Connecting to device: $identifier');
                        polar.connectToDevice(identifier);
                      },
                    ),
                    ElevatedButton.icon(
                      label: const Text('Disconnect'),
                      onPressed: () async {
                        log('Disconnecting from device: $identifier');
                        polar.disconnectFromDevice(identifier);
                      },
                    ),
                    ElevatedButton.icon(
                      label: const Text('Run Background Job'),
                      onPressed: () async {
                        log('Running background job...');
                        await startTestBackgroundJob();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final logMessage = logs[logs.length - 1 - index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(logMessage),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestPermissions() async {
    debugPrint('Requesting permissions...');

    // Request all required permissions for Bluetooth
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      // These are needed for older Android versions
      // Permission.bluetooth,
    ].request();

    statuses.forEach((permission, status) {
      debugPrint('$permission: ${status.toString()}');
    });

    // Check each permission specifically and provide guidance
    if (!statuses[Permission.location]!.isGranted) {
      debugPrint(
          'WARNING: Location permission is required for Bluetooth scanning on many devices');
    }

    if (!statuses[Permission.bluetoothScan]!.isGranted) {
      debugPrint(
          'WARNING: Bluetooth scan permission is required to scan for devices');
    }

    if (!statuses[Permission.bluetoothConnect]!.isGranted) {
      debugPrint(
          'WARNING: Bluetooth connect permission is required to connect to devices');
    }

    // For debugging - show specific permission errors
    bool allGranted = statuses.values.every((status) => status.isGranted);
    setState(() {
      allPermissionsGranted = allGranted;
    });

    if (!allGranted) {
      debugPrint(
          'ATTENTION: Not all permissions were granted. Please check app settings.');
    } else {
      debugPrint('SUCCESS: All required permissions granted');
    }
  }

  void log(String log) {
    debugPrint(log);
    setState(() {
      logs.add(log);
    });
  }
}
