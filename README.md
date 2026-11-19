# CSES 离线编辑器

独立 Flutter 编辑器包 `cses_editor`，包根目录下带 `example/`。成果导向位于示例 App 的业务层，只将通用编辑能力封装成包。
本项目不依赖原协同工程、Common 账号 SDK、Rust、FRB、Yrs 或 SQLite 插件。

```text
lib/                       通用编辑会话、视图、工具栏、渲染与扩展契约
assets/                    编辑器资源
test/                      通用编辑器回归
pubspec.yaml               根包 cses_editor 的依赖声明
example/lib/daily_guidance/ 成果导向页面、栏目、草稿和业务转换
example/                   可独立安装的 Android/iOS 示例宿主
```

需要 Flutter >=3.44.0、Dart >=3.12.0；本轮使用 Flutter 3.44.9 / Dart 3.12.2。

## 运行

```sh
# 在 cses_editor/ 根目录
flutter pub get
flutter test
cd example
flutter pub get
flutter run
```

示例在 `example/pubspec.yaml` 中通过 `cses_editor: {path: ..}` 引用根包。

首页先选择“成果导向”或“工作成果”，再进入“编辑”或“预览”。首次打开对应类型时，宿主调用 `createEmptyGuidanceRecord(DateTime.now(), orientType: 'ORIENT')`（成果传 `RESULT`），按设备本地当天创建空白 JSON，仅含一个空白正文栏目，不读取或打包样例 JSON。两类记录在本次启动中分别保留，切换不会覆盖已保存正文。`orientType` 的 ORIENT/RESULT 分别显示“成果导向”/“工作成果”，只将 `bodyContent` 适配进当前横格记事本，保留现有键盘和自定义菜单。
头部提供显式“保存”，提交完整记录及正文派生业务字段，成功后当前页进入只读预览，可继续分享。mock 数据在当前首页实例中保留，重开恢复已保存内容，重启应用重新创建当天空文档；选人使用虚构人员。真实接入由宿主实现服务端口并注入客户端。
预览采用沉浸式封面，可生成包含米色品牌页脚的完整分享图片，并通过宿主图片端口交给微信、朋友圈或系统文件保存。分享图片包含头尾后至少为设备一屏高度，短正文在末栏目补齐横格并将品牌页脚放在底部，长正文完整导出。编辑与预览共用紧凑栏目间距，保留编辑输入和原键盘菜单。
实际业务账号、人员、任务/会议/KR详情、天气与媒体上传由接入方注入，示例不伪造在线服务成功。
已加载网络图片使用无数据库的App私有文件缓存，可跨进程离线读取。

## 接入与验证

- [其他App完整接入说明](docs/integration.md)：引入、初始化、离线保存和宿主注入
- [可复制的独立宿主模板](docs/integration_app/README.md)：不依赖example的完整源码与测试
- [数据格式](docs/data-format.md)
- [来源及维护边界](docs/source.md)
- [块兼容与版本跟踪](docs/block-adaptation.md)
- [验证索引](docs/verification/README.md)
- [2026-10-29复审与修复](docs/verification/offline-review-20261029/report.md)

```sh
python3 tool/verify_independence.py
# 同时检查构建产物
python3 tool/verify_independence.py example/build/app/outputs/flutter-apk/app-debug.apk
```

保留部分 `Collab*` Dart 类型名以减少迁移造成的数据与调用差异；这些名称不代表本包包含协同引擎。
文件选择、视频、WebView等能力仍使用普通 Flutter 平台插件。
编辑器依赖使用 pub.dev 发布的 [`applowy_editor_fork`](https://pub.dev/packages/applowy_editor_fork)，版本约束为 `^6.2.1`。

示例在宿主层通过 `createDemoGuidanceHostServices` 注入用户头像，普通 @、都来帮、领航员及旧用户引用共用头像槽。可传入用户 ID 到头像 URL 的映射；未提供图片时显示离线姓名首字头像，不向正文 JSON 写入头像展示数据。任务引用图标与样式保持原样。


## 嵌入只读正文

`DocumentEditorView(embeddedPreview: true, preview: true)` 按内容自然高度渲染全部块，适用于外层统一滚动的模板画布、测量与整幅截图。该模式复用块构建器与只读交互规则，不创建 Overlay、内部滚动、键盘或选区服务。默认 `embeddedPreview: false` 保持原独立编辑视图行为。

宿主必须提供独立只读会话，配置自身事务权限；测量和可见正文不得共享同一个 EditorState、节点 Key 或 renderer。视图不接管控制器，不发起保存，卸载后由创建者等待关闭。只读媒体交互按现有参数显式开启，测量与静态截图应保持关闭；异步资源加载与截图就绪由宿主协调。

```dart
import 'package:flutter/material.dart';
import 'package:cses_editor/cses_editor.dart';

final controller = DocumentEditorController();
controller.editorState
  ..editable = false
  ..transactionGuard = (_) => false;
final body = DocumentEditorView(
  editorState: controller.editorState,
  preview: true,
  embeddedPreview: true,
);
// 将 body 放入外层画布；从组件树卸载后 await controller.close()。
```

### 嵌入预览的资源就绪

`EditorResourceScope(tracker: tracker, staticMedia: true, child: view)` 可为测量或截图观察原图片加载器的真实状态。宿主各自创建测量、可见画布的 `EditorResourceTracker`，卸载正文后 dispose；空资源集合就绪，图片须完成真实解码/绘制，失败不能放行。状态同步登记，通知合并至帧后，不修改文档、替换缓存或拥有宿主保存服务。使用 `failed` 显示原因、`value` 等待资源，截图仍需等待宿主实际布局收敛。

静态模式下视频只展示原 poster（无封面时为静态卡），音频只展示静态卡，不初始化播放器。普通编辑默认 false，沿用原播放行为；作用域切换时视频播放器按创建者所有权释放。data 图片继续后台解码，HTTP 图片及 SVG 继续原缓存加载器，读取到字节不等于可截图。宿主应使用公开 `cses_editor.dart` 的 Scope/Tracker/Status，不依赖内部观测 Widget。
