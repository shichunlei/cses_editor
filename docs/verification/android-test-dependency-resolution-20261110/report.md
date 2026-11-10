# Android 集成测试依赖解析与 Debug 构建

Flutter 3.44.9 的 `integration_test` 声明了三项动态版本。解析 `androidx.test:runner:1.2+` 时，Gradle 请求 Google Maven 版本列表，TLS 握手中断。修复前的离线依赖报告也显示该动态请求解析失败，而 Espresso 的传递依赖已选中 Runner 1.3.0。

example 的 Android 构建将 `:integration_test` 和 `:app` 中对应的动态请求分别替换为 Runner 1.3.0、Rules 1.2.0 和 Espresso Core 3.3.0，沿用原依赖图中的实际版本。首次构建仍需要能下载本机缓存中缺失的依赖。

## 验证结果

- 使用 JDK 21 和 Gradle 8.14.5 离线检查 `:integration_test:debugCompileClasspath` 与 `:app:debugRuntimeClasspath`，两者均解析到上述三个固定版本。
- `./gradlew --offline :integration_test:compileDebugJavaWithJavac :app:assembleDebug` 成功并生成 Debug APK。
- `flutter build apk --debug --no-pub` 使用 JDK 21 成功，耗时 41.6 秒，产物位于 `example/build/app/outputs/flutter-apk/app-debug.apk`。
- `flutter analyze --no-pub` 通过。
- example 的 `flutter test --no-pub` 共 294 项通过、6 项失败。用修改前的提交和同一份依赖锁文件在临时目录复跑对应的三个测试文件，复现全部 6 项失败，分别涉及导向条目布局、记录字段及两种屏幕尺寸下的标题格式。
- `git diff --check` 通过。
