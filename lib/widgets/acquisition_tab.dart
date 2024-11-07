import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert'; // For UTF8 encoding/decoding
import 'dart:async'; // For StreamSubscription
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart'; // For Clipboard
import '../screens/home_screen.dart'; // For BulbSettings
import '../models/capture_data_model.dart'; // Import CaptureData

// Global constant to switch mocking on or off
const bool isMockMode = false; // Set to false to use real BLE

// BLE Service and Characteristic UUIDs
final Uuid serviceUuid = Uuid.parse("0000ffe0-0000-1000-8000-00805f9b34fb");
final Uuid characteristicUuid =
    Uuid.parse("0000ffe1-0000-1000-8000-00805f9b34fb");

// Interface for BLE operations
abstract class BleService {
  Stream<List<DiscoveredDevice>> scanForDevices();
  Future<void> connectToDevice(DiscoveredDevice device);
  Future<void> disconnectFromDevice();
  Future<void> writeCharacteristic(String value);
  Future<String> readCharacteristic();
  QualifiedCharacteristic? get characteristic;
  DiscoveredDevice? get connectedDevice;
}

// Real BLE Service using flutter_reactive_ble
class RealBleService implements BleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  QualifiedCharacteristic? _characteristic;
  DiscoveredDevice? _connectedDevice;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;

  @override
  QualifiedCharacteristic? get characteristic => _characteristic;

  @override
  DiscoveredDevice? get connectedDevice => _connectedDevice;

  @override
  Stream<List<DiscoveredDevice>> scanForDevices() async* {
    List<DiscoveredDevice> devices = [];
    await for (final device in _ble
        .scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)) {
      if (devices.every((d) => d.id != device.id)) {
        devices.add(device);
        yield devices;
      }
    }
  }

  @override
  Future<void> connectToDevice(DiscoveredDevice device) async {
    _connectedDevice = device;
    final completer = Completer<void>();

    _connectionSubscription = _ble
        .connectToDevice(
      id: device.id,
      servicesWithCharacteristicsToDiscover: {
        serviceUuid: [characteristicUuid]
      },
      connectionTimeout: const Duration(seconds: 5),
    )
        .listen((connectionState) {
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        _characteristic = QualifiedCharacteristic(
          deviceId: device.id,
          serviceId: serviceUuid,
          characteristicId: characteristicUuid,
        );
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else if (connectionState.connectionState ==
          DeviceConnectionState.disconnected) {
        _connectedDevice = null;
        _characteristic = null;
        if (!completer.isCompleted) {
          completer.completeError('Disconnected');
        }
      }
    }, onError: (error) {
      _connectedDevice = null;
      _characteristic = null;
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    return completer.future;
  }

  @override
  Future<void> disconnectFromDevice() async {
    await _connectionSubscription?.cancel();
    _connectedDevice = null;
    _characteristic = null;
  }

  @override
  Future<void> writeCharacteristic(String value) async {
    if (_characteristic == null) {
      throw Exception('Characteristic not found');
    }
    await _ble.writeCharacteristicWithResponse(
      _characteristic!,
      value: utf8.encode(value),
    );
  }

  @override
  Future<String> readCharacteristic() async {
    if (_characteristic == null) {
      throw Exception('Characteristic not found');
    }
    var value = await _ble.readCharacteristic(_characteristic!);
    return utf8.decode(value);
  }
}

// Mock BLE Service for testing without hardware
class MockBleService implements BleService {
  QualifiedCharacteristic? _characteristic;
  DiscoveredDevice? _connectedDevice;

  @override
  QualifiedCharacteristic? get characteristic => _characteristic;

  @override
  DiscoveredDevice? get connectedDevice => _connectedDevice;

  @override
  Stream<List<DiscoveredDevice>> scanForDevices() async* {
    await Future.delayed(Duration(seconds: 2)); // Simulate scan delay
    yield [
      DiscoveredDevice(
        id: '00:11:22:33:44:55',
        name: 'MockDevice',
        serviceData: {},
        manufacturerData: Uint8List(0),
        serviceUuids: [serviceUuid],
        rssi: -50,
      ),
    ];
  }

  @override
  Future<void> connectToDevice(DiscoveredDevice device) async {
    await Future.delayed(Duration(seconds: 1)); // Simulate connection delay
    _connectedDevice = device;
    _characteristic = QualifiedCharacteristic(
      deviceId: device.id,
      serviceId: serviceUuid,
      characteristicId: characteristicUuid,
    );
  }

  @override
  Future<void> disconnectFromDevice() async {
    await Future.delayed(
        Duration(milliseconds: 500)); // Simulate disconnection delay
    _connectedDevice = null;
    _characteristic = null;
  }

  @override
  Future<void> writeCharacteristic(String value) async {
    await Future.delayed(Duration(milliseconds: 500)); // Simulate write delay
    // You can handle the value if needed
  }

  @override
  Future<String> readCharacteristic() async {
    await Future.delayed(Duration(milliseconds: 500)); // Simulate read delay
    // Return simulated sensor data
    return '100,1.23,4.56,7.89,10.11,12.13,14.15,16.17,18.19,20.21,22.23,24.25,26.27,28.29,30.31,32.33,34.35,36.37,38.39';
  }
}

class AcquisitionTab extends StatefulWidget {
  const AcquisitionTab({super.key});

  @override
  State<AcquisitionTab> createState() => _AcquisitionTabState();
}

class _AcquisitionTabState extends State<AcquisitionTab> {
  late final BleService bleService;
  String connectionStatus = 'Disconnected';
  bool isScanning = false;
  List<DiscoveredDevice> discoveredDevices = [];
  bool isCapturing = false; // Added this variable

  // Text controllers for label and multiplier
  TextEditingController labelController = TextEditingController();
  TextEditingController multiplierController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    bleService = isMockMode ? MockBleService() : RealBleService();
  }

  @override
  void dispose() {
    bleService.disconnectFromDevice();
    labelController.dispose();
    multiplierController.dispose();
    super.dispose();
  }

  Future<void> requestPermissions() async {
    // Check and request location permission
    PermissionStatus locationPermission =
        await Permission.locationWhenInUse.status;
    if (locationPermission.isDenied || locationPermission.isPermanentlyDenied) {
      locationPermission = await Permission.locationWhenInUse.request();
      if (!locationPermission.isGranted) {
        // Permission denied, handle appropriately
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location permission is required to scan for BLE devices.')),
        );
        return;
      }
    }

    // For Android 12 and above, request Bluetooth permissions
    if (Theme.of(context).platform == TargetPlatform.android) {
      if (await Permission.bluetoothScan.isDenied) {
        await Permission.bluetoothScan.request();
      }
      if (await Permission.bluetoothConnect.isDenied) {
        await Permission.bluetoothConnect.request();
      }
    }
  }

  void startScan() async {
    if (isScanning) return;

    // Clear previous scan results
    discoveredDevices.clear();

    // Request permissions
    if (!isMockMode) {
      await requestPermissions();
    }

    setState(() {
      connectionStatus = 'Scanning...';
      isScanning = true;
    });

    bleService.scanForDevices().listen((deviceList) {
      setState(() {
        discoveredDevices = deviceList;
      });
    }).onDone(() {
      setState(() {
        isScanning = false;
        connectionStatus = 'Scan Complete';
      });
    });

    // Stop scanning after a timeout
    Future.delayed(const Duration(seconds: 5), () {
      setState(() {
        isScanning = false;
        connectionStatus = 'Scan Complete';
      });
    });
  }

  void connectToDevice(DiscoveredDevice device) async {
    setState(() {
      connectionStatus = 'Connecting...';
      isScanning = false;
      discoveredDevices.clear(); // Clear the device list
    });

    try {
      await bleService.connectToDevice(device);
      setState(() {
        connectionStatus = 'Connected';
      });
    } catch (e) {
      print('Connection error: $e');
      setState(() {
        connectionStatus = 'Disconnected';
      });
    }
  }

  void disconnectFromDevice() async {
    await bleService.disconnectFromDevice();
    setState(() {
      connectionStatus = 'Disconnected';
    });
  }

  void readData() async {
    if (bleService.characteristic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Characteristic not found')),
      );
      return;
    }

    setState(() {
      isCapturing = true; // Disable the capture button
    });

    int multiplier = int.tryParse(multiplierController.text) ?? 1;
    if (multiplier < 1) {
      multiplier = 1;
    }

    String label = labelController.text;

    // Access bulbSettings
    final bulbSettings = Provider.of<BulbSettings>(context, listen: false);
    String bulbState = bulbSettings.bulbState;

    // Access captureDataNotifier
    final captureDataNotifier =
        Provider.of<CaptureDataNotifier>(context, listen: false);

    try {
      for (int i = 0; i < multiplier; i++) {
        // Send command to device based on bulbState
        String command = 'bulb=$bulbState';
        await bleService.writeCharacteristic(command);

        // Wait for the device to process
        await Future.delayed(const Duration(milliseconds: 500));

        // Read response from the device
        String dataString = await bleService.readCharacteristic();
        print('Received data: $dataString');

        // Parse dataString to get numerical values
        List<String> stringValues = dataString.split(',');
        List<double> newData =
            stringValues.map((e) => double.tryParse(e) ?? 0.0).toList();

        // Generate a color for this capture
        Color color = Colors.primaries[
            captureDataNotifier.captures.length % Colors.primaries.length];

        // Add capture to notifier
        captureDataNotifier.addCapture(CaptureData(
          data: newData,
          label: label,
          color: color,
        ));
      }
    } catch (e) {
      print('Error reading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading data: $e')),
      );
    } finally {
      setState(() {
        isCapturing = false; // Re-enable the capture button
      });
    }
  }

  // Function to copy data to clipboard in CSV format
  void _copyDataToClipboard(List<CaptureData> captures) {
    // Define the headers
    List<String> headers = [
      'read_rate',
      '410nm',
      '435nm',
      '460nm',
      '485nm',
      '510nm',
      '535nm',
      '560nm',
      '585nm',
      '610nm',
      '645nm',
      '680nm',
      '705nm',
      '730nm',
      '760nm',
      '785nm',
      '810nm',
      '860nm',
      '940nm',
      'label', // Added label column
    ];

    // Start building the CSV string
    String csvData = headers.join(',') + '\n';

    // Append each row of data
    for (var capture in captures) {
      String row =
          capture.data.map((e) => e.toString()).join(',') + ',' + capture.label;
      csvData += row + '\n';
    }

    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: csvData));

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine the device name to display
    String deviceName = 'SS - Hardware';
    if (bleService.connectedDevice != null && connectionStatus == 'Connected') {
      deviceName = bleService.connectedDevice!.name.isNotEmpty
          ? bleService.connectedDevice!.name
          : 'Unnamed device';
    }

    // Access captures
    final captureDataNotifier = Provider.of<CaptureDataNotifier>(context);
    final captures = captureDataNotifier.captures;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeaderSection(
              connectionStatus: connectionStatus,
              onConnectionButtonPressed: () {
                if (connectionStatus == 'Connected') {
                  disconnectFromDevice();
                } else {
                  startScan();
                }
              },
              deviceName: deviceName, // Pass the device name here
            ),
            if (isScanning) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 10),
              const Text('Scanning for devices...'),
            ] else if (discoveredDevices.isNotEmpty &&
                connectionStatus != 'Connected') ...[
              DeviceList(
                devices: discoveredDevices,
                onDeviceSelected: (device) {
                  connectToDevice(device);
                },
              ),
            ] else if (connectionStatus == 'Connected') ...[
              const SizedBox(height: 20),
              ChartContainer(captures: captures),
              const SizedBox(height: 20),
              DataInfoSection(
                numberOfRows: captures.length,
                onCopyData: () => _copyDataToClipboard(captures),
              ),
              const SizedBox(height: 10),
              InputFields(
                labelController: labelController,
                multiplierController: multiplierController,
              ),
              const SizedBox(height: 20),
              CaptureButton(
                isConnected: connectionStatus == 'Connected' && !isCapturing,
                onPressed: readData,
              ),
              const SizedBox(height: 20),
            ] else ...[
              const Text('No devices found.'),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

// DeviceList Widget
class DeviceList extends StatelessWidget {
  final List<DiscoveredDevice> devices;
  final Function(DiscoveredDevice) onDeviceSelected;

  const DeviceList({
    Key? key,
    required this.devices,
    required this.onDeviceSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const Center(child: Text('No devices found'));
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: devices.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final device = devices[index];
        return ListTile(
          title: Text(device.name.isNotEmpty ? device.name : 'Unnamed device'),
          subtitle: Text(device.id),
          onTap: () => onDeviceSelected(device),
        );
      },
    );
  }
}

// Header Section Widget
class HeaderSection extends StatelessWidget {
  final String connectionStatus;
  final VoidCallback onConnectionButtonPressed;
  final String deviceName;

  const HeaderSection({
    Key? key,
    required this.connectionStatus,
    required this.onConnectionButtonPressed,
    required this.deviceName,
  }) : super(key: key);

  // Method to get status color based on connection status
  Color getStatusColor() {
    if (connectionStatus == 'Connected') {
      return Colors.green;
    } else if (connectionStatus == 'Scanning...' ||
        connectionStatus == 'Connecting...' ||
        connectionStatus == 'Scan Complete') {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // Method to get the appropriate Bluetooth icon
  IconData getStatusIcon() {
    if (connectionStatus == 'Connected') {
      return Icons.bluetooth_connected;
    } else {
      return Icons.bluetooth_disabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First Row: Device Name and Bluetooth Button
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              deviceName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: Icon(
                getStatusIcon(),
                color: Colors.black,
                size: 24,
              ),
              onPressed: onConnectionButtonPressed,
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Second Row: Connection Status
        DecoratedBox(
          decoration: BoxDecoration(
            color: getStatusColor(),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              connectionStatus,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// InputFields Widget
class InputFields extends StatelessWidget {
  final TextEditingController labelController;
  final TextEditingController multiplierController;

  const InputFields({
    Key? key,
    required this.labelController,
    required this.multiplierController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: labelController,
          decoration: InputDecoration(
            labelText: 'Label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: multiplierController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Multiplier',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
      ],
    );
  }
}

// ChartContainer Widget
class ChartContainer extends StatelessWidget {
  final List<CaptureData> captures;

  const ChartContainer({Key? key, required this.captures}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (captures.isEmpty) {
      return Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.width * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: const Center(child: Text('No data to display')),
      );
    }

    // Collect data points excluding read_rate to determine minY and maxY
    List<double> allDataPoints =
        captures.expand((c) => c.data.skip(1)).toList();

    double minY = allDataPoints.reduce((a, b) => a < b ? a : b);
    double maxY = allDataPoints.reduce((a, b) => a > b ? a : b);

    // Adjust minY and maxY if necessary (same as before)
    if (minY == maxY) {
      minY = minY - 1;
      maxY = maxY + 1;
    } else {
      double yRange = maxY - minY;
      minY = minY - yRange * 0.1;
      maxY = maxY + yRange * 0.1;
    }

    if (minY > maxY) {
      double temp = minY;
      minY = maxY;
      maxY = temp;
    }

    if (minY < 0) {
      minY = 0;
    }

    double yInterval = (maxY - minY) / 5;
    if (yInterval == 0) {
      yInterval = maxY == 0 ? 1 : maxY / 5;
    }

    // Define the wavelengths for the x-axis labels
    const wavelengths = [
      '',
      '410nm',
      '435nm',
      '460nm',
      '485nm',
      '510nm',
      '535nm',
      '560nm',
      '585nm',
      '610nm',
      '645nm',
      '680nm',
      '705nm',
      '730nm',
      '760nm',
      '785nm',
      '810nm',
      '860nm',
      '940nm'
    ];

    // Build lineBarsData excluding read_rate
    List<LineChartBarData> lineBarsData = captures.map((capture) {
      return LineChartBarData(
        spots: List.generate(
          capture.data.length - 1, // Exclude read_rate
          (index) => FlSpot((index + 1).toDouble(), capture.data[index + 1]),
        ),
        isCurved: true,
        color: capture.color,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
      );
    }).toList();

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.width * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: yInterval,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt() - 1;
                  if (index < 0 || index >= wavelengths.length) {
                    return const SizedBox.shrink();
                  }
                  return Transform.rotate(
                    angle: -1.5708,
                    child: Text(
                      wavelengths[index],
                      style: const TextStyle(fontSize: 8),
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
          ),
          minY: minY,
          maxY: maxY,
          minX: 1,
          maxX: wavelengths.length.toDouble(),
          lineBarsData: lineBarsData,
        ),
      ),
    );
  }
}

// DataInfoSection Widget with Copy Data Button
class DataInfoSection extends StatelessWidget {
  final int numberOfRows;
  final VoidCallback onCopyData;

  const DataInfoSection({
    Key? key,
    required this.numberOfRows,
    required this.onCopyData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Number of Rows: $numberOfRows',
          style: const TextStyle(fontSize: 16),
        ),
        TextButton(
          onPressed: onCopyData,
          child: const Text('Copy Data'),
        ),
      ],
    );
  }
}

// Capture Button Widget
class CaptureButton extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onPressed;

  const CaptureButton({
    super.key,
    required this.isConnected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isConnected ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        child: const Text(
          'Capture data',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }
}
