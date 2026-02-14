import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/constants.dart';

enum BluetoothConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
}

class BluetoothService extends ChangeNotifier {
  // State
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  BluetoothDevice? _connectedDevice;
  List<ScanResult> _scanResults = [];
  String? _errorMessage;
  bool _isBluetoothOn = false;

  // Subscriptions
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  // Getters
  BluetoothConnectionState get connectionState => _connectionState;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<ScanResult> get scanResults => _scanResults;
  String? get errorMessage => _errorMessage;
  bool get isBluetoothOn => _isBluetoothOn;
  bool get isConnected =>
      _connectionState == BluetoothConnectionState.connected;

  BluetoothService() {
    _init();
  }

  void _init() {
    // Listen to Bluetooth adapter state
    _adapterStateSubscription =
        FlutterBluePlus.adapterState.listen((state) {
      _isBluetoothOn = state == BluetoothAdapterState.on;
      if (!_isBluetoothOn) {
        _connectionState = BluetoothConnectionState.disconnected;
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
    _connectionState = BluetoothConnectionState.scanning;
    _scanResults = [];
    notifyListeners();

    // Cancel any existing scan subscription
    await _scanSubscription?.cancel();

    // Start scanning
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
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
      await FlutterBluePlus.startScan(
        timeout: AppConstants.scanDuration,
        androidUsesFineLocation: false,
      );
    } catch (e) {
      _errorMessage = 'Scan failed: ${e.toString()}';
      _connectionState = BluetoothConnectionState.disconnected;
      notifyListeners();
      return;
    }

    // When scan completes
    await Future.delayed(AppConstants.scanDuration);
    _connectionState = _connectedDevice != null
        ? BluetoothConnectionState.connected
        : BluetoothConnectionState.disconnected;
    notifyListeners();
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    if (_connectionState == BluetoothConnectionState.scanning) {
      _connectionState = _connectedDevice != null
          ? BluetoothConnectionState.connected
          : BluetoothConnectionState.disconnected;
      notifyListeners();
    }
  }

  /// Connect to a Bluetooth device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    _errorMessage = null;
    _connectionState = BluetoothConnectionState.connecting;
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
      _connectionState = BluetoothConnectionState.connected;

      // Listen to connection state changes
      _deviceStateSubscription?.cancel();
      _deviceStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _connectionState = BluetoothConnectionState.disconnected;
          notifyListeners();
        }
      });

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Connection failed: ${e.toString()}';
      _connectionState = BluetoothConnectionState.disconnected;
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
    _connectionState = BluetoothConnectionState.disconnected;
    notifyListeners();
  }

  /// Get list of bonded (paired) devices
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await FlutterBluePlus.bondedDevices;
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
