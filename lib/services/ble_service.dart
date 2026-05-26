import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/sensor_sample.dart';

const _serviceUuid        = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const _characteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

class BleService {
  final _scanResultsController =
      StreamController<List<ScanResult>>.broadcast();
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;

  final Map<String, ScanResult> _seen = {};
  StreamSubscription<List<ScanResult>>? _scanSub;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;

  final _sampleController =
      StreamController<List<SensorSample>>.broadcast();
  Stream<List<SensorSample>> get sampleStream => _sampleController.stream;

  final _connectionStateController =
      StreamController<BluetoothConnectionState>.broadcast();
  Stream<BluetoothConnectionState> get connectionState =>
      _connectionStateController.stream;

  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  StreamSubscription<List<int>>? _notifySub;

  Future<void> startScan() async {
    _seen.clear();
    await FlutterBluePlus.stopScan();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        _seen[r.device.remoteId.str] = r;
      }
      _scanResultsController.add(_seen.values.toList());
    });
    await FlutterBluePlus.startScan(
      withServices: [],
      timeout: const Duration(seconds: 10),
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
  }

  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    _device = device;

    await device.connect(autoConnect: false);

// VERY IMPORTANT
    await Future.delayed(const Duration(seconds: 2));

// safer MTU
    await device.requestMtu(247);

  _connStateSub = device.connectionState.listen((state) {
      _connectionStateController.add(state);
      if (state == BluetoothConnectionState.disconnected) {
        _cleanup();
      }
    });

   

    final services = await device.discoverServices();

    // ── Print ALL discovered UUIDs so we can see exactly what ESP32 sends ──
    print('======= DISCOVERED SERVICES =======');
    for (final svc in services) {
      print('SERVICE UUID: [${svc.uuid.toString()}]');
      for (final chr in svc.characteristics) {
        print('   CHAR UUID: [${chr.uuid.toString()}]');
      }
    }
    print('===================================');
    print('LOOKING FOR SERVICE:  [$_serviceUuid]');
    print('LOOKING FOR CHAR:     [$_characteristicUuid]');

    // ── Try to match ────────────────────────────────────────────────────────
    BluetoothCharacteristic? found;

    for (final svc in services) {
      final s = svc.uuid.toString().toLowerCase().trim();
      final sMatch = s == _serviceUuid || s.startsWith(_serviceUuid);
      print('Comparing service: [$s] match=$sMatch');

      for (final chr in svc.characteristics) {
        final c = chr.uuid.toString().toLowerCase().trim();
        final cMatch = c == _characteristicUuid || c.startsWith(_characteristicUuid);
        print('  Comparing char: [$c] match=$cMatch');

        if (sMatch && cMatch) {
          found = chr;
        }
      }
    }

    if (found == null) {
      // Last resort — try ANY characteristic that has notify property
      print('Exact match failed — trying any NOTIFY characteristic...');
      for (final svc in services) {
        for (final chr in svc.characteristics) {
          if (chr.properties.notify) {
            print('  Found notify char: [${chr.uuid}] in service [${svc.uuid}]');
            found = chr;
          }
        }
      }
    }

    if (found == null) {
      throw Exception(
        'BMI088 characteristic not found.\n'
        'Check terminal/logcat for the actual UUIDs printed above.',
      );
    }

    _characteristic = found;
    await found.setNotifyValue(true);
    _notifySub = found.onValueReceived.listen(_onPacket);
    print('SUCCESS: Subscribed to [${found.uuid}]');
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    await _connStateSub?.cancel();
    _connStateSub = null;
    await _characteristic?.setNotifyValue(false).catchError((_) {});
    _characteristic = null;
    await _device?.disconnect().catchError((_) {});
    _device = null;
  }

  void _cleanup() {
    _notifySub?.cancel();
    _notifySub = null;
    _characteristic = null;
  }

  void _onPacket(List<int> raw) {
    if (raw.length < SensorSample.samplesPerPacket * SensorSample.bytesPerSample) {
      print('Short packet: ${raw.length} bytes (need ${SensorSample.samplesPerPacket * SensorSample.bytesPerSample})');
      return;
    }
    final samples = SensorSample.parsePacket(raw);
    if (samples.isNotEmpty) _sampleController.add(samples);
  }

  Future<void> dispose() async {
    await disconnect();
    await _scanResultsController.close();
    await _sampleController.close();
    await _connectionStateController.close();
  }
}