# ZexNote

一款基于 Jetpack Compose + Material 3 开发的本地便签 Android 应用。

## 软件特点

- Material 3 界面与系统深色模式
- Android 12+ 动态颜色（Material You）
- 可选主题颜色预设与滑块自定义
- 原生 Compose 导航和页面过渡动画
- 悬浮底部导航栏，支持独立毛玻璃开关
- 本地笔记增删改查、归档、批量选择和批量删除
- TXT 文件导出
- GitHub Releases API + Atom 双通道更新检测
- Mirror 酱版本检查和浏览器高速下载入口
- 应用内 APK 下载、存储权限循环检测、签名校验和系统安装
- Contributors API 贡献者列表
- 推荐应用和独立下载弹窗

## 设备支持

- CPU 架构：**仅 ARM64（arm64-v8a）**
- Android 9（API 28）及以上
- compileSdk / targetSdk：36

## 更新系统

1. 优先检查 GitHub Releases API，失败时回退 Releases Atom。
2. Mirror 酱用于检查版本和打开浏览器项目页，不作为应用内下载源。
3. 应用内更新始终下载 GitHub APK，并在安装前校验 APK 签名。
4. 下载前检查存储权限，未授权时进入系统设置；返回后必须点击“重新检测”才能继续。
5. Mirror 酱 RID 通过 GitHub Actions Secret `MIRROR_RES_ID` 注入。

## 构建

项目使用原生 Android Gradle 构建，不再依赖 Flutter SDK、Dart 或 pubspec。

```bash
gradle -p android assembleRelease
```

Release 构建由 GitHub Actions 完成，流程包括：

- 原生 Compose Release 编译
- JKS APK 签名和 `apksigner verify`
- SSH 签名版本 Tag 创建与推送
- GitHub Release 发布
- Mirror 酱工作流触发

## 版本

每次发布同步修改：

- `android/app/build.gradle` 中的 `versionName` / `versionCode`
- CI 自动读取的版本配置

## 许可证

本项目采用自定义开源许可协议，详见 `LICENSE`。

## 赞助

赞助说明和赞赏码位于 GitHub README 页面底部。
