import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionOutcome { granted, denied, permanentlyDenied }

class PermissionHelper {
  PermissionHelper._();

  static Future<PermissionOutcome> ensureMicrophone() {
    return _ensure(Permission.microphone);
  }

  static Future<PermissionOutcome> ensureCamera() {
    return _ensure(Permission.camera);
  }

  static Future<PermissionOutcome> ensureCall({required bool video}) async {
    final mic = await ensureMicrophone();
    if (mic != PermissionOutcome.granted) return mic;
    if (video) {
      return ensureCamera();
    }
    return PermissionOutcome.granted;
  }

  static Future<PermissionOutcome> _ensure(Permission permission) async {
    var status = await permission.status;
    if (status.isGranted || status.isLimited) {
      return PermissionOutcome.granted;
    }
    status = await permission.request();
    if (status.isGranted || status.isLimited) {
      return PermissionOutcome.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionOutcome.permanentlyDenied;
    }
    return PermissionOutcome.denied;
  }

  static Future<void> showDeniedDialog(
    BuildContext context, {
    required String message,
    required bool permanentlyDenied,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Permission needed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not now'),
            ),
            if (permanentlyDenied)
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text('Open settings'),
              )
            else
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Try again'),
              ),
          ],
        );
      },
    );
  }
}
