# HAUT BOX

> 河南工业大学校园助手 —— 课表 / 考试 / 成绩 / 校园网自动认证，一个 App 全包。
> 毛玻璃界面，纯 Flutter，只支持 Android。

<p align="center">
  <img src="docs/assets/icon.png" width="120" alt="HAUT BOX">
</p>

<p align="center">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-2F6BFF.svg"></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-Android%208.0%2B-3DDC84.svg">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.50-54C5F8.svg">
  <a href="https://github.com/Daynight2U/haut-box/releases"><img alt="Release" src="https://img.shields.io/github/v/release/Daynight2U/haut-box"></a>
</p>

---

## 它解决什么问题

学校教务系统在手机上是一场灾难：课表要横着看、成绩要点三次、校园网每次连 WiFi 都要重新登录。
HAUT BOX 把这些事一次性做完，顺手给你放一个「下一节课」到桌面上。

**非官方项目**，数据全部来自学校公开网页接口，账号密码只在本机提交给学校服务器。

## 功能

| | 说明 |
|---|---|
| 🗓 **课表** | 一屏显示整天、左右滑动换周、周次下拉跳转、单双周 / 连堂 / 撞课并排、学期切换 |
| 📝 **成绩** | 按学期分开存，可切往年 / 看全部；绩点学分汇总 |
| 📅 **考试** | 按时间排序、倒计时、考场座位 |
| 📶 **校园网** | 深澜 srun 自动认证，连上 WiFi 静默登录，不用再开浏览器 |
| 🧩 **桌面小组件** | 2×2「下一节课」带倒计时、4×2「今日课表」 |
| 🪟 **毛玻璃界面** | 四档模糊强度，中端机可降级 |
| 📴 **离线可读** | 缓存优先秒开 + TTL 控频，断网看昨天的课表 |

## 安装

到 [Releases](https://github.com/Daynight2U/haut-box/releases) 下载最新 APK 直接安装。

| 包 | 体积 | 给谁用 |
|---|---|---|
| `arm64-v8a` | **17 MB** | 绝大多数手机（2017 年后基本都是） |
| `armeabi-v7a` | 15 MB | 老 32 位机型 |
| `universal` | 49 MB | 不确定架构时兜底 |

> 体积差在哪：`universal` 把三个 CPU 架构的 Flutter 引擎各塞了一份，98% 的体积是引擎，
> 业务代码只有 5 MB。不确定就装 universal，确定就装 arm64。


- 需要 Android 8.0（API 26）及以上
- 首次登录：学号 + **教务系统密码**（不是统一认证密码）
- Release 包用调试证书签名，仅用于个人安装，不用于上架

## 从源码构建

```bash
git clone https://github.com/Daynight2U/haut-box.git
cd haut-box
flutter pub get
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

环境：Flutter 3.50+ / JDK 17 / Android SDK 36。

> 国内网络建议设好镜像，否则 `pub get` 会很慢：
> ```bash
> export PUB_HOSTED_URL=https://pub.flutter-io.cn
> export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
> ```

### 两个构建陷阱

1. **不要声明 `ndkVersion`**。本项目没有 C/C++ 代码，声明了 AGP 会去下一 GB 的 NDK，国内基本卡死。
2. **`shared_preferences_android` / `path_provider_android` 在 `pubspec.yaml` 里被钉在旧版本**。
   新版本改用 jni（Dart FFI），编译时强制要求 NDK + CMake。如果你装好了 NDK，可以删掉那两行 `dependency_overrides`。

## 项目结构

```
lib/
├── app/          MaterialApp + 全局状态（单例 ChangeNotifier）
├── core/         登录握手 / RSA / HTTP / 校历 / 缓存 / 小组件桥 / 主题
├── data/         接口层（网络 + 原始报文 + 宽松解析）、模型、演示数据
├── ui/glass/     毛玻璃组件库
└── features/     按功能分包：login schedule exam grade more wifi settings

android/app/src/main/kotlin/cn/edu/haut/hautbox/
├── WifiAuthService.kt   校园网守护（前台服务，原生认证）
├── PortalProbe.kt       认证网关自动识别
├── SrunAuth.kt          深澜加密算法
└── widget/              桌面小组件（RemoteViews 渲染）
```

设计取舍写在 [docs/02-架构说明.md](docs/02-架构说明.md)，接口细节在 [docs/01-接口说明.md](docs/01-接口说明.md)。

## 几个实现上的决定

**认证放原生，不放 Flutter。** App 进程被系统回收后 Dart 虚拟机就没了，认证跟着停。
现在 Kotlin 前台服务独立运行，`START_STICKY` + 开机自启 + 网络回调驱动，平时零轮询。

**小组件只读快照。** App 拿到课表后写一份 JSON 到本地，原生读它渲染。
组件不联网、不启动 Flutter 引擎，刷新一次几毫秒。

**接口层原始报文一定落盘。** 学校升级正方、字段改名时，能直接对比前后报文排查，
而且能靠旧缓存继续显示，不至于白屏。

## 已知限制

- 只能查**当前学期**的课表；往年只有成绩
- 校园网认证目前只验证过河南工业大学莲花街校区的 srun 网关，
  其他部署可能需要额外的 `info`/`chksum` 参数（如遇到欢迎 PR）
- 国产 ROM（MIUI / OriginOS / ColorOS）需要手动把 App 加进「自启动」和「后台无限制」，
  否则定时刷新会被冻结 —— 这是系统策略，代码绕不过

## 免责声明

本项目为个人学习作品，**与河南工业大学无任何隶属关系**。
使用本工具产生的任何后果由使用者自行承担。请勿用于爬取他人数据或任何商业用途。

## License

[MIT](LICENSE) © 2026 Daynight2U
