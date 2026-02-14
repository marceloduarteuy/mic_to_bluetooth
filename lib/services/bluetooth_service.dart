import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../utils/constants.dart';

enum BtConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
}

class BluetoothService extends ChangeNotifier {
  // State
  BtConnectionState _connectionState = BtConnectionState.disconnected;
  fbp.BluetoothDevice? _connectedDevice;
  fbp.DeviceIdentifier? _connectingDeviceId; // Track which device is connecting
  List<fbp.ScanResult> _scanResults = [];
  String? _errorMessage;
  bool _isBluetoothOn = false;

  // Subscriptions
  StreamSubscription<List<fbp.ScanResult>>? _scanSubscription;
  StreamSubscription<fbp.BluetoothConnectionState>? _deviceStateSubscription;
  StreamSubscription<fbp.BluetoothAdapterState>? _adapterStateSubscription;

  // Getters
  BtConnectionState get connectionState => _connectionState;
  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;
  fbp.DeviceIdentifier? get connectingDeviceId => _connectingDeviceId;
  List<fbp.ScanResult> get scanResults => _scanResults;
  String? get errorMessage => _errorMessage;
  bool get isBluetoothOn => _isBluetoothOn;
  bool get isConnected => _connectionState == BtConnectionState.connected;

  /// Check if a specific device is currently connecting
  bool isDeviceConnecting(fbp.DeviceIdentifier deviceId) {
    return _connectionState == BtConnectionState.connecting &&
           _connectingDeviceId == deviceId;
  }

  BluetoothService() {
    _init();
  }

  void _init() {
    // Listen to Bluetooth adapter state
    _adapterStateSubscription =
        fbp.FlutterBluePlus.adapterState.listen((state) {
      _isBluetoothOn = state == fbp.BluetoothAdapterState.on;
      if (!_isBluetoothOn) {
        _connectionState = BtConnectionState.disconnected;
        _connectedDevice = null;
        _scanResults = [];
      }
      notifyListeners();
    });
  }

  /// Start scanning for Bluetooth devices
  Future<void> startScan() async {
    if (!_isBluetoothOn) {
      _errorMessage = 'Please turn on Bluetooth';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _connectionState = BtConnectionState.scanning;
    _scanResults = [];
    notifyListeners();

    // Cancel any existing scan subscription
    await _scanSubscription?.cancel();

    // Start scanning
    _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
      // Filter to show only audio devices (speakers, headphones)
      // We check for audio-related service UUIDs or device names
      _scanResults = results.where((r) {
        // Include devices that are likely audio devices
        // A2DP Audio Sink UUID: 0000110b-0000-1000-8000-00805f9b34fb
        // Or just show all devices and let user choose
        return r.device.platformName.isNotEmpty;
      }).toList();

      // Sort by signal strength
      _scanResults.sort((a, b) => b.rssi.compareTo(a.rssi));
      notifyListeners();
    });

    try {
      await fbp.FlutterBluePlus.startScan(
        timeout: AppConstants.scanDuration,
        androidUsesFineLocation: false,
      );
    } catch (e) {
      _errorMessage = 'Scan failed: ${e.toString()}';
      _connectionState = BtConnectionState.disconnected;
      notifyListeners();
      return;
    }

    // When scan completes
    await Future.delayed(AppConstants.scanDuration);
    _connectionState = _connectedDevice != null
        ? BtConnectionState.connected
        : BtConnectionState.disconnected;
    notifyListeners();
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await fbp.FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    if (_connectionState == BtConnectionState.scanning) {
      _connectionState = _connectedDevice != null
          ? BtConnectionState.connected
          : BtConnectionState.disconnected;
      notifyListeners();
    }
  }

  /// Connect to a Bluetooth device
  Future<bool> connectToDevice(fbp.BluetoothDevice device) async {
    _errorMessage = null;
    _connectionState = BtConnectionState.connecting;
    _connectingDeviceId = device.remoteId; // Track which device is connecting
    notifyListeners();

    try {
      // Stop scanning first
      await stopScan();

      // Connect to device
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice = device;
      _connectionState = BtConnectionState.connected;
      _connectingDeviceId = null;

      // Listen to connection state changes
      _deviceStateSubscription?.cancel();
      _deviceStateSubscription = device.connectionState.listen((state) {
        if (state == fbp.BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _connectionState = BtConnectionState.disconnected;
          notifyListeners();
        }
      });

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Connection failed: ${e.toString()}';
      _connectionState = BtConnectionState.disconnected;
      _connectingDeviceId = null;
      _connectedDevice = null;
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    try {
      await _connectedDevice?.disconnect();
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
    _connectedDevice = null;
    _connectionState = BtConnectionState.disconnected;
    notifyListeners();
  }

  /// Get list of bonded (paired) devices
  Future<List<fbp.BluetoothDevice>> getBondedDevices() async {
    try {
      return await fbp.FlutterBluePlus.bondedDevices;
    } catch (e) {
      _errorMessage = 'Failed to get paired devices: ${e.toString()}';
      notifyListeners();
      return [];
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _deviceStateSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    super.dispose();
  }
}
