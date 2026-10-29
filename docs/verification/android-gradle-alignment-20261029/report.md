# Android 构建版本对齐

日期：2026-10-29。参考本机 `workspace/cses/cses.jqdl/android` 的配置，按用户确认将 example 宿主的 AGP 和 Gradle 一并对齐。

| 配置 | 修改前 | 修改后（与参考项目一致） |
|---|---|---|
| Android Gradle Plugin | 9.0.1 | 8.13.2 |
| Gradle wrapper | 9.1.0-all | 8.14.5-bin |
| Kotlin Gradle Plugin | 2.3.20 | 2.3.20（保持） |

app 显式应用 `org.jetbrains.kotlin.android`，使 AGP 8 使用已声明的 KGP。保留原有 Java/Kotlin JVM 17 目标及 Flutter 配置。本轮不复制参考项目的业务插件、仓库或依赖，不修改参考项目、第三方插件或依赖缓存。

## 验证

- [Gradle wrapper 实际版本](gradle-version.txt)：8.14.5。日志中的 Kotlin 2.0.21 是 Gradle 自身内嵌版本，应用 KGP 的声明仍为 2.3.20。
- [宿主静态分析](example-analysis.txt)：`flutter analyze --no-pub`，无问题。
- [键盘相关回归](keyboard-tests.txt)：`flutter test --no-pub test/daily_guidance/journal_keyboard_toolbar_test.dart`，14 项通过。
- [Android Debug 构建](android-build.txt)：`flutter build apk --debug --no-pub` 成功，耗时 86.2 秒；不再出现 `keyboard_height_plugin` 的 KGP 迁移警告。仍有 Android SDK 工具 XML 版本提示，不影响本轮构建。
- `git diff --check` 通过（涵盖当前工作区已有修改）。

本轮未改动 Dart 声明、公共 API 或块协议；不新增真机和 iOS 验收。
