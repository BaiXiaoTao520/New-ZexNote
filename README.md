# ZexNote
一款简洁精致的本地便签APP，基于 Flutter + Material3 开发

## ✨ 软件特点
- 主题：跟随系统浅色/深色夜间模式自动切换；Android12+ 支持 Material You 壁纸动态取色
- 底部小型悬浮胶囊导航栏，页面切换带有平滑滑动指示器动画
- 完全本地存储笔记，基础便签功能：新建、编辑、删除、归档笔记
- 支持笔记批量操作（多选批量删除、批量归档）
- 笔记 JSON 备份与恢复，方便导出导入保存数据

## 📱 设备支持
- CPU架构：**仅ARM64（arm64-v8a）**，不支持32位arm、x86架构
- 安卓版本：Android 9.0 (API 28) 及以上（已适配 Android 9–16）

## 🔄 双通道版本更新系统
1. **双通道检测版本**：优先 GitHub Releases API，遇到IP限流自动切换 Releases Atom 订阅源，规避访问频控
2. 可选 Mirror酱高速下载源，Mirror 酱项目页仅通过浏览器打开，接口异常自动回退 GitHub 直连
3. 应用内下载 APK 仅使用 GitHub 直连，带有平滑进度条，实时展示已下载/总文件大小
4. Mirror 酱 RID 不写入源码，通过 GitHub Actions Secrets 的 `MIRROR_RES_ID` 注入
5. 更新弹窗内置可滑动日志小窗口，记录下载全过程日志
6. 更新弹窗选项：浏览器下载｜稍后｜重试，弹窗自带升级图标
7. 设置页「关于」板块：
   - 开关：启动时自动检查更新
   - 按钮：手动检查新版本
8. 安全校验：应用内下载完成后校验 APK 签名，签名不一致拦截安装，防止恶意篡改包

## 📦 构建说明
- 使用 GitHub Actions 云端远程编译打包APK
- 云端自动使用JKS密钥签名，输出已签名APK
- 构建成功自动发布 GitHub Release，自动标记为 Latest 最新版本
- 用户下载直接安装，无需手动签名，新版本可覆盖升级

## 🎨 应用图标
- 源图标文件：`assets/images/app_icon.png`
- 桌面图标需要生成全套mipmap尺寸，替换 `android/app/src/main/res/mipmap-*/` 目录下的图标文件

## 📱 权限说明
- `INTERNET`：用于版本检测、下载更新包
- 存储权限：保存下载的APK、笔记备份文件
- `REQUEST_INSTALL_PACKAGES`：下载完成后唤起系统安装器

## ⚠️ 使用须知
1. 本软件为本地便签工具，所有笔记默认保存在手机本地，建议定期备份
2. 每次发布新版本，**同步修改两处版本号**
   - `pubspec.yaml` 的 version
   - `lib/main.dart` 内 `currentVersion`
3. 升级必须使用**同一签名密钥**打包，否则无法覆盖安装
4. 仅支持ARM64架构安卓设备

## 📄 开源协议
本项目采用自定义开源许可协议，详见 `LICENSE` 文件

## ☕ 赞助作者
如果这个项目对你有帮助，请请我喝杯咖啡支持开发喵～
<img width="1213" height="1213" alt="Image" src="https://github.com/user-attachments/assets/f73bb41f-da30-4615-8daf-857ea9ffb5b9" />

## 💌 反馈通道
1.Github Issues
2.入群反馈: [ZexNote用户交流群](https://qun.qq.com/universal-share/share?ac=1&authKey=DvOhQf0Uucy%2F7IFpHx76%2BD5wkEsbW4V12oPGNvlDcicpXItL6TlC9NxdLPWkJsE9&busi_data=eyJncm91cENvZGUiOiI2NzgxOTY0ODEiLCJ0b2tlbiI6IkhCRHVFR29mdzRocGFIbWg1UG90aUZFSXVMS3d4d2E3VzRuTHE2MzFDQU1rWnFJek5yL1pvTjhBcTJ5WTZrV0EiLCJ1aW4iOiIxNTM3NTE1MjU2In0%3D&data=PyYzqo4qiuTJguxnLkHCxXGzHPn-rRlbIXH3cj1jJCRxt7YVPStCzAlWPnbXra310f3dk3dDmgAMOdaZOqs2qg&svctype=4&tempid=h5_group_info)
