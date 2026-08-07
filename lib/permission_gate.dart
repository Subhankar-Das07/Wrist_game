import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';

/// PermissionGate
///
/// First screen the user sees. Checks camera permission status and either:
/// - Proceeds to [onGranted] if permission is already granted
/// - Shows a branded permission request UI if not yet granted
/// - Shows a "permanently denied" UI with deep link to app settings if blocked
class PermissionGate extends StatefulWidget {
  final Widget child;
  const PermissionGate({super.key, required this.child});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> with WidgetsBindingObserver {
  _PermStatus _status = _PermStatus.checking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when user returns from Settings
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    setState(() {
      if (status.isGranted) {
        _status = _PermStatus.granted;
      } else if (status.isPermanentlyDenied) {
        _status = _PermStatus.permanentlyDenied;
      } else {
        _status = _PermStatus.denied;
      }
    });
  }

  Future<void> _requestPermission() async {
    final result = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      if (result.isGranted) {
        _status = _PermStatus.granted;
      } else if (result.isPermanentlyDenied) {
        _status = _PermStatus.permanentlyDenied;
      } else {
        _status = _PermStatus.denied;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_status == _PermStatus.granted) return widget.child;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyan.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.cyanAccent, width: 2),
                ),
                child: Icon(
                  _status == _PermStatus.permanentlyDenied
                      ? Icons.no_photography_outlined
                      : Icons.camera_alt_outlined,
                  size: 80,
                  color: Colors.cyanAccent,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                _status == _PermStatus.permanentlyDenied
                    ? 'Camera Access Blocked'
                    : 'Camera Permission Required',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Body
              Text(
                _status == _PermStatus.permanentlyDenied
                    ? 'Camera permission was permanently denied.\n\nPlease open App Settings, go to Permissions → Camera, and enable it to play Jesture.'
                    : 'Jesture uses your front camera to track your fist movements in real time.\n\nNo video or images are ever recorded, stored, or transmitted.',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Primary Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(
                    _status == _PermStatus.permanentlyDenied
                        ? Icons.settings_outlined
                        : Icons.camera_alt,
                    size: 24,
                  ),
                  label: Text(
                    _status == _PermStatus.permanentlyDenied
                        ? 'Open App Settings'
                        : 'Grant Camera Access',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _status == _PermStatus.permanentlyDenied
                      ? () => AppSettings.openAppSettings()
                      : _requestPermission,
                ),
              ),

              if (_status == _PermStatus.checking) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Colors.cyanAccent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _PermStatus { checking, granted, denied, permanentlyDenied }
