import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request all permissions needed for the app
  Future<bool> requestAllPermissions() async {
    final permissions = [
      Permission.microphone,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ];

    // Request all permissions
    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // Check if all critical permissions are granted
    bool micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    bool btConnectGranted =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    bool btScanGranted =
        statuses[Permission.bluetoothScan]?.isGranted ?? false;

    return micGranted && btConnectGranted && btScanGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> isMicrophoneGranted() async {
    return await Permission.microphone.isGranted;
  }

  /// Check if Bluetooth permissions are granted
  Future<bool> isBluetoothGranted() async {
    bool connect = await Permission.bluetoothConnect.isGranted;
    bool scan = await Permission.bluetoothScan.isGranted;
    return connect && scan;
  }

  /// Open app settings if permissions are permanently denied
  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
