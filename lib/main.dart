import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dynamic_color/flutter_dynamic_color.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZexNoteApp());
}

class ZexNoteApp extends StatelessWidget {
  const ZexNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
      return MaterialApp(
        title: "ZexNote",
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: lightDynamic,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: darkDynamic,
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const MainPage(),
        debugShowCheckedModeBanner: false,
      );
    });
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int currentIndex = 0;
  final PageController pageCtrl = PageController();

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = [
      const NoteHomePage(),
      const ArchivePage(),
      SettingPage(onCheckUpdate: checkVersion),
    ];
    autoCheckUpdate();
  }

  // 启动自动检查更新
  Future<void> autoCheckUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    bool autoCheck = prefs.getBool("autoCheckUpdate") ?? true;
    if (autoCheck) {
      await checkVersion(showDialogIfNoUpdate: false);
    }
  }

  Future<void> checkVersion({bool showDialogIfNoUpdate = true}) async {
    const repo = "BaiXiaoTao520/New-ZexNote";
    String latestVer = "";
    String downloadUrl = "";

    // 双通道：优先GitHub API，失败切换Atom订阅源
    try {
      final apiRes = await http.get(Uri.parse("https://api.github.com/repos/$repo/releases/latest"));
      if (apiRes.statusCode == 200) {
        final json = jsonDecode(apiRes.body);
        latestVer = json["tag_name"];
        final assetsList = json["assets"] as List;
        if (assetsList.isNotEmpty) {
          downloadUrl = assetsList[0]["browser_download_url"];
        }
      }
    } catch (_) {
      // API被限流，切换Atom订阅源
      try {
        final atomRes = await http.get(Uri.parse("https://github.com/$repo/releases.atom"));
        if (atomRes.statusCode == 200) {
          final atomBody = atomRes.body;
          final tagReg = RegExp(r'<title>(v[\d\.]+)</title>');
          final match = tagReg.firstMatch(atomBody);
          if (match != null) latestVer = match.group(1)!;
        }
      } catch (_) {}
    }

    if (latestVer.isEmpty) {
      if (showDialogIfNoUpdate && mounted) {
        showDialog(
          context: context,
          builder: (c) => const AlertDialog(
            title: Text("提示"),
            content: Text("无法获取版本信息"),
          ),
        );
      }
      return;
    }

    // 每次发新版必须同步修改这里
    const currentVer = "v1.0.0";
    if (latestVer == currentVer) {
      if (showDialogIfNoUpdate && mounted) {
        showDialog(
          context: context,
          builder: (c) => const AlertDialog(
            title: Text("已是最新版"),
            content: Text("当前没有新版本"),
          ),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => UpdateDialog(downloadUrl: downloadUrl, newVer: latestVer),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: pageCtrl,
        onPageChanged: (idx) => setState(() => currentIndex = idx),
        children: pages,
      ),
      // 小型悬浮胶囊底部导航
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (idx) {
              pageCtrl.animateToPage(idx,
                  duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.note), label: "便签"),
              BottomNavigationBarItem(icon: Icon(Icons.archive), label: "归档"),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: "设置"),
            ],
          ),
        ),
      ),
    );
  }
}

// 缩小版更新弹窗：带可滚动日志窗口 + 升级图标
class UpdateDialog extends StatefulWidget {
  final String downloadUrl;
  final String newVer;
  const UpdateDialog({super.key, required this.downloadUrl, required this.newVer});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double progress = 0;
  bool downloading = false;
  int total = 0;
  int received = 0;
  final List<String> logLines = [];
  final ScrollController logScrollCtrl = ScrollController();

  void addLog(String msg) {
    setState(() {
      logLines.add(msg);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (logScrollCtrl.hasClients) {
        logScrollCtrl.animateTo(logScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100), curve: Curves.linear);
      }
    });
  }

  Future<void> startDownload() async {
    setState(() {
      downloading = true;
      progress = 0;
      received = 0;
      logLines.clear();
    });
    addLog("开始下载：${widget.newVer}");

    final dir = await getApplicationDocumentsDirectory();
    final savePath = "${dir.path}/zexnote_update.apk";
    final saveFile = File(savePath);
    addLog("保存路径：$savePath");

    try {
      final req = http.Request("GET", Uri.parse(widget.downloadUrl));
      final streamedResponse = await req.send();
      total = streamedResponse.contentLength ?? 0;
      addLog("文件总大小：$total bytes");

      final sink = saveFile.openWrite();
      await streamedResponse.stream.listen((List<int> chunk) {
        sink.add(chunk);
        received += chunk.length;
        setState(() {
          progress = total > 0 ? received / total : 0;
        });
      }).asFuture();
      await sink.close();
      addLog("✅ 下载完成，准备唤起安装器");

      final uri = Uri.parse("file://$savePath");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        addLog("❌ 无法启动安装器，请手动打开文件");
      }
    } catch (e) {
      addLog("❌ 下载异常：$e");
    } finally {
      setState(() => downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      title: Row(
        children: [
          const Icon(Icons.system_update, size: 22),
          const SizedBox(width: 8),
          Text("新版本 ${widget.newVer}", style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
      content: SizedBox(
        width: double.minPositive,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (downloading)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 6),
                  Text("$received / $total bytes", style: const TextStyle(fontSize: 12)),
                ],
              ),
            const SizedBox(height: 8),
            // 可滑动日志小窗口
            SizedBox(
              height: 100,
              width: double.infinity,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  controller: logScrollCtrl,
                  child: Text(
                    logLines.join("\n"),
                    style: const TextStyle(fontSize: 11, height: 1.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => launchUrl(Uri.parse(widget.downloadUrl)),
          child: const Text("浏览器下载"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("稍后"),
        ),
        if (!downloading)
          TextButton(onPressed: startDownload, child: const Text("重试")),
      ],
    );
  }

  @override
  void dispose() {
    logScrollCtrl.dispose();
    super.dispose();
  }
}

// 占位页面，后续填充便签功能
class NoteHomePage extends StatelessWidget {
  const NoteHomePage({super.key});
  @override
  Widget build(BuildContext c) => const Center(child: Text("便签主页"));
}

class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key});
  @override
  Widget build(BuildContext c) => const Center(child: Text("归档页面"));
}

class SettingPage extends StatefulWidget {
  final VoidCallback onCheckUpdate;
  const SettingPage({super.key, required this.onCheckUpdate});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool autoCheck = true;
  final String currentVersion = "v1.0.0";

  @override
  void initState() {
    super.initState();
    loadSwitch();
  }

  Future<void> loadSwitch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      autoCheck = prefs.getBool("autoCheckUpdate") ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("设置")),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("关于 ZexNote"),
            subtitle: Text("简洁本地便签"),
          ),
          ListTile(
            leading: const Icon(Icons.numbers),
            title: const Text("当前版本"),
            subtitle: Text(currentVersion),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.autorenew),
            title: const Text("启动时自动检查更新"),
            value: autoCheck,
            onChanged: (val) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool("autoCheckUpdate", val);
              setState(() {
                autoCheck = val;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text("手动检查新版本"),
            onTap: widget.onCheckUpdate,
          ),
        ],
      ),
    );
  }
}
