import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_services.dart';
import 'recommendations.dart';

const String repository = "BaiXiaoTao520/New-ZexNote";
const String repositoryUrl = "https://github.com/$repository";
const String githubLatestApkUrl = "$repositoryUrl/releases/latest/download/app-release.apk";
const String currentVersion = "2.1.5";
const String mirrorResId = String.fromEnvironment("MIRROR_RES_ID");
const String mirrorApiUrl = "https://mirrorchyan.com/api/resources/$mirrorResId/latest";
const String mirrorProjectUrl = "https://mirrorchyan.com/zh/projects?rid=$mirrorResId";
const String contributorsApiUrl = "https://api.github.com/repos/$repository/contributors";

typedef CheckUpdateCallback = Future<void> Function({VoidCallback? onUpdateFound});

final ValueNotifier<bool> globalDynamicColorNotifier = ValueNotifier(true);
final ValueNotifier<bool> globalNavigationBlurNotifier = ValueNotifier(true);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  globalDynamicColorNotifier.value = prefs.getBool("dynamicColor") ?? true;
  globalNavigationBlurNotifier.value = prefs.getBool("navigationBlur") ?? true;
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

Color noteTextColor(Color background) {
  return background.computeLuminance() > 0.55
      ? const Color(0xFF171717)
      : Colors.white;
}

class UpdateInfo {
  final String tagName;
  final String releaseUrl;
  final String downloadUrl;
  final String updateLog;
  final String source;
  final String? mirrorUrl;

  const UpdateInfo({
    required this.tagName,
    required this.releaseUrl,
    required this.downloadUrl,
    required this.updateLog,
    required this.source,
    this.mirrorUrl,
  });

  String get displayVersion => normalizeVersion(tagName);
}

class MirrorUpdateInfo {
  final String versionName;
  final String releaseNote;

  const MirrorUpdateInfo({
    required this.versionName,
    required this.releaseNote,
  });
}

class ContributorInfo {
  final String username;
  final String avatarUrl;
  final String profileUrl;

  const ContributorInfo({
    required this.username,
    required this.avatarUrl,
    required this.profileUrl,
  });
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

String? _mirrorString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

Future<MirrorUpdateInfo?> _getMirrorUpdate() async {
  if (mirrorResId.isEmpty) return null;
  try {
    final query = <String, String>{
      "current_version": "v$currentVersion",
      "os": "android",
      "arch": "arm64",
    };
    final response = await http.get(
      Uri.parse(mirrorApiUrl).replace(queryParameters: query),
      headers: const {"Accept": "application/json"},
    );
    if (response.statusCode != 200) return null;

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload["code"]?.toString() != "0") return null;
    final data = payload["data"] as Map<String, dynamic>?;
    if (data == null) return null;

    return MirrorUpdateInfo(
      versionName: _mirrorString(data, ["version_name"]) ?? "",
      releaseNote: _mirrorString(data, ["release_note"]) ?? "",
    );
  } catch (_) {
    return null;
  }
}

Future<List<ContributorInfo>> _getContributors() async {
  final contributors = <ContributorInfo>[];
  var page = 1;
  const perPage = 100;

  while (true) {
    final response = await http.get(
      Uri.parse(contributorsApiUrl).replace(
        queryParameters: {
          "per_page": "$perPage",
          "page": "$page",
        },
      ),
      headers: const {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
      },
    );
    if (response.statusCode != 200) {
      throw HttpException("contributors request failed: ${response.statusCode}");
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    for (final item in data) {
      final contributor = item as Map<String, dynamic>;
      final username = contributor["login"] as String? ?? "";
      final avatarUrl = contributor["avatar_url"] as String? ?? "";
      final profileUrl = contributor["html_url"] as String? ?? "";
      if (username.isNotEmpty && avatarUrl.isNotEmpty && profileUrl.isNotEmpty) {
        contributors.add(
          ContributorInfo(
            username: username,
            avatarUrl: avatarUrl,
            profileUrl: profileUrl,
          ),
        );
      }
    }

    if (data.length < perPage) return contributors;
    page++;
  }
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
    downloadUrl: apk?["browser_download_url"] as String? ?? githubLatestApkUrl,
    updateLog: data["body"] as String? ?? "",
    source: "GitHub Releases API",
    mirrorUrl: mirrorResId.isEmpty ? null : mirrorProjectUrl,
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
    downloadUrl: githubLatestApkUrl,
    updateLog: _xmlValue(entry, "summary"),
    source: "Releases Atom",
    mirrorUrl: mirrorResId.isEmpty ? null : mirrorProjectUrl,
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
  final Set<String> selectedArchivedNoteIds = <String>{};
  bool navigationBlurEnabled = true;

  @override
  void initState() {
    super.initState();
    loadNotesFromStorage();
    loadNavigationBlurPreference();
    autoCheckUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStoragePermissionOnStartup());
  }

  Future<void> _checkStoragePermissionOnStartup() async {
    if (!mounted) return;
    await ensureStoragePermission(context);
  }

  Future<void> loadNotesFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString("saved_notes");
    if (notesJson != null && mounted) {
      final decoded = jsonDecode(notesJson) as List<dynamic>;
      setState(() => notes = decoded.map((item) => Note.fromJson(item)).toList());
    }
  }

  Future<void> loadNavigationBlurPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        navigationBlurEnabled = prefs.getBool("navigationBlur") ?? true;
      });
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
    UpdateInfo? githubInfo;
    try {
      githubInfo = await _getUpdateFromApi();
    } catch (_) {}

    if (githubInfo == null) {
      try {
        githubInfo = await _getUpdateFromAtom();
      } catch (_) {}
    }

    final mirror = await _getMirrorUpdate();
    if (mirror == null || mirror.versionName.isEmpty) return githubInfo;
    if (githubInfo != null && compareVersions(mirror.versionName, githubInfo.displayVersion) < 0) {
      return githubInfo;
    }

    final sameVersion = githubInfo != null && compareVersions(mirror.versionName, githubInfo.displayVersion) == 0;
    final githubFallback = sameVersion ? githubInfo.downloadUrl : "";
    return UpdateInfo(
      tagName: mirror.versionName,
      releaseUrl: githubInfo?.releaseUrl ?? "$repositoryUrl/releases",
      downloadUrl: githubFallback,
      updateLog: mirror.releaseNote.isNotEmpty ? mirror.releaseNote : (githubInfo?.updateLog ?? ""),
      source: "Mirror酱 API",
      mirrorUrl: mirrorProjectUrl,
    );
  }

  Future<void> checkVersion({
    bool showNoUpdateToast = true,
    VoidCallback? onUpdateFound,
  }) async {
    final update = await _fetchLatestUpdate();
    if (!mounted) return;

    if (update == null || update.tagName.isEmpty) {
      if (showNoUpdateToast) {
        showAppToast(context, "无法获取版本信息，请检查网络后重试", isError: true);
      }
      return;
    }

    if (compareVersions(update.displayVersion, currentVersion) <= 0) {
      if (showNoUpdateToast) {
        showAppToast(context, "当前已是最新版本");
      }
      return;
    }

    onUpdateFound?.call();
    if (onUpdateFound != null) {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
    }
    final shouldDownload = await showDialog<bool>(
          context: context,
          builder: (context) => UpdateDialog(update: update),
        ) ??
        false;
    if (!mounted || !shouldDownload || update.downloadUrl.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => UpdateDialog(update: update, downloadOnly: true),
    );
  }

  bool get selectionMode => selectedNoteIds.isNotEmpty;
  bool get archiveSelectionMode => selectedArchivedNoteIds.isNotEmpty;

  void toggleNoteSelection(Note note) {
    setState(() {
      if (selectedNoteIds.contains(note.id)) {
        selectedNoteIds.remove(note.id);
      } else {
        selectedNoteIds.add(note.id);
      }
    });
  }

  void toggleArchivedNoteSelection(Note note) {
    setState(() {
      if (selectedArchivedNoteIds.contains(note.id)) {
        selectedArchivedNoteIds.remove(note.id);
      } else {
        selectedArchivedNoteIds.add(note.id);
      }
    });
  }

  void toggleArchivedSelectAll() {
    final archivedIds = notes.where((note) => note.isArchived).map((note) => note.id).toSet();
    setState(() {
      if (archivedIds.isNotEmpty && selectedArchivedNoteIds.length == archivedIds.length) {
        selectedArchivedNoteIds.clear();
      } else {
        selectedArchivedNoteIds
          ..clear()
          ..addAll(archivedIds);
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
            title: Row(
              children: [
                Icon(Icons.delete_forever, color: Theme.of(dialogContext).colorScheme.error),
                const SizedBox(width: 8),
                Expanded(child: Text(title)),
              ],
            ),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("取消"),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.delete_forever),
                label: const Text("删除"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> deleteNotes(Iterable<Note> notesToDelete) async {
    final ids = notesToDelete.map((note) => note.id).toSet();
    if (ids.isEmpty) return false;
    final confirmed = await _confirmDelete(
      ids.length == 1 ? "删除便签" : "删除已选便签",
      "删除后将无法恢复，确定要删除吗？",
    );
    if (!confirmed || !mounted) return false;

    setState(() {
      notes.removeWhere((note) => ids.contains(note.id));
      selectedNoteIds.removeAll(ids);
      selectedArchivedNoteIds.removeAll(ids);
    });
    await saveNotesToStorage();
    return true;
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
              if (savedNote.isArchived) {
                selectedNoteIds.remove(savedNote.id);
              } else {
                selectedArchivedNoteIds.remove(savedNote.id);
              }
            });
            saveNotesToStorage();
          },
          onDelete: (note) => deleteNotes([note]),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final navigationBackground = colorScheme.surfaceContainerHighest.withAlpha(
      navigationBlurEnabled
          ? (isDark ? 150 : 138)
          : 255,
    );
    final navigationBorder = navigationBlurEnabled
        ? (isDark
            ? Colors.white.withAlpha(48)
            : colorScheme.outlineVariant.withAlpha(185))
        : (isDark
            ? Colors.white.withAlpha(28)
            : colorScheme.outlineVariant.withAlpha(150));
    final navigationShadow = navigationBlurEnabled
        ? (isDark ? Colors.black.withAlpha(120) : Colors.black.withAlpha(48))
        : (isDark ? Colors.black.withAlpha(100) : Colors.black.withAlpha(35));
    final selectedNavigationBackground = isDark
        ? colorScheme.primary.withAlpha(190)
        : colorScheme.primaryContainer.withAlpha(245);
    final selectedNavigationForeground = isDark
        ? colorScheme.onPrimary
        : colorScheme.onPrimaryContainer;
    final unselectedNavigationForeground = colorScheme.onSurfaceVariant;
    final pageSelectionMode = currentIndex == 0
        ? selectionMode
        : currentIndex == 1
            ? archiveSelectionMode
            : false;
    final pageSelectedNoteIds = currentIndex == 0
        ? selectedNoteIds
        : currentIndex == 1
            ? selectedArchivedNoteIds
            : const <String>{};
    return PopScope(
      canPop: !pageSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !pageSelectionMode) return;
        setState(() {
          if (currentIndex == 0) {
            selectedNoteIds.clear();
          } else if (currentIndex == 1) {
            selectedArchivedNoteIds.clear();
          }
        });
      },
      child: Scaffold(
        body: Stack(
        children: [
          PageView(
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
              ),
              ArchivePage(
                notes: notes,
                selectionMode: archiveSelectionMode,
                selectedNoteIds: selectedArchivedNoteIds,
                onOpenNote: openEditPage,
                onToggleSelection: toggleArchivedNoteSelection,
                onToggleSelectAll: toggleArchivedSelectAll,
              ),
              const AppRecommendationsPage(),
              SettingPage(onCheckUpdate: checkVersion),
            ],
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: navigationBlurEnabled ? 26 : 0,
                  sigmaY: navigationBlurEnabled ? 26 : 0,
                ),
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: navigationBackground,
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: navigationBorder),
                    boxShadow: [
                      BoxShadow(color: navigationShadow, blurRadius: 22, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    children: List.generate(4, (index) {
                      final selected = currentIndex == index;
                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: Center(
                            child: SizedBox(
                              width: 80,
                              height: 48,
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () {
                                    setState(() => currentIndex = index);
                                    pageCtrl.animateToPage(
                                      index,
                                      duration: const Duration(milliseconds: 220),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeInOut,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? selectedNavigationBackground
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Icon(
                                      index == 0
                                          ? Icons.sticky_note_2_outlined
                                          : index == 1
                                              ? Icons.archive_outlined
                                              : index == 2
                                                  ? Icons.apps_outlined
                                                  : Icons.settings_outlined,
                                      color: selected
                                          ? selectedNavigationForeground
                                          : unselectedNavigationForeground,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
          if (currentIndex == 0 || (currentIndex == 1 && pageSelectionMode))
            Positioned(
              right: 24,
              bottom: 100,
              child: FloatingActionButton(
                backgroundColor: pageSelectionMode
                    ? colorScheme.error
                    : colorScheme.primaryContainer,
                foregroundColor: pageSelectionMode
                    ? colorScheme.onError
                    : colorScheme.onPrimaryContainer,
                onPressed: pageSelectionMode
                    ? () => deleteNotes(
                          notes.where((note) => pageSelectedNoteIds.contains(note.id)),
                        )
                    : currentIndex == 0
                        ? () => openEditPage()
                        : null,
                child: Icon(pageSelectionMode ? Icons.delete_forever : Icons.add),
              ),
            ),
        ],
        ),
      ),
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
  final bool downloadOnly;

  const UpdateDialog({
    super.key,
    required this.update,
    this.downloadOnly = false,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> with WidgetsBindingObserver {
  bool downloading = false;
  double progress = 0;
  int downloadedBytes = 0;
  int totalBytes = 0;
  bool waitingForPermissionReturn = false;
  String? downloadedPath;
  http.Client? downloadClient;
  bool downloadCancelled = false;
  String status = "准备下载";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.downloadOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _downloadAndInstall());
    }
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

  Future<bool> _verifyApkSignature(String path) async {
    try {
      return await installerChannel.invokeMethod<bool>("verifyApkSignature", {"path": path}) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _installApk(String path) async {
    try {
      await installerChannel.invokeMethod<void>("installApk", {"path": path});
    } catch (_) {
      if (mounted) {
        showAppToast(context, "无法打开系统安装器", isError: true);
      }
    }
  }

  Future<void> _confirmInstallPermission() async {
    if (!mounted || downloading) return;
    final enabled = await _canInstallPackages();
    if (!mounted) return;
    if (enabled) {
      final path = await SharedPreferences.getInstance().then((prefs) => prefs.getString("pending_apk_path"));
      if (!mounted) return;
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
              final enabled = await _canInstallPackages();
              if (!mounted) return;
              if (enabled) {
                final prefs = await SharedPreferences.getInstance();
                if (!mounted) return;
                final path = prefs.getString("pending_apk_path");
                if (path != null) await _installApk(path);
                return;
              }
              showAppToast(context, "仍未开启安装权限，请稍后重试", isError: true);
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

  Future<void> _cancelDownload() async {
    downloadCancelled = true;
    downloadClient?.close();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _downloadAndInstall() async {
    if (!mounted || downloading || widget.update.downloadUrl.isEmpty) return;
    if (!await ensureStoragePermission(context)) return;
    if (!mounted) return;
    downloadCancelled = false;
    setState(() {
      downloading = true;
      downloadedPath = null;
      downloadedBytes = 0;
      totalBytes = 0;
      progress = 0;
      status = "正在下载";
    });

    final client = http.Client();
    downloadClient = client;
    IOSink? sink;
    try {
      final response = await client.send(http.Request("GET", Uri.parse(widget.update.downloadUrl)));
      if (response.statusCode != 200) {
        throw HttpException("download failed: ${response.statusCode}");
      }

      totalBytes = response.contentLength ?? 0;
      final directory = await getConfiguredDownloadDirectory();
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

      if (!await _verifyApkSignature(file.path)) {
        await file.delete();
        throw const HttpException("APK signature mismatch");
      }
      if (!mounted) return;
      setState(() {
        downloading = false;
        downloadedPath = file.path;
        status = "下载完成，校验通过";
      });
      showAppToast(context, "下载完成，校验通过");
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
      client.close();
      if (identical(downloadClient, client)) downloadClient = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.downloadOnly) return _buildDownloadDialog(context);
    return _buildInfoDialog(context);
  }

  Widget _buildInfoDialog(BuildContext context) {
    final hasDownload = widget.update.downloadUrl.isNotEmpty;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      title: Row(
        children: [
          const Icon(Icons.system_update),
          const SizedBox(width: 8),
          Expanded(child: Text("发现新版本 v${widget.update.displayVersion}")),
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
            Container(
              height: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.update.updateLog.isEmpty ? "暂无更新日志" : widget.update.updateLog,
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("稍后"),
        ),
        if (hasDownload)
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.download),
            label: const Text("应用内更新"),
          ),
        if (widget.update.mirrorUrl != null)
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () async {
              final launched = await launchUrl(
                Uri.parse(widget.update.mirrorUrl!),
                mode: LaunchMode.externalApplication,
              );
              if (!launched && context.mounted) {
                showAppToast(context, "无法打开浏览器", isError: true);
              }
            },
            icon: const Icon(Icons.speed, size: 18),
            label: const Text(
              "Mirror酱高速下载",
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12),
            ),
          ),
        TextButton.icon(
          onPressed: () async {
            final launched = await launchUrl(
              Uri.parse(widget.update.releaseUrl),
              mode: LaunchMode.externalApplication,
            );
            if (!launched && context.mounted) {
              showAppToast(context, "无法打开浏览器", isError: true);
            }
          },
          icon: const Icon(Icons.open_in_new),
          label: const Text("浏览器下载"),
        ),
      ],
    );
  }

  Widget _buildDownloadDialog(BuildContext context) {
    final completed = downloadedPath != null;
    final failed = !downloading && status == "下载失败";
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      title: Row(
        children: [
          const Icon(Icons.download),
          const SizedBox(width: 8),
          Expanded(child: Text("下载 v${widget.update.displayVersion}")),
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
          TextButton(
            onPressed: _cancelDownload,
            child: const Text("取消"),
          ),
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
            onPressed: _downloadAndInstall,
            child: const Text("重试"),
          ),
        ],
        if (completed)
          FilledButton.icon(
            onPressed: () => _prepareInstall(downloadedPath!),
            icon: const Icon(Icons.install_mobile),
            label: const Text("立即安装"),
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

  const NoteHomePage({
    super.key,
    required this.notes,
    required this.selectionMode,
    required this.selectedNoteIds,
    required this.onOpenNote,
    required this.onToggleSelection,
    required this.onToggleSelectAll,
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
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_add_outlined, size: 48),
                  SizedBox(height: 12),
                  Text("暂无便签，点击右下角加号新建"),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 160),
              itemCount: activeNotes.length,
              itemBuilder: (context, index) {
                final note = activeNotes[index];
                final selected = selectedNoteIds.contains(note.id);
                final foregroundColor = noteTextColor(note.color);
                return Card(
                  color: note.color,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      style: TextStyle(
                        color: foregroundColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: foregroundColor.withAlpha(210)),
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
  final bool selectionMode;
  final Set<String> selectedNoteIds;
  final ValueChanged<Note> onOpenNote;
  final ValueChanged<Note> onToggleSelection;
  final VoidCallback onToggleSelectAll;

  const ArchivePage({
    super.key,
    required this.notes,
    required this.selectionMode,
    required this.selectedNoteIds,
    required this.onOpenNote,
    required this.onToggleSelection,
    required this.onToggleSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final archivedNotes = notes.where((note) => note.isArchived).toList();
    final allSelected = archivedNotes.isNotEmpty && selectedNoteIds.length == archivedNotes.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(selectionMode ? "已选择 ${selectedNoteIds.length} 项" : "归档"),
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
      body: archivedNotes.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.archive_outlined, size: 48),
                  SizedBox(height: 12),
                  Text("暂无归档便签"),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 160),
              itemCount: archivedNotes.length,
              itemBuilder: (context, index) {
                final note = archivedNotes[index];
                final selected = selectedNoteIds.contains(note.id);
                final foregroundColor = noteTextColor(note.color);
                return Card(
                  color: note.color,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      style: TextStyle(
                        color: foregroundColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: foregroundColor.withAlpha(210)),
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
  final Future<bool> Function(Note) onDelete;

  const NoteEditPage({
    super.key,
    required this.existingNote,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<NoteEditPage> {
  late final TextEditingController titleCtrl;
  late final TextEditingController contentCtrl;
  late Color selectedColor;
  late bool isArchived;
  bool hasUnsavedChanges = false;

  final colorOptions = [
    Colors.lightGreen.shade100,
    Colors.yellow.shade100,
    Colors.pink.shade100,
    Colors.blue.shade100,
    Colors.purple.shade100,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.existingNote?.title ?? "");
    contentCtrl = TextEditingController(text: widget.existingNote?.content ?? "");
    selectedColor = widget.existingNote?.color ?? Colors.lightGreen.shade100;
    isArchived = widget.existingNote?.isArchived ?? false;
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
        content: const Text("你有未保存的内容。选择“退出且不保存”将直接丢弃这些修改。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("退出且不保存"),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _saveNoteAsText(Note note) async {
    final safeTitle = note.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), "_").trim();
    final filename = "${safeTitle.isEmpty ? "无标题" : safeTitle}.txt";
    try {
      return await installerChannel.invokeMethod<bool>("saveTextFile", {
            "filename": filename,
            "content": "${note.title}\n\n${note.content}",
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Note _buildNote() {
    return Note(
      id: widget.existingNote?.id,
      title: titleCtrl.text.isEmpty ? "无标题" : titleCtrl.text,
      content: contentCtrl.text,
      color: selectedColor,
      createTime: widget.existingNote?.createTime ?? DateTime.now(),
      isArchived: isArchived,
    );
  }

  void _toggleArchive() {
    setState(() {
      isArchived = !isArchived;
      hasUnsavedChanges = true;
    });
    showAppToast(context, isArchived ? "已归档" : "已取消归档");
  }

  Future<void> _deleteNote() async {
    final note = widget.existingNote;
    if (note == null) return;
    final deleted = await widget.onDelete(note);
    if (!mounted) return;
    if (deleted) Navigator.pop(context);
  }

  void _showSaveOptions() {
    final note = _buildNote();
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
              showAppToast(context, "已保存");
              Navigator.pop(context);
            },
            child: const Text("应用内保存并退出"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final saved = await _saveNoteAsText(note);
              if (saved) {
                if (!mounted) return;
                showAppToast(context, "TXT 文件已保存");
              }
            },
            child: const Text("保存为 TXT 文件"),
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
              tooltip: isArchived ? "移出归档" : "归档",
              onPressed: _toggleArchive,
              color: isArchived
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              icon: Icon(isArchived ? Icons.archive : Icons.archive_outlined),
            ),
            IconButton(
              tooltip: "删除",
              onPressed: widget.existingNote == null ? null : _deleteNote,
              color: Theme.of(context).colorScheme.error,
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip: "保存",
              onPressed: _showSaveOptions,
              color: Theme.of(context).colorScheme.primary,
              icon: const Icon(Icons.save_outlined),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    "颜色预览",
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 24,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
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
                        width: 34,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selectedColor == color
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
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
  final CheckUpdateCallback onCheckUpdate;
  const SettingPage({super.key, required this.onCheckUpdate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("设置")),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 160),
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
          ValueListenableBuilder<bool>(
            valueListenable: globalNavigationBlurNotifier,
            builder: (context, blurEnabled, _) => SwitchListTile(
              secondary: const Icon(Icons.blur_on),
              title: const Text("导航栏毛玻璃模糊"),
              subtitle: const Text("重启软件后生效"),
              value: blurEnabled,
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool("navigationBlur", value);
                globalNavigationBlurNotifier.value = value;
                if (context.mounted) {
                  showAppToast(context, "重启软件后生效");
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text("下载文件目录"),
            subtitle: const Text("默认使用 Download 文件夹，可设置子目录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => const DownloadDirectoryDialog(),
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
  final CheckUpdateCallback onCheckUpdate;
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
    if (mounted) {
      setState(() {
        autoCheck = prefs.getBool("autoCheckUpdate") ?? true;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => UpdateCheckingDialog(
        onCheckUpdate: widget.onCheckUpdate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("更新设置")),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 160),
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
            leading: const Icon(Icons.speed),
            title: const Text("Mirror酱高速下载"),
            subtitle: const Text(
              "国内免梯高速CDN镜像下载最新安装包",
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: () async {
              final launched = await launchUrl(
                Uri.parse(mirrorProjectUrl),
                mode: LaunchMode.externalApplication,
              );
              if (!launched && context.mounted) {
                showAppToast(context, "无法打开浏览器", isError: true);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text("检查更新"),
            onTap: _checkForUpdates,
          ),
        ],
      ),
    );
  }
}

class UpdateCheckingDialog extends StatefulWidget {
  final CheckUpdateCallback onCheckUpdate;

  const UpdateCheckingDialog({
    super.key,
    required this.onCheckUpdate,
  });

  @override
  State<UpdateCheckingDialog> createState() => _UpdateCheckingDialogState();
}

class _UpdateCheckingDialogState extends State<UpdateCheckingDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
  }

  Future<void> _checkForUpdates() async {
    await widget.onCheckUpdate(
      onUpdateFound: () {
        if (mounted) Navigator.pop(context);
      },
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      title: Text("检查更新"),
      content: SizedBox(
        width: 280,
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 16),
            Expanded(child: Text("正在检查最新版本…")),
          ],
        ),
      ),
    );
  }
}

class ThirdPartyLicensesDialog extends StatelessWidget {
  const ThirdPartyLicensesDialog({super.key});

  static const licenseText = """
ZexNote Custom License Agreement
Copyright (c) 2026 BaiXiaoTao520

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to use,
study, run, inspect and modify the Software for personal, non-commercial purposes,
subject to the following conditions:

1. This software is only allowed for personal non-commercial use. It is prohibited
to sell this software or modified derivative versions for commercial purposes,
package for payment, embed advertisements, or distribute for profit.

2. Any modified or derivative versions must retain the original copyright notice
and the text of this license. Derivative works must also follow this agreement
and cannot be changed to closed-source licenses.

3. It is forbidden to remove the identification information about ZexNote and
the original author inside the software.

4. The software is provided as-is without warranty. The author is not liable for
software failures, data loss, or device damage. Users shall bear all risks arising
from the use of this software.

5. It is prohibited to use the code of this project for black-gray industry or
malicious cracking tools.

6. Fork of this repository is allowed, but releasing Release versions must
retain the original update detection logic.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
""";

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("第三方许可证"),
      content: const SizedBox(
        width: double.maxFinite,
        height: 360,
        child: SingleChildScrollView(
          child: Text(licenseText, style: TextStyle(height: 1.5)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("确定"),
        ),
      ],
    );
  }
}

class DownloadDirectoryDialog extends StatefulWidget {
  const DownloadDirectoryDialog({super.key});

  @override
  State<DownloadDirectoryDialog> createState() => _DownloadDirectoryDialogState();
}

class _DownloadDirectoryDialogState extends State<DownloadDirectoryDialog> {
  late final TextEditingController directoryController;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    directoryController = TextEditingController();
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    directoryController.text = prefs.getString("downloadDirectoryName") ?? "";
    setState(() => loading = false);
  }

  Future<void> _saveDirectory() async {
    final directoryName = directoryController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("downloadDirectoryName", directoryName);
    if (!mounted) return;
    Navigator.pop(context);
    showAppToast(context, "下载目录已保存，后续下载立即生效");
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("下载文件目录"),
      content: loading
          ? const SizedBox(
              height: 72,
              child: Center(child: CircularProgressIndicator()),
            )
          : TextField(
              controller: directoryController,
              decoration: const InputDecoration(
                labelText: "Download 子目录",
                hintText: "留空使用 Download 根目录",
                prefixIcon: Icon(Icons.folder_outlined),
              ),
            ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text("取消"),
        ),
        FilledButton(
          onPressed: loading ? null : _saveDirectory,
          child: const Text("保存"),
        ),
      ],
    );
  }

  @override
  void dispose() {
    directoryController.dispose();
    super.dispose();
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
      showAppToast(context, "无法打开浏览器", isError: true);
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
                child: Icon(
                  Icons.note_alt_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
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
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text("贡献者鸣谢"),
                subtitle: const Text("查看参与项目设计与代码贡献的开发者"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => const ContributorsDialog(),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text("第三方许可证"),
                subtitle: const Text("查看应用使用的开源组件许可"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => const ThirdPartyLicensesDialog(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContributorsDialog extends StatefulWidget {
  const ContributorsDialog({super.key});

  @override
  State<ContributorsDialog> createState() => _ContributorsDialogState();
}

class _ContributorsDialogState extends State<ContributorsDialog> {
  List<ContributorInfo>? contributors;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContributors();
  }

  Future<void> _loadContributors() async {
    try {
      final result = await _getContributors();
      if (!mounted) return;
      setState(() => contributors = result);
    } catch (_) {
      if (!mounted) return;
      setState(() => errorMessage = "无法加载贡献者列表，请检查网络后重试");
    }
  }

  Future<void> _openContributor(ContributorInfo contributor) async {
    final launched = await launchUrl(
      Uri.parse(contributor.profileUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      showAppToast(context, "无法打开浏览器", isError: true);
    }
  }

  Widget _buildContributor(ContributorInfo contributor) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openContributor(contributor),
      child: SizedBox(
        width: 112,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: ClipOval(
                child: Image.network(
                  contributor.avatarUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.person_outline, size: 30),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              contributor.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (contributors == null && errorMessage == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorMessage != null) {
      return SizedBox(
        height: 220,
        child: Center(child: Text(errorMessage!, textAlign: TextAlign.center)),
      );
    }
    if (contributors!.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text("暂无公开贡献者")),
      );
    }

    return SizedBox(
      height: 220,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 112,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: contributors!.length,
        itemBuilder: (context, index) => _buildContributor(contributors![index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("贡献者鸣谢"),
      content: _buildContent(context),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("确定"),
        ),
      ],
    );
  }
}
