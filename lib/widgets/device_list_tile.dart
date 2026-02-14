import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceListTile extends StatelessWidget {
  final BluetoothDevice device;
  final int? rssi;
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onTap;

  const DeviceListTile({
    super.key,
    required this.device,
    this.rssi,
    required this.isConnected,
    required this.isConnecting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceName =
        device.platformName.isNotEmpty ? device.platformName : 'Unknown Device';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          _getDeviceIcon(),
          color: isConnected ? Colors.green : theme.colorScheme.primary,
          size: 32,
        ),
        title: Text(
          deviceName,
          style: TextStyle(
            fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          isConnected
              ? 'Connected'
              : rssi != null
                  ? 'Signal: ${_getSignalStrength(rssi!)}'
                  : 'Paired',
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isConnected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.chevron_right),
        onTap: isConnecting ? null : onTap,
      ),
    );
  }

  IconData _getDeviceIcon() {
    final name = device.platformName.toLowerCase();
    if (name.contains('speaker') || name.contains('soundbar')) {
      return Icons.speaker;
    } else if (name.contains('headphone') || name.contains('airpod') || name.contains('buds')) {
      return Icons.headphones;
    } else if (name.contains('car') || name.contains('auto')) {
      return Icons.directions_car;
    }
    return Icons.bluetooth_audio;
  }

  String _getSignalStrength(int rssi) {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Good';
    if (rssi >= -70) return 'Fair';
    return 'Weak';
  }
}
