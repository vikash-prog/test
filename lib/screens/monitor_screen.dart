import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/sensor_sample.dart';
import '../services/ble_service.dart';
import '../widgets/sensor_card.dart';
import '../widgets/data_row_tile.dart';

class MonitorScreen extends StatefulWidget {
  final BluetoothDevice device;
  final BleService ble;
  const MonitorScreen({super.key, required this.device, required this.ble});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with SingleTickerProviderStateMixin {
  SensorSample? _latest;
  int _packetsReceived = 0;
  int _samplesReceived = 0;
  int _packetRate = 0;
  int _packetsSinceLastTick = 0;

  final List<SensorSample> _log = [];
  static const int _maxLog = 200;
  final ScrollController _scrollCtrl = ScrollController();

  bool _connected = true;
  StreamSubscription<List<SensorSample>>? _sampleSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  late TabController _tabCtrl;
  Timer? _rateTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _sampleSub = widget.ble.sampleStream.listen(_onPacket);
    _connSub = widget.ble.connectionState.listen((state) {
      if (mounted) {
        setState(() =>
            _connected = state == BluetoothConnectionState.connected);
      }
    });
    _rateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _packetRate = _packetsSinceLastTick;
          _packetsSinceLastTick = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _rateTimer?.cancel();
    _sampleSub?.cancel();
    _connSub?.cancel();
    _scrollCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onPacket(List<SensorSample> samples) {
    if (!mounted) return;
    _packetsReceived++;
    _packetsSinceLastTick++;
    _samplesReceived += samples.length;
    setState(() {
      _latest = samples.last;
      _log.addAll(samples);
      if (_log.length > _maxLog) _log.removeRange(0, _log.length - _maxLog);
    });
    if (_tabCtrl.index == 1 && _scrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _disconnect() async {
    await widget.ble.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(4);

  @override
  Widget build(BuildContext context) {
    final s = _latest;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Monitor', style: TextStyle(fontSize: 16)),
            Text(
              widget.device.platformName.isNotEmpty
                  ? widget.device.platformName
                  : widget.device.remoteId.str,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _connected
                  ? Colors.green.shade700
                  : Colors.red.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _connected ? '● Connected' : '○ Disconnected',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            tooltip: 'Disconnect',
            onPressed: _disconnect,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Dashboard'),
            Tab(icon: Icon(Icons.list_alt_outlined),  text: 'Raw Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildDashboard(s), _buildLog()],
      ),
    );
  }

  Widget _buildDashboard(SensorSample? s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Stats
          Row(children: [
            _statChip(Icons.inbox_outlined, '$_packetsReceived', 'Packets'),
            const SizedBox(width: 8),
            _statChip(Icons.sensors, '$_samplesReceived', 'Samples'),
            const SizedBox(width: 8),
            _statChip(Icons.speed, '$_packetRate/s', 'Rate'),
          ]),
          const SizedBox(height: 12),

          // Timestamp
          if (s != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('Uptime: ${_formatUptime(s.timestamp)}',
                    style: const TextStyle(fontFamily: 'monospace')),
                subtitle: Text('timestamp = ${s.timestamp} ms',
                    style: const TextStyle(fontSize: 11)),
              ),
            ),
          const SizedBox(height: 8),

          SensorCard(
            label: 'Accelerometer  (m/s²)',
            x: _fmt(s?.accelX),
            y: _fmt(s?.accelY),
            z: _fmt(s?.accelZ),
            color: Colors.blueAccent,
            icon: Icons.vibration,
          ),
          const SizedBox(height: 8),

          SensorCard(
            label: 'Gyroscope  (rad/s)',
            x: _fmt(s?.gyroX),
            y: _fmt(s?.gyroY),
            z: _fmt(s?.gyroZ),
            color: Colors.deepOrangeAccent,
            icon: Icons.rotate_90_degrees_ccw_outlined,
          ),
          const SizedBox(height: 8),

          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(children: [
                const Icon(Icons.speed, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Speed',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold)),
                    Text('${_fmt(s?.speed)} unit',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ]),
            ),
          ),

          if (s == null)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Column(children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Waiting for data…',
                    style: TextStyle(color: Colors.grey)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildLog() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          color: theme.colorScheme.primaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: DefaultTextStyle(
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
              fontFamily: 'monospace',
            ),
            child: const Row(children: [
              SizedBox(width: 58, child: Text('TIME',  textAlign: TextAlign.right)),
              SizedBox(width: 54, child: Text('aX',    textAlign: TextAlign.right)),
              SizedBox(width: 54, child: Text('aY',    textAlign: TextAlign.right)),
              SizedBox(width: 54, child: Text('aZ',    textAlign: TextAlign.right)),
              SizedBox(width: 54, child: Text('gX',    textAlign: TextAlign.right)),
              SizedBox(width: 54, child: Text('gY',    textAlign: TextAlign.right)),
              SizedBox(width: 54, child: Text('gZ',    textAlign: TextAlign.right)),
              SizedBox(width: 50, child: Text('SPD',   textAlign: TextAlign.right)),
            ]),
          ),
        ),
        Expanded(
          child: _log.isEmpty
              ? const Center(child: Text('No samples yet…'))
              : ListView.builder(
                  controller: _scrollCtrl,
                  itemCount: _log.length,
                  itemExtent: 28,
                  itemBuilder: (_, i) =>
                      DataRowTile(sample: _log[i], index: i),
                ),
        ),
        Container(
          color: theme.colorScheme.surfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Last ${_log.length} of $_samplesReceived samples',
                  style: const TextStyle(fontSize: 11)),
              Text('$_packetRate pkt/s',
                  style: const TextStyle(
                      fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String value, String label) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(children: [
              Icon(icon, size: 18),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ),
        ),
      );

  String _formatUptime(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs =
        (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '${d.inHours}:$m:$s.$cs';
  }
}