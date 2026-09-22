import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String repository = "BaiXiaoTao520/New-ZexNote";
const String repositoryUrl = "https://github.com/$repository";
const String currentVersion = "1.0.2";
const MethodChannel installerChannel = MethodChannel("com.zex.note/installer");

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
          final lightScheme = useDynamic && lightDynamic != null
              ? lightDynamic
              : ColorScheme.fromSeed(seedColor: Colors.lightGreen);
          final darkScheme = useDynamic && darkDynamic != null
              ? darkDynamic
              : ColorScheme.fromSeed(
                  seedColor: Colors.lightGreen,
                  brightness: Brightness.dark,
                );

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
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "content": content,
        "color": color.value,
        "createTime": createTime.toIso8601String(),
        "isArchived": isArchived,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json["id"],
        title: json["title"],
        content: json["content"],
        color: Color(json["color"]),
        createTime: DateTime.parse(json["createTime"]),
        isArchived: json["isArchived"] ?? false,
      );
}

class UpdateInfo {
  final String tagName;
  final String releaseUrl;
  final String downloadUrl;
  final String updateLog;
  final String source;

  const UpdateInfo({
    required this.tagName,
    required this.releaseUrl,
    required this.downloadUrl,
    required this.updateLog,
    required this.source,
  });

  String get displayVersion => normalizeVersion(tagName);
}

String normalizeVersion(String value) {
  final version = value.trim().replaceFirst(RegExp(r"^[vV]"), "");
  return version.split("+").first;
}

int compareVersions(String left, String right) {
  final leftParts = normalizeVersion(left).split(".").map(int.parse).toList();
  final rightParts = normalizeVersion(right).split(".").map(int.parse).toList();
  for (var index = 0; index < 3; index++) {
    final leftPart = index < leftParts.length ? leftParts[index] : 0;
    final rightPart = index < rightParts.length ? rightParts[index] : 0;
    if (leftPart != rightPart) return leftPart.compareTo(rightPart);
  }
  return 0;
}

String _xmlValue(String source, String tag) {
  final match = RegExp("<$tag[^>]*>([\\s\\S]*?)</$tag>").firstMatch(source);
  return match?.group(1)?.trim() ?? "";
}

String _atomTag(String entry) {
  final id = _xmlValue(entry, "id");
  final idMatch = RegExp(r"/releases/tag/([^<]+)$").firstMatch(id);
  if (idMatch != null) return Uri.decodeComponent(idMatch.group(1)!);

  final title = _xmlValue(entry, "title");
  final versionMatch = RegExp(r"[vV]?\d+(?:\.\d+){1,3}(?:\+\d+)?").firstMatch(title);
  return versionMatch?.group(0) ?? title;
}

Future<UpdateInfo?> _getUpdateFromApi() async {
  final response = await http.get(
    Uri.parse("https://api.github.com/repos/$repository/releases/latest"),
    headers: const {"Accept": "application/vnd.github+json"},
  );
  if (response.statusCode != 200) return null;

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final tagName = data["tag_name"] as String? ?? "";
  final htmlUrl = data["html_url"] as String? ?? "$repositoryUrl/releases";
  final assets = (data["assets"] as List<dynamic>? ?? const []);
  Map<String, dynamic>? apk;
  for (final item in assets) {
    final asset = item as Map<String, dynamic>;
    if ((asset["name"] as String? ?? "").toLowerCase().endsWith(".apk")) {
      apk = asset;
      break;
    }
  }

  return UpdateInfo(
    tagName: tagName,
    releaseUrl: htmlUrl,
    downloadUrl: apk?["browser_download_url"] as String? ?? "",
    updateLog: data["body"] as String? ?? "",
    source: "GitHub Releases API",
  );
}

Future<UpdateInfo?> _getUpdateFromAtom() async {
  final response = await http.get(
    Uri.parse("$repositoryUrl/releases.atom"),
    headers: const {"Accept": "application/atom+xml"},
  );
  if (response.statusCode != 200) return null;

  final entryMatch = RegExp(r"<entry\b[\s\S]*?</entry>").firstMatch(response.body);
  if (entryMatch == null) return null;
  final entry = entryMatch.group(0)!;
  final tagName = _atomTag(entry);
  if (tagName.isEmpty) return null;

  final linkMatch = RegExp(r'<link[^>]+href="([^"]+)"').firstMatch(entry);
  final releaseUrl = linkMatch?.group(1) ?? "$repositoryUrl/releases/tag/$tagName";
  return UpdateInfo(
    tagName: tagName,
    releaseUrl: releaseUrl,
    downloadUrl: "",
    updateLog: _xmlValue(entry, "summary"),
    source: "Releases Atom",
  );
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int currentIndex = 0;
  final PageController pageCtrl = PageController();
  List<Note> notes = [];
  final Set<String> selectedNoteIds = <String>{};

  @override
  void initState() {
    super.initState();
    loadNotesFromStorage();
    autoCheckUpdate();
  }

  Future<void> loadNotesFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString("saved_notes");
    if (notesJson != null && mounted) {
      final decoded = jsonDecode(notesJson) as List<dynamic>;
      setState(() => notes = decoded.map((item) => Note.fromJson(item)).toList());
    }
  }

  Future<void> saveNotesToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      "saved_notes",
      jsonEncode(notes.map((note) => note.toJson()).toList()),
    );
  }

  Future<void> autoCheckUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool("autoCheckUpdate") ?? true) {
      await checkVersion(showNoUpdateToast: false);
    }
  }

  Future<UpdateInfo?> _fetchLatestUpdate() async {
    try {
      final apiInfo = await _getUpdateFromApi();
      if (apiInfo != null) return apiInfo;
    } catch (_) {}

    try {
      return await _getUpdateFromAtom();
    } catch (_) {
      return null;
    }
  }

  Future<void> checkVersion({bool showNoUpdateToast = true}) async {
    final update = await _fetchLatestUpdate();
    if (!mounted) return;

    if (update == null || update.tagName.isEmpty) {
      if (showNoUpdateToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("无法获取版本信息，请检查网络后重试")),
        );
      }
      return;
    }

    if (compareVersions(update.displayVersion, currentVersion) <= 0) {
      if (showNoUpdateToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("当前已是最新版本")),
        );
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => UpdateDialog(update: update),
    );
  }

  bool get selectionMode => selectedNoteIds.isNotEmpty;

  void toggleNoteSelection(Note note) {
    setState(() {
      if (selectedNoteIds.contains(note.id)) {
        selectedNoteIds.remove(note.id);
      } else {
        selectedNoteIds.add(note.id);
      }
    });
  }

  void toggleSelectAll() {
    final activeIds = notes.where((note) => !note.isArchived).map((note) => note.id).toSet();
    setState(() {
      if (activeIds.isNotEmpty && selectedNoteIds.length == activeIds.length) {
        selectedNoteIds.clear();
      } else {
        selectedNoteIds
          ..clear()
          ..addAll(activeIds);
      }
    });
  }

  Future<bool> _confirmDelete(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("取消"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text("删除"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> deleteNotes(Iterable<Note> notesToDelete) async {
    final ids = notesToDelete.map((note) => note.id).toSet();
    if (ids.isEmpty) return;
    final confirmed = await _confirmDelete(
      ids.length == 1 ? "删除便签" : "删除已选便签",
      "删除后将无法恢复，确定要删除吗？",
    );
    if (!confirmed || !mounted) return;

    setState(() {
      notes.removeWhere((note) => ids.contains(note.id));
      selectedNoteIds.removeAll(ids);
    });
    await saveNotesToStorage();
  }

  void openEditPage([Note? existing]) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => NoteEditPage(
          existingNote: existing,
          onSave: (savedNote) {
            setState(() {
              final index = notes.indexWhere((note) => note.id == savedNote.id);
              if (index == -1) {
                notes.add(savedNote);
              } else {
                notes[index] = savedNote;
              }
            });
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: pageCtrl,
        onPageChanged: (index) => setState(() => currentIndex = index),
        children: [
          NoteHomePage(
            notes: notes,
            selectionMode: selectionMode,
            selectedNoteIds: selectedNoteIds,
            onOpenNote: openEditPage,
            onToggleSelection: toggleNoteSelection,
            onToggleSelectAll: toggleSelectAll,
            onDeleteNote: (note) => deleteNotes([note]),
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
              BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    pageCtrl.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          color: currentIndex == index
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      Icon(
                        index == 0 ? Icons.note : index == 1 ? Icons.archive : Icons.settings,
                        color: currentIndex == index
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
              onPressed: selectionMode
                  ? () => deleteNotes(notes.where((note) => selectedNoteIds.contains(note.id)))
                  : () => openEditPage(),
              child: Icon(selectionMode ? Icons.delete : Icons.add),
            )
          : null,
    );
  }

  @override
  void dispose() {
    pageCtrl.dispose();
    super.dispose();
  }
}

class UpdateDialog extends StatefulWidget {
  final UpdateInfo update;
  const UpdateDialog({super.key, required this.update});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> with WidgetsBindingObserver {
  bool downloading = false;
  double progress = 0;
  int downloadedBytes = 0;
  int totalBytes = 0;
  bool waitingForPermissionReturn = false;
  String status = "准备下载";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && waitingForPermissionReturn) {
      waitingForPermissionReturn = false;
      Future<void>.delayed(const Duration(milliseconds: 300), _confirmInstallPermission);
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

  Future<void> _installApk(String path) async {
    try {
      await installerChannel.invokeMethod<void>("installApk", {"path": path});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("无法打开系统安装器")),
        );
      }
    }
  }

  Future<void> _confirmInstallPermission() async {
    if (!mounted || downloading) return;
    final enabled = await _canInstallPackages();
    if (enabled) {
      final path = await SharedPreferences.getInstance().then((prefs) => prefs.getString("pending_apk_path"));
      if (path != null) await _installApk(path);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("安装权限确认"),
        content: const Text("尚未检测到安装未知来源应用权限。请确认你已在系统设置中开启该权限。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (await _canInstallPackages()) {
                final prefs = await SharedPreferences.getInstance();
                final path = prefs.getString("pending_apk_path");
                if (path != null) await _installApk(path);
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("仍未开启安装权限，请稍后重试")),
                );
              }
            },
            child: const Text("再次检查"),
          ),
        ],
      ),
    );
  }

  Future<void> _prepareInstall(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("pending_apk_path", path);
    if (await _canInstallPackages()) {
      await _installApk(path);
      return;
    }

    waitingForPermissionReturn = true;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("需要安装权限"),
        content: const Text("请在系统设置中允许 ZexNote 安装未知来源应用，返回本应用后会再次检查。"),
        actions: [
          TextButton(
            onPressed: () {
              waitingForPermissionReturn = false;
              Navigator.pop(dialogContext);
            },
            child: const Text("稍后"),
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

  Future<void> _downloadAndInstall() async {
    if (downloading || widget.update.downloadUrl.isEmpty) return;
    setState(() {
      downloading = true;
      status = "正在下载";
    });

    final client = http.Client();
    IOSink? sink;
    try {
      final response = await client.send(http.Request("GET", Uri.parse(widget.update.downloadUrl)));
      if (response.statusCode != 200) {
        throw HttpException("download failed: ${response.statusCode}");
      }

      totalBytes = response.contentLength ?? 0;
      final directory = await getApplicationSupportDirectory();
      final file = File("${directory.path}/zexnote-${widget.update.displayVersion}.apk");
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
        status = "下载完成，准备安装";
      });
      await _prepareInstall(file.path);
    } catch (_) {
      await sink?.close();
      if (mounted) {
        setState(() {
          downloading = false;
          status = "下载失败";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("下载失败，请检查网络后重试")),
        );
      }
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDownload = widget.update.downloadUrl.isNotEmpty;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      title: Row(
        children: [
          const Icon(Icons.system_update),
          const SizedBox(width: 8),
          Expanded(child: Text("新版本 v${widget.update.displayVersion}")),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("检测来源：${widget.update.source}"),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: SingleChildScrollView(
                child: Text(
                  widget.update.updateLog.isEmpty ? "暂无更新日志" : widget.update.updateLog,
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ),
            if (downloading || status == "下载完成，准备安装") ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: totalBytes > 0 ? progress : null),
              const SizedBox(height: 8),
              Text(
                totalBytes > 0
                    ? "$status：${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}"
                    : status,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: downloading ? null : () => Navigator.pop(context),
          child: const Text("稍后"),
        ),
        if (hasDownload)
          FilledButton.icon(
            onPressed: downloading ? null : _downloadAndInstall,
            icon: const Icon(Icons.download),
            label: const Text("应用内下载"),
          ),
        TextButton.icon(
          onPressed: downloading
              ? null
              : () async {
                  await launchUrl(
                    Uri.parse(widget.update.releaseUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
          icon: const Icon(Icons.open_in_new),
          label: const Text("浏览器下载"),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class NoteHomePage extends StatelessWidget {
  final List<Note> notes;
  final bool selectionMode;
  final Set<String> selectedNoteIds;
  final ValueChanged<Note> onOpenNote;
  final ValueChanged<Note> onToggleSelection;
  final VoidCallback onToggleSelectAll;
  final ValueChanged<Note> onDeleteNote;

  const NoteHomePage({
    super.key,
    required this.notes,
    required this.selectionMode,
    required this.selectedNoteIds,
    required this.onOpenNote,
    required this.onToggleSelection,
    required this.onToggleSelectAll,
    required this.onDeleteNote,
  });

  @override
  Widget build(BuildContext context) {
    final activeNotes = notes.where((note) => !note.isArchived).toList();
    final allSelected = activeNotes.isNotEmpty && selectedNoteIds.length == activeNotes.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(selectionMode ? "已选择 ${selectedNoteIds.length} 项" : "ZexNote"),
        actions: selectionMode
            ? [
                IconButton(
                  tooltip: allSelected ? "取消全选" : "全选",
                  onPressed: onToggleSelectAll,
                  icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                ),
              ]
            : null,
      ),
      body: activeNotes.isEmpty
          ? const Center(child: Text("暂无便签，点击右下角加号新建"))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: activeNotes.length,
              itemBuilder: (context, index) {
                final note = activeNotes[index];
                final selected = selectedNoteIds.contains(note.id);
                return Card(
                  color: note.color,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    onTap: () => selectionMode ? onToggleSelection(note) : onOpenNote(note),
                    onLongPress: () => onToggleSelection(note),
                    leading: selectionMode
                        ? Checkbox(
                            value: selected,
                            onChanged: (_) => onToggleSelection(note),
                          )
                        : null,
                    title: Text(
                      note.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: "删除便签",
                      onPressed: () => onDeleteNote(note),
                      icon: const Icon(Icons.delete_outline),
                    ),
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
    final archivedNotes = notes.where((note) => note.isArchived).toList();
    return Scaffold(
      appBar: AppBar(title: const Text("归档")),
      body: archivedNotes.isEmpty
          ? const Center(child: Text("暂无归档便签"))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: archivedNotes.length,
              itemBuilder: (context, index) {
                final note = archivedNotes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(note.title),
                    subtitle: Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class NoteEditPage extends StatefulWidget {
  final Note? existingNote;
  final ValueChanged<Note> onSave;

  const NoteEditPage({
    super.key,
    required this.existingNote,
    required this.onSave,
  });

  @override
  State<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<NoteEditPage> {
  late final TextEditingController titleCtrl;
  late final TextEditingController contentCtrl;
  late Color selectedColor;
  bool hasUnsavedChanges = false;

  final colorOptions = [
    Colors.lightGreen.shade100,
    Colors.yellow.shade100,
    Colors.pink.shade100,
    Colors.blue.shade100,
    Colors.purple.shade100,
  ];

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.existingNote?.title ?? "");
    contentCtrl = TextEditingController(text: widget.existingNote?.content ?? "");
    selectedColor = widget.existingNote?.color ?? Colors.lightGreen.shade100;
    titleCtrl.addListener(_markChanged);
    contentCtrl.addListener(_markChanged);
  }

  void _markChanged() => hasUnsavedChanges = true;

  Future<bool> _onWillPop() async {
    if (!hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("未保存的更改"),
        content: const Text("你有未保存的内容，确定要离开吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("离开"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSaveOptions() {
    final note = Note(
      id: widget.existingNote?.id,
      title: titleCtrl.text.isEmpty ? "无标题" : titleCtrl.text,
      content: contentCtrl.text,
      color: selectedColor,
      createTime: widget.existingNote?.createTime ?? DateTime.now(),
      isArchived: widget.existingNote?.isArchived ?? false,
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("保存方式"),
        content: const Text("选择保存这篇便签的方式"),
        actions: [
          TextButton(
            onPressed: () {
              widget.onSave(note);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已保存")));
              Navigator.pop(context);
            },
            child: const Text("保存并退出"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await Share.share(
                "${note.title}\n\n${note.content}",
                subject: note.title,
              );
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
        if (await _onWillPop() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("编辑便签"),
          actions: [
            IconButton(
              tooltip: "保存",
              onPressed: _showSaveOptions,
              icon: const Icon(Icons.save),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(hintText: "标题", border: InputBorder.none),
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
                  itemBuilder: (context, index) {
                    final color = colorOptions[index];
                    return GestureDetector(
                      onTap: () => setState(() {
                        selectedColor = color;
                        hasUnsavedChanges = true;
                      }),
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
            builder: (context, isDynamic, _) => SwitchListTile(
              secondary: const Icon(Icons.palette),
              title: const Text("动态颜色（Material You）"),
              subtitle: const Text("跟随系统壁纸配色"),
              value: isDynamic,
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool("dynamicColor", value);
                globalDynamicColorNotifier.value = value;
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("关于 ZexNote"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text("更新设置"),
            subtitle: const Text("自动检查与手动检查新版本"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UpdateSettingsPage(onCheckUpdate: onCheckUpdate),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UpdateSettingsPage extends StatefulWidget {
  final VoidCallback onCheckUpdate;
  const UpdateSettingsPage({super.key, required this.onCheckUpdate});

  @override
  State<UpdateSettingsPage> createState() => _UpdateSettingsPageState();
}

class _UpdateSettingsPageState extends State<UpdateSettingsPage> {
  bool autoCheck = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => autoCheck = prefs.getBool("autoCheckUpdate") ?? true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("更新设置")),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.update),
            title: const Text("启动时自动检查更新"),
            subtitle: const Text("打开应用时检查 GitHub 最新版本"),
            value: autoCheck,
            onChanged: (value) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool("autoCheckUpdate", value);
              if (mounted) setState(() => autoCheck = value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text("手动检查新版本"),
            onTap: widget.onCheckUpdate,
          ),
        ],
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _openRepository(BuildContext context) async {
    final launched = await launchUrl(
      Uri.parse(repositoryUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("无法打开浏览器")),
      );
    }
  }

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
                    BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 8)),
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
                "版本 v$currentVersion",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 40),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text("访问仓库"),
                subtitle: const Text("点击访问主页"),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => _openRepository(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
