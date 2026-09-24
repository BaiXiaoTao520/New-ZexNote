import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel installerChannel = MethodChannel("com.zex.note/installer");

const String publicDownloadPath = "/storage/emulated/0/Download";

Future<Directory> getConfiguredDownloadDirectory() async {
  final baseDirectory = Directory(publicDownloadPath);
  final prefs = await SharedPreferences.getInstance();
  final configuredName = prefs.getString("downloadDirectoryName")?.trim() ?? "";
  final safeName = configuredName
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), "_")
      .trim();
  final directory = safeName.isEmpty
      ? baseDirectory
      : Directory("${baseDirectory.path}/$safeName");
  await directory.create(recursive: true);
  return directory;
}

Future<bool> hasStoragePermission() async {
  try {
    return await installerChannel.invokeMethod<bool>("hasStoragePermission") ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> openStoragePermissionSettings() async {
  try {
    await installerChannel.invokeMethod<void>("openStoragePermissionSettings");
  } catch (_) {}
}

Future<bool> ensureStoragePermission(BuildContext context) async {
  if (await hasStoragePermission()) return true;
  if (!context.mounted) return false;
  final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("需要存储权限"),
          content: const Text("为了将下载文件保存到 /storage/emulated/0/Download，请允许 ZexNote 访问外部存储。"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("稍后"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("去开启"),
            ),
          ],
        ),
      ) ??
      false;
  if (!shouldOpenSettings) return false;
  await openStoragePermissionSettings();
  return false;
}

void showAppToast(BuildContext context, String message, {bool isError = false}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) {
      final colorScheme = Theme.of(overlayContext).colorScheme;
      final backgroundColor = isError
          ? colorScheme.errorContainer
          : colorScheme.inverseSurface;
      final foregroundColor = isError
          ? colorScheme.onErrorContainer
          : colorScheme.onInverseSurface;
      final bottomOffset = MediaQuery.of(overlayContext).viewPadding.bottom + 104;
      return Positioned(
        left: 24,
        right: 24,
        bottom: bottomOffset,
        child: IgnorePointer(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: backgroundColor.withAlpha(242),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: foregroundColor.withAlpha(35)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isError ? Icons.error_outline : Icons.check_circle_outline,
                        color: foregroundColor,
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: foregroundColor, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  Timer(const Duration(seconds: 2), () {
    if (entry.mounted) entry.remove();
  });
}
