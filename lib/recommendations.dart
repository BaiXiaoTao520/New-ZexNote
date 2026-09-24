import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'app_services.dart';

class RecommendedApp {
  final String name;
  final String version;
  final String summary;
  final String description;
  final String downloadUrl;
  final IconData icon;
  final bool browserOnly;

  const RecommendedApp({
    required this.name,
    required this.version,
    required this.summary,
    required this.description,
    required this.downloadUrl,
    required this.icon,
    this.browserOnly = false,
  });
}

const appShareRecommendation = RecommendedApp(
  name: "AppShare",
  version: "",
  summary: "App 多版本讨论、评分与资源分享平台",
  downloadUrl: "https://app.sharess.cn/download",
  icon: Icons.apps_rounded,
  browserOnly: true,
  description: r"""AppShare 平台介绍
一个提供 App 多版本讨论及评分的平台

排行系统
AppShare 提供了用户资产排行、应用下载排行、分类排行等一些榜单，榜单数据实时更新。

应用分类
AppShare 现存 31 个大分类和 104 个小分类，您可以快速又精准地检索需要的资源。

任务中心
AppShare 日渐完善的任务中心，可以使普通用户无限制地使用所有功能。

应用更新
AppShare 会在用户上传新版本后提醒您更新应用，没有先后顺序，每个人都可以在第一时间更新应用。
您也可以选择忽略不想更新的应用。

日渐完善的资产系统
您可以通过一些 App 任务获取积分或分享值，从而无限制下载 AppShare 内的资源；资源上传者也可以通过其他人的下载获得分享值，用于兑换高级功能或奖励。""",
);

const reveriePaintRecommendation = RecommendedApp(
  name: "ReveriePaint",
  version: "v1.3.0",
  summary: "基于 Krita 核心引擎打造的 Android 原生数字绘画应用",
  downloadUrl:
      "https://gh.xmly.dev/https://github.com/LanRhyme/ReveriePaint/releases/download/v1.3.0/ReveriePaint-v1.3.0.apk",
  icon: Icons.brush_rounded,
  description: r"""基于 Krita 核心引擎打造的 Android 原生现代数字绘画应用

融合 Jetpack Compose 现代化界面与 Krita C++ 原生图像处理内核，专为平板与触控设备优化的专业创作工作流。

绘画引擎与笔刷系统
• Krita 官方内核集成：复用 Krita 核心笔刷引擎，支持真实物理笔触与颜料混合模拟。
• 内置丰富笔刷库：内置 240+ 官方笔刷预设，涵盖铅笔、钢笔、墨水、水彩、油画、喷枪、纹理与马克笔。
• 笔刷工坊：支持实时调整尺寸、不透明度、流量、间距、软硬度、混色比与压感动态曲线。
• 硬件压感适配：适配 Android 压感手写笔，支持抖动修正、子帧平滑插值与悬浮光标预览。

专业图层与合成管理
• 无限图层与分组树：支持无限图层创建、图层组嵌套与层级折叠。
• 丰富混合模式：支持正常、正片叠底、滤色、叠加、柔光、强光、颜色减淡等 25 种混合模式。
• 图层操作全功能：支持剪贴蒙版、Alpha 锁定、图层锁定、隐藏/显示、快速合并与色彩标签。
• 直观交互：图层面板支持长按拖拽排序、左滑操作菜单与批量图层管理。

创作工具箱
• 包含画笔、橡皮擦、涂抹、模糊、液化变形、渐变填充与文字排版工具。
• 支持直线、矩形、椭圆与多边形工具，以及快速吸附与辅助对齐。
• 支持套索、矩形、椭圆、魔棒与颜色选区，并支持加选、减选、反选和羽化。
• 支持自由变换、等比缩放、旋转、透视扭曲与画布裁剪。

录制与延时回放
• 记录笔迹、笔刷参数、图层变动、滤镜与色彩变迁全过程。
• 录制数据随 .revp 工程文件自动存储压缩，方便跨设备共享。
• 支持播放、暂停、进度拖动与 0.5x - 4x 倍速调节。

自动保存与工程安全
• 支持 1/3/5/10/15/30 分钟多档静默自动保存。
• 应用切至后台或意外中断时自动保留最后创作状态，支持快速恢复未保存草稿。

现代触控与个性化主题
• 支持双指缩放、旋转、平移画布，提供 120 FPS 视口变换。
• 支持双指点击撤销、三指点击重做、长按快速吸色。
• 提供莫兰迪全局主题，支持 Material You 动态取色。
• 支持自适应、深灰、纯黑、纯白及自定义 Hex 工作区底色。""",
);

class AppRecommendationsPage extends StatelessWidget {
  const AppRecommendationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final recommendations = [appShareRecommendation, reveriePaintRecommendation];
    return Scaffold(
      appBar: AppBar(title: const Text("应用推荐")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 160),
        children: [
          Text(
            "Zex 开发者为您精选以下应用",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            "发现适合你的工具与创作体验",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          for (final app in recommendations) RecommendationCard(app: app),
        ],
      ),
    );
  }
}

class RecommendationCard extends StatelessWidget {
  final RecommendedApp app;
  const RecommendationCard({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: Icon(app.icon),
        ),
        title: Text(app.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          app.version.isEmpty ? app.summary : "${app.version} · ${app.summary}",
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => RecommendationInfoDialog(app: app),
        ),
      ),
    );
  }
}

class RecommendationInfoDialog extends StatelessWidget {
  final RecommendedApp app;
  const RecommendationInfoDialog({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      title: Row(
        children: [
          Icon(app.icon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(app.version.isEmpty ? app.name : "${app.name} ${app.version}"),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: SingleChildScrollView(
          child: Text(app.description, style: const TextStyle(height: 1.5)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("取消"),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            if (app.browserOnly) {
              showDialog<void>(
                context: context,
                builder: (dialogContext) => const BrowserDownloadInfoDialog(),
              );
            } else {
              showDialog<void>(
                context: context,
                builder: (dialogContext) => RecommendationDownloadDialog(app: app),
              );
            }
          },
          icon: Icon(app.browserOnly ? Icons.open_in_browser : Icons.download),
          label: Text(app.browserOnly ? "浏览器下载" : "下载"),
        ),
      ],
    );
  }
}

class BrowserDownloadInfoDialog extends StatelessWidget {
  const BrowserDownloadInfoDialog({super.key});

  static const downloadUrl = "https://app.sharess.cn/download";

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("AppShare 下载说明"),
      content: const SingleChildScrollView(
        child: Text(
          "具体下载步骤：\n\n"
          "1. 点击页面中的“正式版”。\n"
          "2. 页面会跳转到蓝奏云。\n"
          "3. 在蓝奏云页面点击下载即可。\n\n"
          "建议使用电脑 UA 访问。手机端网页可能会提示开通会员才能下载。",
          style: TextStyle(height: 1.5),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("取消"),
        ),
        FilledButton.icon(
          onPressed: () async {
            await launchUrl(
              Uri.parse(downloadUrl),
              mode: LaunchMode.externalApplication,
            );
          },
          icon: const Icon(Icons.open_in_browser),
          label: const Text("打开浏览器"),
        ),
      ],
    );
  }
}

class RecommendationDownloadDialog extends StatefulWidget {
  final RecommendedApp app;
  const RecommendationDownloadDialog({super.key, required this.app});

  @override
  State<RecommendationDownloadDialog> createState() => _RecommendationDownloadDialogState();
}

class _RecommendationDownloadDialogState extends State<RecommendationDownloadDialog>
    with WidgetsBindingObserver {
  http.Client? client;
  String? downloadedPath;
  bool downloadCancelled = false;
  bool downloading = false;
  bool waitingForPermissionReturn = false;
  double progress = 0;
  int downloadedBytes = 0;
  int totalBytes = 0;
  String status = "准备下载";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _download());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && waitingForPermissionReturn) {
      waitingForPermissionReturn = false;
      Future<void>.delayed(const Duration(milliseconds: 300), _checkPermissionAfterReturn);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  Future<bool> _canInstallPackages() async {
    try {
      return await installerChannel.invokeMethod<bool>("canInstallPackages") ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openInstallSettings() async {
    try {
      await installerChannel.invokeMethod<void>("openInstallSettings");
    } catch (_) {}
  }

  Future<void> _download() async {
    if (!mounted || downloading) return;
    if (!await ensureStoragePermission(context)) return;
    if (!mounted) return;
    downloadCancelled = false;
    setState(() {
      downloading = true;
      status = "正在下载";
    });

    final currentClient = http.Client();
    client = currentClient;
    IOSink? sink;
    try {
      final response = await currentClient.send(
        http.Request("GET", Uri.parse(widget.app.downloadUrl)),
      );
      if (response.statusCode != 200) {
        throw HttpException("download failed: ${response.statusCode}");
      }

      totalBytes = response.contentLength ?? 0;
      final directory = await getConfiguredDownloadDirectory();
      final file = File(
        "${directory.path}/${widget.app.name.toLowerCase()}-${widget.app.version.replaceAll('.', '_')}.apk",
      );
      sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (mounted) {
          setState(() {
            progress = totalBytes > 0 ? downloadedBytes / totalBytes : 0;
          });
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (!mounted) return;
      setState(() {
        downloading = false;
        downloadedPath = file.path;
        status = "下载完成";
      });
      showAppToast(context, "下载完成");
    } catch (_) {
      await sink?.close();
      if (downloadCancelled) return;
      if (mounted) {
        setState(() {
          downloading = false;
          status = "下载失败";
        });
        showAppToast(context, "下载失败，请检查网络后重试", isError: true);
      }
    } finally {
      currentClient.close();
      if (identical(client, currentClient)) client = null;
    }
  }

  void _cancel() {
    downloadCancelled = true;
    client?.close();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _install() async {
    final path = downloadedPath;
    if (path == null) return;
    if (await _canInstallPackages()) {
      await _launchInstaller(path);
      return;
    }

    waitingForPermissionReturn = true;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("需要安装权限"),
        content: const Text("请允许 ZexNote 安装未知来源应用，返回本应用后会再次检查。"),
        actions: [
          TextButton(
            onPressed: () {
              waitingForPermissionReturn = false;
              Navigator.pop(dialogContext);
            },
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_openInstallSettings());
            },
            child: const Text("去开启"),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPermissionAfterReturn() async {
    if (!mounted || downloadedPath == null) return;
    if (await _canInstallPackages()) {
      await _launchInstaller(downloadedPath!);
    } else if (mounted) {
      showAppToast(context, "仍未开启安装权限，请稍后重试", isError: true);
    }
  }

  Future<void> _launchInstaller(String path) async {
    try {
      await installerChannel.invokeMethod<void>("installApk", {"path": path});
    } catch (_) {
      if (mounted) showAppToast(context, "无法打开系统安装器", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = downloadedPath != null;
    final failed = !downloading && status == "下载失败";
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      title: Row(
        children: [
          Icon(widget.app.icon),
          const SizedBox(width: 10),
          Expanded(child: Text("下载 ${widget.app.name}")),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: totalBytes > 0 ? progress : null),
          const SizedBox(height: 10),
          Text(
            totalBytes > 0 && !completed
                ? "$status：${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}"
                : status,
          ),
        ],
      ),
      actions: [
        if (downloading)
          TextButton(onPressed: _cancel, child: const Text("取消")),
        if (!downloading && !completed && !failed)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
        if (failed) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: _download,
            child: const Text("重试"),
          ),
        ],
        if (completed) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          FilledButton.icon(
            onPressed: _install,
            icon: const Icon(Icons.install_mobile),
            label: const Text("立即安装"),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    client?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
