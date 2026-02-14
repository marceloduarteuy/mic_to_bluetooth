import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../services/audio_service.dart';
import '../services/permission_service.dart';
import '../widgets/device_list_tile.dart';
import '../widgets/mic_button.dart';
import '../widgets/volume_slider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _permissionsGranted = false;
  bool _showingPairedDevices = true;
  List<BluetoothDevice> _pairedDevices = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep audio running when app goes to background
    if (state == AppLifecycleState.paused) {
      // Audio continues in background due to foreground service
    }
  }

  Future<void> _requestPermissions() async {
    final permissionService = context.read<PermissionService>();
    final granted = await permissionService.requestAllPermissions();
    setState(() {
      _permissionsGranted = granted;
    });

    if (granted) {
      _loadPairedDevices();
    } else {
      _showPermissionDeniedDialog();
    }
  }

  Future<void> _loadPairedDevices() async {
    final btService = context.read<BluetoothService>();
    final devices = await btService.getBondedDevices();
    setState(() {
      _pairedDevices = devices;
    });
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'This app needs microphone and Bluetooth permissions to work. '
          'Please grant the permissions in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final permissionService = context.read<PermissionService>();
              await permissionService.openSettings();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _requestPermissions();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mic to Bluetooth'),
        centerTitle: true,
        actions: [
          Consumer<BluetoothService>(
            builder: (context, btService, _) {
              if (btService.isConnected) {
                return IconButton(
                  icon: const Icon(Icons.bluetooth_disabled),
                  tooltip: 'Disconnect',
                  onPressed: () => btService.disconnect(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: !_permissionsGranted
          ? _buildPermissionRequest()
          : Consumer2<BluetoothService, AudioService>(
              builder: (context, btService, audioService, _) {
                return Column(
                  children: [
                    // Connection status banner
                    _buildConnectionBanner(btService),

                    // Main content
                    Expanded(
                      child: btService.isConnected
                          ? _buildMicControls(btService, audioService)
                          : _buildDeviceSelector(btService),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 64, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              'Permissions Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This app needs access to your microphone and Bluetooth to stream audio.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _requestPermissions,
              child: const Text('Grant Permissions'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBanner(BluetoothService btService) {
    if (!btService.isBluetoothOn) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Colors.orange.shade800,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled, size: 20),
            SizedBox(width: 8),
            Text('Please turn on Bluetooth'),
          ],
        ),
      );
    }

    if (btService.isConnected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Colors.green.shade800,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_connected, size: 20),
            const SizedBox(width: 8),
            Text(
              'Connected to ${btService.connectedDevice?.platformName ?? "device"}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDeviceSelector(BluetoothService btService) {
    return Column(
      children: [
        // Toggle between paired and scan
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Paired'),
                icon: Icon(Icons.bluetooth),
              ),
              ButtonSegment(
                value: false,
                label: Text('Scan'),
                icon: Icon(Icons.bluetooth_searching),
              ),
            ],
            selected: {_showingPairedDevices},
            onSelectionChanged: (selected) {
              setState(() {
                _showingPairedDevices = selected.first;
              });
              if (!_showingPairedDevices) {
                btService.startScan();
              } else {
                btService.stopScan();
                _loadPairedDevices();
              }
            },
          ),
        ),

        // Device list
        Expanded(
          child: _showingPairedDevices
              ? _buildPairedDeviceList(btService)
              : _buildScannedDeviceList(btService),
        ),
      ],
    );
  }

  Widget _buildPairedDeviceList(BluetoothService btService) {
    if (_pairedDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No paired Bluetooth devices found'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadPairedDevices,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPairedDevices,
      child: ListView.builder(
        itemCount: _pairedDevices.length,
        itemBuilder: (context, index) {
          final device = _pairedDevices[index];
          return DeviceListTile(
            device: device,
            isConnected:
                btService.connectedDevice?.remoteId == device.remoteId,
            isConnecting:
                btService.connectionState == BluetoothConnectionState.connecting,
            onTap: () => btService.connectToDevice(device),
          );
        },
      ),
    );
  }

  Widget _buildScannedDeviceList(BluetoothService btService) {
    if (btService.connectionState == BluetoothConnectionState.scanning) {
      if (btService.scanResults.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Scanning for devices...'),
            ],
          ),
        );
      }
    }

    if (btService.scanResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No devices found'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => btService.startScan(),
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Again'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: btService.scanResults.length,
      itemBuilder: (context, index) {
        final result = btService.scanResults[index];
        return DeviceListTile(
          device: result.device,
          rssi: result.rssi,
          isConnected:
              btService.connectedDevice?.remoteId == result.device.remoteId,
          isConnecting:
              btService.connectionState == BluetoothConnectionState.connecting,
          onTap: () => btService.connectToDevice(result.device),
        );
      },
    );
  }

  Widget _buildMicControls(
      BluetoothService btService, AudioService audioService) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mic button
          MicButton(
            micState: audioService.micState,
            isEnabled: btService.isConnected && audioService.isInitialized,
            onPressed: () => audioService.toggleMicStreaming(),
          ),

          const SizedBox(height: 48),

          // Volume control
          VolumeSlider(
            label: 'Microphone Volume',
            icon: Icons.mic,
            value: audioService.micVolume,
            onChanged: audioService.setMicVolume,
            enabled: true,
            activeColor:
                audioService.isMicActive ? Colors.red : null,
          ),

          const Spacer(),

          // Error message
          if (audioService.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      audioService.errorMessage!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          // Instructions
          const SizedBox(height: 16),
          Text(
            audioService.isMicActive
                ? 'Your voice is being streamed.\nOther apps\' audio will be ducked.'
                : 'Tap the mic button to start speaking.\nMusic from other apps will lower in volume.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
