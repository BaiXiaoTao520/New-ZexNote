package com.zex.note

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.ExperimentalAnimationApi
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideIntoContainer
import androidx.compose.animation.slideOutOfContainer
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArchiveOutlined
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material.icons.filled.SystemUpdate
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import coil.compose.AsyncImage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

private const val CURRENT_VERSION = "8.0.0"
private const val REPOSITORY = "BaiXiaoTao520/New-ZexNote"
private const val GITHUB_RELEASES = "https://api.github.com/repos/$REPOSITORY/releases/latest"
private const val GITHUB_ATOM = "https://github.com/$REPOSITORY/releases.atom"
private const val MIRROR_API = "https://mirrorchyan.com/api/resources/New-ZexNote/latest"
private const val MIRROR_PAGE = "https://mirrorchyan.com/zh/projects?rid=New-ZexNote"
private const val README_URL = "https://github.com/$REPOSITORY/blob/main/README.md"

private data class Note(val id: String, val title: String, val content: String, val color: Int, val createdAt: String, val archived: Boolean)
private data class UpdateInfo(val version: String, val log: String, val githubUrl: String, val apkUrl: String, val source: String)
private data class RecommendedApp(val name: String, val version: String, val description: String, val url: String, val browserOnly: Boolean = false)

private val recommendations = listOf(
    RecommendedApp("AppShare", "", "App 多版本讨论、评分与资源分享平台", "https://app.sharess.cn/download", true),
    RecommendedApp("ReveriePaint", "v1.3.0", "基于 Krita 核心引擎打造的 Android 原生数字绘画应用", "https://gh.xmly.dev/https://github.com/LanRhyme/ReveriePaint/releases/download/v1.3.0/ReveriePaint-v1.3.0.apk"),
    RecommendedApp("星环浏览器-标准版", "", "新一代星环，不止是浏览器，更是你的生活伴侣。", "https://roamexplore.rth1.xyz/", true),
    RecommendedApp("Tomato", "v2.0.1", "开源简洁的番茄钟软件", "https://gh.xmly.dev/https://github.com/nsh07/Tomato/releases/download/v2.0.1/tomato-v2.0.1-release.apk"),
    RecommendedApp("Komi Store", "v1.9.2", "开源 Github 仓库应用商店", "https://gh.xmly.dev/https://github.com/komi-store/komi-store/releases/download/v1.9.2/Komi-Store-1.9.2.apk"),
    RecommendedApp("CoolMonitor", "v5.3.2", "开源设备健康监控诊断工具", "https://gitee.com/hm1997a/cool-monitor/releases/download/v5.3.2/CoolMonitor_v5.3.2_release_20260926_130735.apk"),
)

private class AppState(private val services: AppServices) {
    var notes by mutableStateOf(loadNotes())
    var dynamicColor by mutableStateOf(services.getBoolean("dynamicColor", true))
    var themeSeed by mutableStateOf(Color(services.getInt("themeSeedColor", Color(0xFF69A88D).toArgb())))
    var navigationBlur by mutableStateOf(services.getBoolean("navigationBlur", true))
    var monetBackground by mutableStateOf(services.getBoolean("monetBackground", false))

    private fun loadNotes(): List<Note> = runCatching {
        val array = JSONArray(services.getString("saved_notes"))
        List(array.length()) { i ->
            val item = array.getJSONObject(i)
            Note(item.getString("id"), item.getString("title"), item.getString("content"), item.getInt("color"), item.getString("createTime"), item.optBoolean("isArchived"))
        }
    }.getOrDefault(emptyList())

    fun saveNotes(value: List<Note>) {
        notes = value
        val array = JSONArray()
        value.forEach { note ->
            array.put(JSONObject().apply {
                put("id", note.id); put("title", note.title); put("content", note.content)
                put("color", note.color); put("createTime", note.createdAt); put("isArchived", note.archived)
            })
        }
        services.setString("saved_notes", array.toString())
    }

    fun setDynamicColor(value: Boolean) { dynamicColor = value; services.setBoolean("dynamicColor", value) }
    fun setThemeSeed(value: Color) { themeSeed = value; services.setInt("themeSeedColor", value.toArgb()) }
    fun setNavigationBlur(value: Boolean) { navigationBlur = value; services.setBoolean("navigationBlur", value) }
    fun setMonetBackground(value: Boolean) { monetBackground = value; services.setBoolean("monetBackground", value) }
}

@OptIn(ExperimentalAnimationApi::class)
@Composable
fun ZexNoteApp(services: AppServices) {
    val state = remember { AppState(services) }
    val nav = rememberNavController()
    val context = LocalContext.current
    val light = if (state.dynamicColor && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) androidx.compose.material3.dynamicLightColorScheme(context) else androidx.compose.material3.lightColorScheme(primary = state.themeSeed)
    val dark = if (state.dynamicColor && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) androidx.compose.material3.dynamicDarkColorScheme(context) else androidx.compose.material3.darkColorScheme(primary = state.themeSeed)
    var startupCheck by remember { mutableStateOf(services.getBoolean("autoCheckUpdate", true)) }
    ZexTheme(light, dark) {
        Surface(color = MaterialTheme.colorScheme.surface, modifier = Modifier.fillMaxSize()) {
            Box(Modifier.fillMaxSize()) {
                if (state.monetBackground) MonetBackground(state.themeSeed)
                NavHost(navController = nav, startDestination = "home", enterTransition = { fadeIn() + slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.Left) }, exitTransition = { fadeOut() + slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.Left) }) {
                    composable("home") { NotesScreen(state, false, nav) }
                    composable("archive") { NotesScreen(state, true, nav) }
                    composable("recommendations") { RecommendationsScreen(services, nav) }
                    composable("settings") { SettingsScreen(state, nav) }
                    composable("settings/directory") { DirectoryScreen(services, nav) }
                    composable("theme") { ThemeScreen(state, nav) }
                    composable("updates") { UpdateSettingsScreen(services, nav) }
                    composable("about") { AboutScreen(services, nav) }
                    composable("edit/{id}") { entry -> EditorScreen(state, entry.arguments?.getString("id"), nav) }
                }
            }
        }
    }
    if (startupCheck) UpdateDialogCompose(services) { startupCheck = false }
}

@Composable
private fun ZexTheme(light: androidx.compose.material3.ColorScheme, dark: androidx.compose.material3.ColorScheme, content: @Composable () -> Unit) {
    androidx.compose.material3.MaterialTheme(colorScheme = if (androidx.compose.foundation.isSystemInDarkTheme()) dark else light, typography = androidx.compose.material3.Typography(), content = content)
}

@Composable
private fun MonetBackground(seed: Color) {
    val transition = rememberInfiniteTransition(label = "monet-background")
    val phase by transition.animateFloat(0f, 1f, infiniteRepeatable(tween(18000), RepeatMode.Reverse), label = "monet-phase")
    Canvas(Modifier.fillMaxSize()) {
        drawCircle(seed.copy(alpha = 0.14f), size.minDimension * 0.42f, Offset(size.width * (0.2f + phase * 0.35f), size.height * 0.22f))
        drawCircle(MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.12f), size.minDimension * 0.48f, Offset(size.width * (0.82f - phase * 0.3f), size.height * 0.5f))
        drawCircle(MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.1f), size.minDimension * 0.5f, Offset(size.width * 0.35f, size.height * (0.82f - phase * 0.2f)))
    }
}

private fun navItems() = listOf("home" to Icons.Default.Edit, "archive" to Icons.Default.ArchiveOutlined, "recommendations" to Icons.Default.Storefront, "settings" to Icons.Default.Settings)

@Composable
private fun BottomNav(nav: NavHostController) {
    val current by nav.currentBackStackEntryAsState()
    val route = current?.destination?.route ?: "home"
    Surface(
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp).navigationBarsPadding(),
        shape = RoundedCornerShape(34.dp),
        tonalElevation = 6.dp,
        shadowElevation = 10.dp,
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f),
    ) {
        NavigationBar(containerColor = Color.Transparent) {
            navItems().forEach { (name, icon) ->
                NavigationBarItem(selected = route == name, onClick = { nav.navigate(name) { launchSingleTop = true; popUpTo("home") { saveState = true } } }, icon = { Icon(icon, null) }, label = { Text(name.replaceFirstChar { it.uppercase() }) })
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun NotesScreen(state: AppState, archived: Boolean, nav: NavHostController) {
    var selected by remember { mutableStateOf(setOf<String>()) }
    val visible = state.notes.filter { it.archived == archived }
    Scaffold(containerColor = Color.Transparent, topBar = { TopAppBar(title = { Text(if (selected.isEmpty()) if (archived) "归档" else "ZexNote" else "已选择 ${selected.size} 项") }) }, bottomBar = { BottomNav(nav) }, floatingActionButton = { FloatingActionButton(onClick = { if (selected.isEmpty()) nav.navigate("edit/new") else { state.saveNotes(state.notes.filterNot { selected.contains(it.id) }); selected = emptySet() } }) { Icon(if (selected.isEmpty()) Icons.Default.Add else Icons.Default.Delete, null) } }) { padding ->
        LazyColumn(Modifier.padding(padding).fillMaxSize()) {
            items(visible, key = { it.id }) { note ->
                Card(Modifier.padding(horizontal = 16.dp, vertical = 6.dp).fillMaxWidth().clickable { if (selected.isEmpty()) nav.navigate("edit/${note.id}") else selected = selected.toggle(note.id) }) {
                    ListItem(leadingContent = { if (selected.isNotEmpty()) Checkbox(selected.contains(note.id), { selected = selected.toggle(note.id) }) }, headlineContent = { Text(note.title, fontWeight = FontWeight.Bold) }, supportingContent = { Text(note.content, maxLines = 2) })
                }
            }
        }
    }
}

private fun Set<String>.toggle(value: String) = if (contains(value)) this - value else this + value

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EditorScreen(state: AppState, id: String?, nav: NavHostController) {
    val context = LocalContext.current
    val old = state.notes.firstOrNull { it.id == id }
    var title by remember { mutableStateOf(if (id == "new") "" else old?.title ?: "") }
    var content by remember { mutableStateOf(if (id == "new") "" else old?.content ?: "") }
    var archived by remember { mutableStateOf(old?.archived ?: false) }
    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) { uri -> if (uri != null) runCatching { context.contentResolver.openOutputStream(uri)?.use { it.write("${title.ifBlank { "无标题" }}\n\n$content".toByteArray()) } } }
    Scaffold(containerColor = Color.Transparent, topBar = { TopAppBar(title = { Text("编辑便签") }, navigationIcon = { IconButton({ nav.popBackStack() }) { Icon(Icons.Default.ArrowBack, null) } }, actions = { IconButton({ exportLauncher.launch("${title.ifBlank { "无标题" }}.txt") }) { Icon(Icons.Default.Share, null) }; IconButton({ val now = System.currentTimeMillis().toString(); val note = Note(old?.id ?: now, title.ifBlank { "无标题" }, content, old?.color ?: 0xFFFFF59D.toInt(), old?.createdAt ?: now, archived); state.saveNotes(state.notes.filterNot { it.id == note.id } + note); nav.popBackStack() }) { Icon(Icons.Default.Check, null) } }) }) { padding ->
        Column(Modifier.padding(padding).padding(16.dp).fillMaxSize()) {
            OutlinedTextField(title, { title = it }, Modifier.fillMaxWidth(), label = { Text("标题") })
            Spacer(Modifier.height(12.dp)); OutlinedTextField(content, { content = it }, Modifier.fillMaxWidth().weight(1f), label = { Text("内容") })
            Row(verticalAlignment = Alignment.CenterVertically) { Text("归档"); Spacer(Modifier.weight(1f)); Switch(archived, { archived = it }) }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DirectoryScreen(services: AppServices, nav: NavHostController) {
    var value by remember { mutableStateOf(services.getString("downloadDirectoryName")) }
    Scaffold(containerColor = Color.Transparent, topBar = { TopAppBar(title = { Text("下载文件目录") }, navigationIcon = { IconButton({ nav.popBackStack() }) { Icon(Icons.Default.ArrowBack, null) } }) }) { padding -> Column(Modifier.padding(padding).padding(16.dp)) { OutlinedTextField(value, { value = it }, Modifier.fillMaxWidth(), label = { Text("Download 子目录") }); Spacer(Modifier.height(16.dp)); Button({ services.setString("downloadDirectoryName", value.trim()); nav.popBackStack() }) { Text("保存") } } }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsScreen(state: AppState, nav: NavHostController) {
    Scaffold(containerColor = Color.Transparent, topBar = { TopAppBar(title = { Text("设置") }) }, bottomBar = { BottomNav(nav) }) { padding -> LazyColumn(Modifier.padding(padding)) {
        item { ListItem(leadingContent = { Icon(Icons.Default.Palette, null) }, headlineContent = { Text("主题设置") }, supportingContent = { Text("动态颜色与主题颜色自定义") }, modifier = Modifier.clickable { nav.navigate("theme") }) }
        item { ListItem(leadingContent = { Icon(Icons.Default.WaterDrop, null) }, headlineContent = { Text("导航栏毛玻璃模糊") }, supportingContent = { Text("重启软件后生效") }, trailingContent = { Switch(state.navigationBlur, { state.setNavigationBlur(it) }) }) }
        item { ListItem(leadingContent = { Icon(Icons.Default.Folder, null) }, headlineContent = { Text("下载文件目录") }, modifier = Modifier.clickable { nav.navigate("settings/directory") }) }
        item { ListItem(leadingContent = { Icon(Icons.Default.Info, null) }, headlineContent = { Text("关于 ZexNote") }, modifier = Modifier.clickable { nav.navigate("about") }) }
        item { ListItem(leadingContent = { Icon(Icons.Default.SystemUpdate, null) }, headlineContent = { Text("更新设置") }, supportingContent = { Text("自动检查与手动检查新版本") }, modifier = Modifier.clickable { nav.navigate("updates") }) }
    } }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ThemeScreen(state: AppState, nav: NavHostController) {
    var dynamic by remember { mutableStateOf(state.dynamicColor) }
    var showColors by remember { mutableStateOf(false) }
    Scaffold(containerColor = Color.Transparent, topBar = { TopAppBar(title = { Text("主题设置") }, navigationIcon = { IconButton({ nav.popBackStack() }) { Icon(Icons.Default.ArrowBack, null) } }) }) { padding -> LazyColumn(Modifier.padding(padding)) {
        item { ListItem(leadingContent = { Icon(Icons.Default.AutoAwesome, null) }, headlineContent = { Text("动态颜色（Material You）") }, supportingContent = { Text("跟随系统壁纸配色") }, trailingContent = { Switch(dynamic, { dynamic = it; state.setDynamicColor(it) }) }) }
        item { ListItem(leadingContent = { Icon(Icons.Default.WaterDrop, null) }, headlineContent = { Text("动态莫奈背景") }, supportingContent = { Text("柔和色块缓慢晕染流动的背景效果") }, trailingContent = { Switch(state.monetBackground, { state.setMonetBackground(it) }) }) }
        item { ListItem(leadingContent = { Icon(Icons.Default.Palette, null) }, headlineContent = { Text("主题颜色自定义（Beta）") }, supportingContent = { Text(if (dynamic) "你已开启动态颜色，该功能不可用" else "选择应用的主题配色风格") }, modifier = Modifier.clickable(enabled = !dynamic) { showColors = true }) }
    } }
    if (showColors) ThemeColorDialogCompose(state) { showColors = false }
}

@Composable
private fun ThemeColorDialogCompose(state: AppState, close: () -> Unit) {
    val colors = listOf("薄荷绿" to Color(0xFF69A88D), "海洋蓝" to Color(0xFF5577B8), "薰衣草" to Color(0xFF8B78B8), "暖阳橙" to Color(0xFFC47D4D), "樱粉色" to Color(0xFFB86F82))
    var selected by remember { mutableStateOf(state.themeSeed) }
    var hue by remember { mutableStateOf(selected.toArgb().toFloat() % 360f) }
    AlertDialog(
        onDismissRequest = close,
        title = { Text("主题颜色自定义（Beta）") },
        text = {
            LazyColumn {
                items(colors) { item ->
                    ListItem(
                        leadingContent = { RadioButton(item.second == selected, { selected = item.second }) },
                        headlineContent = { Text(item.first) },
                        trailingContent = { Box(Modifier.size(32.dp).clip(CircleShape).background(item.second)) },
                        modifier = Modifier.clickable { selected = item.second },
                    )
                }
                item {
                    ListItem(
                        leadingContent = { Icon(Icons.Default.Edit, null) },
                        headlineContent = { Text("自定义色相") },
                        supportingContent = { Text("拖动滑块实时选择颜色") },
                    )
                    Slider(
                        value = hue,
                        onValueChange = { hue = it; selected = Color.hsv(it, 0.68f, 0.9f) },
                        valueRange = 0f..360f,
                    )
                    Box(Modifier.fillMaxWidth().height(48.dp).clip(RoundedCornerShape(12.dp)).background(selected))
                }
            }
        },
        confirmButton = { Button({ state.setThemeSeed(selected); close() }) { Text("确定") } },
        dismissButton = { TextButton(onClick = close) { Text("取消") } },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun UpdateSettingsScreen(services: AppServices, nav: NavHostController) {
    val context = LocalContext.current
    var auto by remember { mutableStateOf(services.getBoolean("autoCheckUpdate", true)) }
    var checking by remember { mutableStateOf(false) }
    Scaffold(containerColor = Color.Transparent, topBar = { TopAppBar(title = { Text("更新设置") }, navigationIcon = { IconButton({ nav.popBackStack() }) { Icon(Icons.Default.ArrowBack, null) } }) }) { padding -> Column(Modifier.padding(padding)) {
        ListItem(leadingContent = { Icon(Icons.Default.SystemUpdate, null) }, headlineContent = { Text("启动时自动检查更新") }, supportingContent = { Text("打开应用时检查 GitHub 最新版本") }, trailingContent = { Switch(auto, { auto = it; services.setBoolean("autoCheckUpdate", it) }) })
        ListItem(leadingContent = { Icon(Icons.Default.Speed, null) }, headlineContent = { Text("Mirror酱高速下载") }, supportingContent = { Text("国内免梯高速CDN镜像下载最新安装包") }, modifier = Modifier.clickable { openUrl(context, MIRROR_PAGE) })
        ListItem(leadingContent = { Icon(Icons.Default.Search, null) }, headlineContent = { Text("检查更新") }, modifier = Modifier.clickable { checking = true })
    } }
    if (checking) UpdateDialogCompose(services) { checking = false }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RecommendationsScreen(services: AppServices, nav: NavHostController) {
    val context = LocalContext.current
    var downloadApp by remember { mutableStateOf<RecommendedApp?>(null) }
    var infoApp by remember { mutableStateOf<RecommendedApp?>(null) }
    Scaffold(containerColor = Color.Transparent, topBar = { TopAppBar(title = { Text("应用推荐") }) }, bottomBar = { BottomNav(nav) }) { padding ->
        LazyColumn(Modifier.padding(padding)) { item { Text("Zex 开发者为您精选以下应用", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(16.dp)) }; items(recommendations) { app -> Card(Modifier.padding(horizontal = 16.dp, vertical = 6.dp).fillMaxWidth().clickable { infoApp = app }) { ListItem(headlineContent = { Text(if (app.version.isBlank()) app.name else "${app.name} ${app.version}", fontWeight = FontWeight.Bold) }, supportingContent = { Text(app.description, maxLines = 2) }, trailingContent = { Icon(Icons.Default.Download, null) }) } } }
    }
    infoApp?.let { app -> RecommendationInfoDialog(app, onClose = { infoApp = null }, onDownload = { infoApp = null; if (app.browserOnly) openUrl(context, app.url) else downloadApp = app }) }
    downloadApp?.let { app -> DownloadDialogCompose(services, app) { downloadApp = null } }
}

@Composable
private fun RecommendationInfoDialog(app: RecommendedApp, onClose: () -> Unit, onDownload: () -> Unit) {
    AlertDialog(onDismissRequest = onClose, title = { Text(if (app.version.isBlank()) app.name else "${app.name} ${app.version}") }, text = { Text(app.description) }, dismissButton = { TextButton(onClose) { Text("取消") } }, confirmButton = { Button(onDownload) { Text(if (app.browserOnly) "浏览器下载" else "下载") } })
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AboutScreen(services: AppServices, nav: NavHostController) {
    val context = LocalContext.current
    var showContributors by remember { mutableStateOf(false) }
    var showSponsor by remember { mutableStateOf(false) }
    Scaffold(containerColor = Color.Transparent, topBar = { TopAppBar(title = { Text("关于 ZexNote") }, navigationIcon = { IconButton({ nav.popBackStack() }) { Icon(Icons.Default.ArrowBack, null) } }) }) { padding ->
        Column(Modifier.padding(padding).fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) { Spacer(Modifier.height(40.dp)); Text("ZexNote", style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold); Text("版本 v$CURRENT_VERSION"); ListItem(leadingContent = { Icon(Icons.Default.Language, null) }, headlineContent = { Text("访问仓库") }, modifier = Modifier.clickable { openUrl(context, "https://github.com/$REPOSITORY") }); ListItem(leadingContent = { Icon(Icons.Default.Groups, null) }, headlineContent = { Text("贡献者鸣谢") }, supportingContent = { Text("查看参与项目设计与代码贡献的开发者") }, modifier = Modifier.clickable { showContributors = true }); ListItem(leadingContent = { Icon(Icons.Default.Share, null) }, headlineContent = { Text("赞助与支持") }, supportingContent = { Text("支持作者与后续开发维护") }, modifier = Modifier.clickable { showSponsor = true }); ListItem(leadingContent = { Icon(Icons.Default.MenuBook, null) }, headlineContent = { Text("第三方许可证") }) }
    }
    if (showContributors) ContributorsDialog(services) { showContributors = false }
    if (showSponsor) SponsorDialog { showSponsor = false; openUrl(context, README_URL) }
}

private suspend fun fetchContributors(services: AppServices): List<Pair<String, String>> = withContext(Dispatchers.IO) {
    val result = mutableListOf<Pair<String, String>>()
    var page = 1
    while (true) {
        val response = services.httpClient().newCall(Request.Builder().url("https://api.github.com/repos/$REPOSITORY/contributors?per_page=100&page=$page").build()).execute()
        if (!response.isSuccessful) error("contributors request failed")
        val data = JSONArray(response.body?.string().orEmpty())
        for (i in 0 until data.length()) {
            val item = data.getJSONObject(i)
            result += item.optString("login") to item.optString("avatar_url")
        }
        if (data.length() < 100) break
        page++
    }
    result
}

@Composable
private fun ContributorsDialog(services: AppServices, close: () -> Unit) {
    val context = LocalContext.current
    var users by remember { mutableStateOf<List<Pair<String, String>>?>(null) }
    LaunchedEffect(Unit) { users = runCatching { fetchContributors(services) }.getOrDefault(emptyList()) }
    AlertDialog(onDismissRequest = close, title = { Text("贡献者鸣谢") }, text = { if (users == null) CircularProgressIndicator() else LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) { items(users!!) { (name, avatar) -> Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.clickable { openUrl(context, "https://github.com/$name") }) { AsyncImage(avatar, name, Modifier.size(56.dp).clip(CircleShape)); Text(name, maxLines = 1) } } } }, confirmButton = { Button(onClick = close) { Text("确定") } })
}

@Composable
private fun SponsorDialog(close: () -> Unit) {
    AlertDialog(onDismissRequest = close, title = { Text("赞助与支持") }, text = { LazyColumn { item { Text("无论是否选择赞助，都感谢你点开本页。愿意来了解，本身就是对项目的认可。") }; item { Spacer(Modifier.height(12.dp)); Text("独立开发者，无公司、没有服务器经费，做免费开源APP，不强求捐赠，完全自愿，不捆绑任何功能，捐赠不会解锁特殊特权。") }; item { Spacer(Modifier.height(12.dp)); Text("如果 ZexNote 帮到了你，可以自愿赞助支持作者。赞助完全自愿，不赞助也能使用全部功能，赞助不会解锁额外特权。") }; item { Spacer(Modifier.height(12.dp)); Text("如需加入QQ交流群：考虑到群维护精力有限，同时曾遭遇恶意举报干扰，入群需要至少5元的赞助门槛，感谢大家理解与配合。") } } }, confirmButton = { Button(onClick = close) { Text("跳转至浏览器") } })
}

private fun openUrl(context: Context, url: String) {
    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
}

private suspend fun fetchUpdate(services: AppServices): UpdateInfo? = withContext(Dispatchers.IO) {
    fun parseVersion(value: String): List<Int> = value.trim().removePrefix("v").split(".").mapNotNull { it.toIntOrNull() }
    fun newer(left: String, right: String): Boolean { val a = parseVersion(left); val b = parseVersion(right); return (0..2).any { (a.getOrNull(it) ?: 0) > (b.getOrNull(it) ?: 0) } }
    fun read(url: String): JSONObject? { val response = services.httpClient().newCall(Request.Builder().url(url).header("Accept", "application/json").build()).execute(); if (!response.isSuccessful) return null; return response.body?.string()?.let { JSONObject(it) } }
    val github = runCatching { read(GITHUB_RELEASES) }.getOrNull()
    val githubInfo = github?.let { data -> val assets = data.optJSONArray("assets") ?: JSONArray(); var apk = ""; for (i in 0 until assets.length()) { val asset = assets.getJSONObject(i); if (asset.optString("name").endsWith(".apk")) { apk = asset.optString("browser_download_url"); break } }; UpdateInfo(data.optString("tag_name"), data.optString("body"), data.optString("html_url", "https://github.com/$REPOSITORY/releases"), apk, "GitHub Releases API") } ?: runCatching { val response = services.httpClient().newCall(Request.Builder().url(GITHUB_ATOM).build()).execute(); val body = response.body?.string() ?: return@runCatching null; val title = Regex("<title>(.*?)</title>", RegexOption.DOT_MATCHES_ALL).find(body)?.groupValues?.get(1)?.trim() ?: return@runCatching null; UpdateInfo(title, "", "https://github.com/$REPOSITORY/releases", "https://github.com/$REPOSITORY/releases/latest/download/app-release.apk", "Releases Atom") }.getOrNull()
    val mirror = runCatching { read("$MIRROR_API?current_version=v$CURRENT_VERSION&os=android&arch=arm64")?.takeIf { it.optInt("code") == 0 }?.optJSONObject("data") }.getOrNull()
    val mirrorVersion = mirror?.optString("version_name") ?: ""; if (mirrorVersion.isBlank() || (githubInfo != null && !newer(mirrorVersion, githubInfo.version) && mirrorVersion != githubInfo.version)) return@withContext githubInfo
    UpdateInfo(mirrorVersion, mirror?.optString("release_note").orEmpty().ifBlank { githubInfo?.log.orEmpty() }, githubInfo?.githubUrl ?: "https://github.com/$REPOSITORY/releases", if (githubInfo?.version == mirrorVersion) githubInfo.apkUrl else "", "Mirror酱 API")
}

private suspend fun downloadApk(services: AppServices, url: String, name: String, progress: (Float) -> Unit): File = withContext(Dispatchers.IO) {
    val response = services.httpClient().newCall(Request.Builder().url(url).build()).execute(); check(response.isSuccessful); val body = response.body ?: error("empty response"); val file = File(services.downloadDirectory(), name); body.byteStream().use { input -> FileOutputStream(file).use { output -> val buffer = ByteArray(16 * 1024); var total = 0L; val length = body.contentLength(); while (true) { val count = input.read(buffer); if (count < 0) break; output.write(buffer, 0, count); total += count; if (length > 0) progress((total.toDouble() / length).toFloat()) } } }; file
}

@Composable
private fun UpdateDialogCompose(services: AppServices, onClose: () -> Unit) {
    var loading by remember { mutableStateOf(true) }; var update by remember { mutableStateOf<UpdateInfo?>(null) }; var downloading by remember { mutableStateOf(false) }; var permission by remember { mutableStateOf(false) }; var progress by remember { mutableStateOf(0f) }; val scope = rememberCoroutineScope(); LaunchedEffect(Unit) { update = fetchUpdate(services); loading = false }
    if (permission) AlertDialog(onDismissRequest = {}, title = { Text("需要存储权限") }, text = { Text("请先开启存储权限，返回后点击重新检测继续下载。") }, dismissButton = { TextButton({ permission = false }) { Text("取消") } }, confirmButton = { Button({ if (services.hasStoragePermission()) { permission = false; downloading = true } else services.openStorageSettings() }) { Text("重新检测") } })
    else if (loading || downloading) AlertDialog(onDismissRequest = {}, title = { Text(if (downloading) "下载更新" else "检查更新") }, text = { if (downloading) LinearProgressIndicator(progress) else CircularProgressIndicator() }, confirmButton = { TextButton(onClose) { Text("取消") } })
    else if (update == null || !isNewer(update!!.version, CURRENT_VERSION)) LaunchedEffect(Unit) { onClose() }
    else {
        val context = LocalContext.current
        AlertDialog(
            onDismissRequest = onClose,
            title = { Text("发现新版本 v${update!!.version}") },
            text = {
                Column {
                    Text(update!!.log.ifBlank { "暂无更新日志" })
                    TextButton({ openUrl(context, MIRROR_PAGE) }) { Text("Mirror酱高速下载") }
                    TextButton({ openUrl(context, update!!.githubUrl) }) { Text("浏览器下载") }
                }
            },
            dismissButton = { TextButton(onClose) { Text("稍后") } },
            confirmButton = {
                Button({
                    val url = update?.apkUrl
                    if (url != null && !services.hasStoragePermission()) {
                        services.openStorageSettings()
                        permission = true
                    } else if (url != null) {
                        downloading = true
                        scope.launch {
                            try {
                                val file = downloadApk(services, url, "zexnote-${update!!.version}.apk") { progress = it }
                                if (services.verifyApkSignature(file)) services.installApk(file) else downloading = false
                            } catch (_: Exception) { downloading = false }
                        }
                    }
                }) { Text("应用内更新") }
            },
        )
    }
}

private fun isNewer(left: String, right: String): Boolean { val a = left.removePrefix("v").split(".").mapNotNull { it.toIntOrNull() }; val b = right.removePrefix("v").split(".").mapNotNull { it.toIntOrNull() }; return (0..2).any { (a.getOrNull(it) ?: 0) > (b.getOrNull(it) ?: 0) } }

@Composable
private fun DownloadDialogCompose(services: AppServices, app: RecommendedApp, onClose: () -> Unit) {
    var permission by remember { mutableStateOf(false) }; var downloading by remember { mutableStateOf(false) }; var progress by remember { mutableStateOf(0f) }; val scope = rememberCoroutineScope(); fun start() { scope.launch { if (!services.hasStoragePermission()) { services.openStorageSettings(); permission = true; return@launch }; downloading = true; try { val file = downloadApk(services, app.url, "${app.name.lowercase(Locale.US)}-${app.version}.apk") { progress = it }; if (services.verifyApkSignature(file)) services.installApk(file); downloading = false } catch (_: Exception) { downloading = false } } }; LaunchedEffect(Unit) { start() }
    if (permission) AlertDialog(onDismissRequest = {}, title = { Text("需要存储权限") }, text = { Text("请先开启存储权限，返回后点击重新检测继续下载。") }, dismissButton = { TextButton({ permission = false }) { Text("取消") } }, confirmButton = { Button({ if (services.hasStoragePermission()) { permission = false; start() } else services.openStorageSettings() }) { Text("重新检测") } })
    else if (downloading) AlertDialog(onDismissRequest = {}, title = { Text("下载 ${app.name}") }, text = { LinearProgressIndicator(progress) }, confirmButton = { TextButton(onClose) { Text("取消") } })
}
