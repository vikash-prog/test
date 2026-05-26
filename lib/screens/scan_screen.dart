import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart';
import 'monitor_screen.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final BleService _ble = BleService();
  List<ScanResult> _results = [];
  bool _isScanning = false;
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    _ble.scanResults.listen((r) => setState(() => _results = r));
  }

  @override
  void dispose() {
    _ble.stopScan();
    _ble.dispose();
    super.dispose();
  }

 Future<bool> _requestPermissions() async {
  if (Platform.isAndroid) {
    // Check Android version
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 31) {
      // Android 12+
      final scan    = await Permission.bluetoothScan.request();
      final connect = await Permission.bluetoothConnect.request();
      return scan.isGranted && connect.isGranted;
    } else {
      // Android 11 and below
      final location = await Permission.locationWhenInUse.request();
      return location.isGranted;
    }
  }
  if (Platform.isIOS) {
    final s = await Permission.bluetooth.request();
    return s.isGranted;
  }
  return true;
}

  Future<void> _startScan() async {
    final ok = await _requestPermissions();
    if (!ok) { _showSnack('Bluetooth permissions denied.'); return; }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _showSnack('Please enable Bluetooth.');
      return;
    }

    setState(() { _results.clear(); _isScanning = true; });
    await _ble.startScan();
    await Future.delayed(const Duration(seconds: 10));
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _stopScan() async {
    await _ble.stopScan();
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _connect(ScanResult result) async {
    await _stopScan();
    setState(() => _connectingId = result.device.remoteId.str);
    try {
      await _ble.connect(result.device);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MonitorScreen(device: result.device, ble: _ble),
      ));
    } catch (e) {
      _showSnack('Connection failed: $e');
    } finally {
      if (mounted) setState(() => _connectingId = null);
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('BMI088 — Device Scanner'),
        centerTitle: true,
        actions: [
          if (_isScanning)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _stopScan,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Banner ──────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: theme.colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Looking for "BMI088_Sensor"',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Service: 4fafc201-…914b',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace')),
              ],
            ),
          ),

          // ── Scan button ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isScanning
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Scanning…'),
                    ],
                  )
                : FilledButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('Scan for Devices'),
                  ),
          ),

          // ── Device list ─────────────────────────────────────────────────────
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _isScanning
                          ? 'Searching for nearby devices…'
                          : 'Tap "Scan for Devices" to begin.',
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      final name = r.device.platformName.isNotEmpty
                          ? r.device.platformName
                          : '(unknown)';
                      final id = r.device.remoteId.str;
                      final isTarget = name == 'BMI088_Sensor';
                      final isConnecting = _connectingId == id;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isTarget
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceVariant,
                          child: Icon(
                            isTarget ? Icons.sensors : Icons.bluetooth,
                            color: isTarget
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(name,
                            style: TextStyle(
                                fontWeight: isTarget
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        subtitle: Text(id,
                            style: const TextStyle(
                                fontSize: 11, fontFamily: 'monospace')),
                        trailing: isConnecting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${r.rssi} dBm',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                  const SizedBox(width: 8),
                                  FilledButton.tonal(
                                    onPressed: () => _connect(r),
                                    child: const Text('Connect'),
                                  ),
                                ],
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}