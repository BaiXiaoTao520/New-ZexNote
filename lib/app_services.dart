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

Future<bool> hasRootAccess() async {
  try {
    return await installerChannel.invokeMethod<bool>("hasRootAccess") ?? false;
  } catch (_) {
    return false;
  }
}

Future<String?> detectUnsupportedSystem() async {
  Map<String, String>? properties;
  try {
    final raw = await installerChannel.invokeMapMethod<String, dynamic>("systemProperties");
    if (raw != null) {
      properties = raw.map((key, value) => MapEntry(key, value?.toString() ?? ""));
    }
  } catch (_) {
    properties = null;
  }
  if (properties == null) return null;

  String value(String key) => properties![key]?.trim().toLowerCase() ?? "";

  final flymeSignal = [
    value("ro.flyme.version"),
    value("ro.flyme.os.version"),
    value("ro.build.flyme.version"),
    value("persist.sys.flyme.version"),
    value("ro.aios.version"),
  ].any((item) => item.isNotEmpty);
  final displayAndFingerprint =
      "${value("ro.build.display.id")} ${value("ro.build.fingerprint")}";
  if (flymeSignal ||
      displayAndFingerprint.contains("flyme") ||
      displayAndFingerprint.contains("aios")) {
    return "Flyme 系统";
  }

  final isFuntouch = value("ro.vivo.os.name").contains("funtouch") ||
      value("ro.vivo.os.version").contains("funtouch") ||
      value("ro.build.display.id").contains("funtouch");
  // 仅在国内版有明确标记时才拦截；海外版或标记缺失一律放行，避免误伤海外用户
  final overseasFlag = value("ro.vivo.product.overseas");
  final explicitlyDomestic = overseasFlag == "no" || overseasFlag == "false" || overseasFlag == "0";
  if (isFuntouch && explicitlyDomestic) {
    return "Funtouch OS（国内版）";
  }
  return null;
}

class UnsupportedSystemDialog extends StatelessWidget {
  final String systemName;

  const UnsupportedSystemDialog({super.key, required this.systemName});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.block),
        title: const Text("抱歉，你的系统不再支持"),
        content: Text(
          "检测到当前设备运行 $systemName。由于该系统对第三方应用的安装与后台限制过于严格，"
          "ZexNote 在上面无法稳定保存便签，继续使用可能导致数据丢失。\n\n"
          "为保护你的笔记安全，我们已停止对 $systemName 的支持。感谢理解。",
        ),
        actions: [
          FilledButton(
            onPressed: () => SystemNavigator.pop(animated: true),
            child: const Text("退出应用"),
          ),
        ],
      ),
    );
  }
}

class RootInstallResult {
  final bool success;
  final String message;

  const RootInstallResult({required this.success, required this.message});
}

Future<RootInstallResult> rootInstallApk(String path) async {
  try {
    final response = await installerChannel.invokeMapMethod<String, dynamic>(
      "rootInstallApk",
      {"path": path},
    );
    return RootInstallResult(
      success: response?["success"] == true,
      message: response?["message"]?.toString().trim() ?? "",
    );
  } catch (error) {
    return RootInstallResult(success: false, message: error.toString());
  }
}

Future<bool> rootSilentInstallEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool("rootSilentInstall") ?? false;
}

Future<void> setRootSilentInstallEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool("rootSilentInstall", enabled);
}

Future<bool> ensureStoragePermission(BuildContext context) async {
  if (await hasStoragePermission()) return true;
  if (!context.mounted) return false;

  await openStoragePermissionSettings();
  if (!context.mounted) return false;

  while (true) {
    final shouldRecheck = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text("需要存储权限"),
            content: const Text(
              "请先在系统设置中允许 ZexNote 访问外部存储，完成后点击“重新检测”继续下载。",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("取消"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text("重新检测"),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldRecheck) return false;
    if (await hasStoragePermission()) return true;
    if (!context.mounted) return false;
  }
}

Future<void> installApk(BuildContext context, String path) async {
  final useRoot = (await rootSilentInstallEnabled()) && await hasRootAccess();
  if (!context.mounted) return;
  unawaited(showInstallingDialog(context));
  await Future<void>.delayed(Duration.zero);

  if (useRoot) {
    final installResult = await rootInstallApk(path);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    final failureMessage = installResult.message.isEmpty
        ? "Root 静默安装失败"
        : "Root 静默安装失败：${installResult.message}";
    showAppToast(
      context,
      installResult.success ? "安装成功" : failureMessage,
      isError: !installResult.success,
    );
    return;
  }

  try {
    await installerChannel.invokeMethod<void>("installApk", {"path": path});
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    showAppToast(context, "无法打开系统安装器", isError: true);
  }
}

Future<void> showInstallingDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const InstallationProgressDialog(),
  );
}

class InstallationProgressDialog extends StatefulWidget {
  const InstallationProgressDialog({super.key});

  @override
  State<InstallationProgressDialog> createState() => _InstallationProgressDialogState();
}

class _InstallationProgressDialogState extends State<InstallationProgressDialog>
    with WidgetsBindingObserver {
  bool openedInstaller = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      openedInstaller = true;
      return;
    }
    if (state == AppLifecycleState.resumed && openedInstaller && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text("正在安装"),
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 16),
            Expanded(child: Text("正在交给系统安装程序处理…")),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
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
