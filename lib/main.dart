import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

// 全局通知器，用于动态颜色开关的实时热重绘
final ValueNotifier<bool> globalDynamicColorNotifier = ValueNotifier(true);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  globalDynamicColorNotifier.value = prefs.getBool("dynamicColor") ?? true;
  runApp(const ZexNoteApp());
}

class ZexNoteApp extends StatelessWidget {
  const ZexNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: globalDynamicColorNotifier,
      builder: (context, useDynamic, _) {
        return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
          final ColorScheme lightScheme = (useDynamic && lightDynamic != null)
              ? lightDynamic
              : ColorScheme.fromSeed(seedColor: Colors.lightGreen);
          final ColorScheme darkScheme = (useDynamic && darkDynamic != null)
              ? darkDynamic
              : ColorScheme.fromSeed(seedColor: Colors.lightGreen, brightness: Brightness.dark);

          return MaterialApp(
            title: "ZexNote",
            theme: ThemeData(
              brightness: Brightness.light,
              colorScheme: lightScheme,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: darkScheme,
              useMaterial3: true,
            ),
            themeMode: ThemeMode.system,
            home: const MainPage(),
            debugShowCheckedModeBanner: false,
          );
        });
      },
    );
  }
}

// 便签数据模型
class Note {
  final String id;
  final String title;
  final String content;
  final Color color;
  final DateTime createTime;
  final bool isArchived;

  Note({
    String? id,
    required this.title,
    required this.content,
    required this.color,
    required this.createTime,
    this.isArchived = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'color': color.value,
        'createTime': createTime.toIso8601String(),
        'isArchived': isArchived,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        color: Color(json['color']),
        createTime: DateTime.parse(json['createTime']),
        isArchived: json['isArchived'] ?? false,
      );
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  int currentIndex = 0;
  final PageController pageCtrl = PageController();
  late AnimationController _navAnimController;
  List<Note> notes = [];

  @override
  void initState() {
    super.initState();
    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    loadNotesFromStorage();
    autoCheckUpdate();
  }

  Future<void> loadNotesFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString('saved_notes');
    if (notesJson != null) {
      final List decoded = jsonDecode(notesJson);
      setState(() {
        notes = decoded.map((e) => Note.fromJson(e)).toList();
      });
    }
  }

  Future<void> saveNotesToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(notes.map((e) => e.toJson()).toList());
    await prefs.setString('saved_notes', encoded);
  }

  Future<void> autoCheckUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    bool autoCheck = prefs.getBool("autoCheckUpdate") ?? true;
    if (autoCheck) {
      await checkVersion(showNoUpdateToast: false);
    }
  }

  Future<void> checkVersion({bool showNoUpdateToast = true}) async {
    const repo = "BaiXiaoTao520/New-ZexNote";
    String latestVer = "";
    String downloadUrl = "";
    String updateLog = "";

    try {
      final apiRes = await http.get(Uri.parse("https://api.github.com/repos/$repo/releases/latest"));
      if (apiRes.statusCode == 200) {
        final json = jsonDecode(apiRes.body);
        latestVer = json["tag_name"];
        updateLog = json["body"] ?? "";
        final assetsList = json["assets"] as List;
        if (assetsList.isNotEmpty) {
          downloadUrl = assetsList[0]["browser_download_url"];
        }
      }
    } catch (_) {}

    if (latestVer.isEmpty) {
      if (showNoUpdateToast && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("无法获取版本信息")));
      }
      return;
    }

    const currentVer = "v1.0.0";
    if (latestVer == currentVer) {
      if (showNoUpdateToast && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("当前已是最新版本")));
      }
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => UpdateDialog(
          downloadUrl: downloadUrl,
          newVer: latestVer,
          updateLog: updateLog,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: pageCtrl,
        onPageChanged: (idx) => setState(() => currentIndex = idx),
        children: [
          NoteHomePage(
            notes: notes,
            onAddNote: () => _openEditPage(),
          ),
          ArchivePage(notes: notes),
          SettingPage(onCheckUpdate: () => checkVersion(showNoUpdateToast: true)),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000), 
                blurRadius: 10,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: List.generate(3, (idx) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    pageCtrl.animateToPage(
                      idx,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: currentIndex == idx
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      Icon(
                        idx == 0 ? Icons.note : idx == 1 ? Icons.archive : Icons.settings,
                        color: currentIndex == idx
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      floatingActionButton: currentIndex == 0
          ? FloatingActionButton(
              onPressed: _openEditPage,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _openEditPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => NoteEditPage(
          onSave: (note) {
            setState(() => notes.add(note));
            saveNotesToStorage();
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    pageCtrl.dispose();
    super.dispose();
  }
}

class UpdateDialog extends StatelessWidget {
  final String downloadUrl;
  final String newVer;
  final String updateLog;
  const UpdateDialog({
    super.key,
    required this.downloadUrl,
    required this.newVer,
    required this.updateLog,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      title: Row(
        children: [
          const Icon(Icons.system_update, size: 22),
          const SizedBox(width: 8),
          Text("新版本 $newVer"),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    updateLog.isEmpty ? "暂无更新日志" : updateLog,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("稍后"),
        ),
        TextButton(
          onPressed: () {
            launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
            Navigator.pop(context);
          },
          child: const Text("浏览器下载"),
        ),
      ],
    );
  }
}

class NoteHomePage extends StatelessWidget {
  final List<Note> notes;
  final VoidCallback onAddNote;
  const NoteHomePage({super.key, required this.notes, required this.onAddNote});

  @override
  Widget build(BuildContext context) {
    final activeNotes = notes.where((n) => !n.isArchived).toList();
    return Scaffold(
      appBar: AppBar(title: const Text("ZexNote")),
      body: activeNotes.isEmpty
          ? const Center(child: Text("暂无便签，点击右下角加号新建"))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: activeNotes.length,
              itemBuilder: (context, idx) {
                final note = activeNotes[idx];
                return Card(
                  color: note.color,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                );
              },
            ),
    );
  }
}

class ArchivePage extends StatelessWidget {
  final List<Note> notes;
  const ArchivePage({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    final archivedNotes = notes.where((n) => n.isArchived).toList();
    return Scaffold(
      appBar: AppBar(title: const Text("归档")),
      body: archivedNotes.isEmpty
          ? const Center(child: Text("暂无归档便签"))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: archivedNotes.length,
              itemBuilder: (context, idx) {
                final note = archivedNotes[idx];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(note.title),
                    subtitle: Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                );
              },
            ),
    );
  }
}

class NoteEditPage extends StatefulWidget {
  final Function(Note) onSave;
  const NoteEditPage({super.key, required this.onSave});

  @override
  State<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<NoteEditPage> {
  final titleCtrl = TextEditingController();
  final contentCtrl = TextEditingController();
  Color selectedColor = Colors.lightGreen.shade100;
  bool hasUnsavedChanges = false;

  final List<Color> colorOptions = [
    Colors.lightGreen.shade100,
    Colors.yellow.shade100,
    Colors.pink.shade100,
    Colors.blue.shade100,
    Colors.purple.shade100,
  ];

  @override
  void initState() {
    super.initState();
    titleCtrl.addListener(() => hasUnsavedChanges = true);
    contentCtrl.addListener(() => hasUnsavedChanges = true);
  }

  Future<bool> _onWillPop() async {
    if (!hasUnsavedChanges) return true;
    final result = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("未保存的更改"),
        content: const Text("你有未保存的内容，确定要离开吗？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("取消")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("离开")),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSaveOptions() {
    final note = Note(
      title: titleCtrl.text.isEmpty ? "无标题" : titleCtrl.text,
      content: contentCtrl.text,
      color: selectedColor,
      createTime: DateTime.now(),
    );
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("保存方式"),
        content: const Text("选择保存这篇便签的方式"),
        actions: [
          TextButton(
            onPressed: () {
              widget.onSave(note);
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("已保存")),
              );
              Navigator.pop(context);
            },
            child: const Text("保存并退出"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(c);
              final shareText = "${note.title}\n\n${note.content}";
              await Share.share(shareText, subject: note.title);
            },
            child: const Text("分享便签"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("编辑便签"),
          actions: [
            IconButton(onPressed: _showSaveOptions, icon: const Icon(Icons.save)),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  hintText: "标题",
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: contentCtrl,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    hintText: "写点什么...",
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: colorOptions.length,
                  itemBuilder: (context, idx) {
                    final color = colorOptions[idx];
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = color),
                      child: Container(
                        width: 50,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selectedColor == color
                              ? Border.all(color: Colors.black, width: 2)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    contentCtrl.dispose();
    super.dispose();
  }
}

class SettingPage extends StatelessWidget {
  final VoidCallback onCheckUpdate;
  const SettingPage({super.key, required this.onCheckUpdate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("设置")),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: globalDynamicColorNotifier,
            builder: (context, isDynamic, _) {
              return SwitchListTile(
                secondary: const Icon(Icons.palette),
                title: const Text("动态颜色（Material You）"),
                subtitle: const Text("跟随系统壁纸配色"),
                value: isDynamic,
                onChanged: (val) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool("dynamicColor", val);
                  globalDynamicColorNotifier.value = val;
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("关于 ZexNote"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const AboutPage(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text("手动检查新版本"),
            onTap: onCheckUpdate,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("关于 ZexNote")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    )
                  ],
                ),
                child: const Icon(Icons.note, size: 64),
              ),
              const SizedBox(height: 24),
              Text(
                "ZexNote",
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                "版本 v1.0.0",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
