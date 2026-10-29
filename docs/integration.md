# 其他 App 接入 cses_editor

接入 App 只引用仓库根包 `cses_editor`，无需依赖或运行 `example/`。今日导向是宿主业务源码，不是核心包 API。包不初始化协同引擎、Common 账号 SDK、Rust/FRB/Yrs 或协同数据库。

本文配套一份可复制的[独立宿主模板](integration_app/README.md)，代码只从 `package:cses_editor/cses_editor.dart` 和其他依赖的公开入口导入。包含完整应用初始化、正文恢复、自动保存、保存失败重试、退出释放、人员选择、头像和详情注入。模板自身不是业务依赖，应将所需源码放到接入 App 的业务目录。

## 1. 引入根包

要求 Flutter >=3.44.0、Dart >=3.12.0；支持本例文件保存流程的平台为 Android/iOS。假设两个项目平级：

```text
workspace/
├── cses_editor/       # pubspec.yaml 中 name: cses_editor
└── your_app/
```

在 `your_app/pubspec.yaml` 合并以下依赖，然后执行 `flutter pub get`：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  cses_editor:
    path: ../cses_editor
  appflowy_editor:
    git:
      url: https://github.com/shichunlei/appflowy-editor.git
      ref: 9e7593134457eac9193a61ee4023a75de55fcc68
  path_provider: ^2.1.6
  crypto: ^3.0.7
  dio: ^5.11.1
```

`cses_editor` 的 path 指向根包，不指向 `example` 或旧的 `packages` 目录。宿主直接使用 `Document`、`EditorState` 或本地化 delegate，所以也声明 `appflowy_editor`，与根包固定同一 Git 提交。`path_provider`/`crypto`用于本文宿主文件保存模板，`dio`用于上传适配器的取消信号；只接入内存编辑且未导入这些 API 时不必逐项添加。

目前根包 `publish_to: none`，本文不假定已有 pub.dev 版本或可用的 cses_editor 远程仓库地址。若团队将根包放进内部 Git 仓库，宿主可改为该仓库的 Git URL和固定提交，仓库包路径必须仍指向根 pubspec。不要用依赖覆盖把编辑器指回原协同工程。

## 2. 初始化与最小内存编辑

宿主按普通 Flutter 应用初始化，不执行 Rust 加载、FRB 初始化、账号登录或数据库打开：

将模板的三个Dart文件放在宿主 `lib/editor_host/` 后，宿主 `lib/main.dart` 可直接使用：

```dart
import 'package:flutter/material.dart';
import 'editor_host/main.dart' show HostApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HostApp());
}
```

[HostApp完整实现](integration_app/lib/main.dart)已经配置 `AppFlowyEditorLocalizations.delegate`、`GlobalMaterialLocalizations.delegates`、中文/英文Locale以及宿主路由。接入已有MaterialApp时把这些配置合并到现有应用，使用模板的会话和页面流程；不要再创建第二个MaterialApp。不会创建进程级编辑器实例。

只需要从纯文本开始编辑时：

```dart
final editor = LocalEditorController(
  initialText: '离线正文',
  configuration: EditorConfiguration.local,
  services: const CollabHostServices(),
);
final view = DocumentEditorView(editorState: editor.editorState);
// 将view从组件树中移除、等待相关路由完全退场后：
await editor.close();
```

`LocalEditorController`从纯文本创建会话并带本地事务约束，不负责文件保存。恢复完整富文本JSON时，使用下面的 `DocumentEditorController` 装配，不将 JSON 当作纯文本传给 `initialText`：

```dart
final editor = DocumentEditorController(
  document: savedDocument == null ? null : Document.fromJson(savedDocument),
  commandContext: EditorCommandContext(
    configuration: EditorConfiguration.local,
    localOnly: true,
    services: hostServices,
  ),
);
final view = DocumentEditorView(
  editorState: editor.editorState,
  onUserMention: (state) => handleEditorUserMentionTrigger(context, state),
);
```

这里的 `savedDocument`来自宿主存储，`hostServices`是本会话注入值，`context`来自当前页面。完整模板将三者串在同一个生命周期内。`EditorConfiguration.local`提供离线功能集合；`EditorViewConfiguration`用于皮肤、块展示及宿主工具栏动作。通用 `DocumentEditorController`不会自动继承 `LocalEditorController`的事务容量保护；宿主若要求强制块白名单或容量约束，应在自身数据/事务边界校验，不能把菜单配置当作外部JSON验证器。

## 3. 离线保存与重开

可直接复制的实现位于[offline_document.dart](integration_app/lib/offline_document.dart)：

```dart
import 'dart:io';
import 'package:cses_editor/cses_editor.dart';
import 'package:path_provider/path_provider.dart';
// 同时导入复制到宿主的offline_document.dart。

final directory = await getApplicationSupportDirectory();
final store = OfflineDocumentStore(
  Directory('${directory.path}/editor-drafts'),
  'tenant-1/user-1',
  'document-1',
);
final session = await OfflineDocumentSession.open(
  store,
  hostServices,
  (error, stack) { /* 接入宿主日志；页面同时显示保存错误。 */ },
);
// 页面借用：DocumentEditorView(editorState: session.editor.editorState)。
await session.flush(); // 明确等待成功；失败抛错，仍保留内存正文。
// 先卸载视图、等待路由完全退场，再由创建者释放：
await session.close();
```

模板保存完整的 `editor.editorState.document.toJson()`，包含正文、格式和嵌套块；选区、键盘及撤销栈属于会话状态，不写入文件，重开时创建新会话。文件封装为宿主自有格式：

```json
{
  "schemaVersion": 1,
  "document": {"document": {"type": "page", "children": []}}
}
```

上面仅展示层级；可读文档须有至少一个正文节点。该格式是本模板自定义的 v1 文件格式，与今日导向 `JournalDraft` 的 v2、桌面JSON均不同。不要混用版本字段或直接删除 `cses_`/`bc.`等已有数据属性。

模板的保存契约：

- 监听已完成的编辑事务，500ms去抖自动保存；写入串行化，保存期间的新修订继续写入，不把较早快照标为最新。
- 捕获时递归复制正文属性，JSON编解码和文件读写在后台执行。采用4MiB文件上限、临时文件flush及同目录rename；保存成功才清除脏状态。
- 路径按账号/企业分区和稳定文档ID联合哈希。每个文件只有一个活动写入者；不同窗口或Isolate的互斥由实际App存储层实现。
- 文件不存在才创建空白。损坏、版本不支持、正文无法恢复或读取失败会显示错误，保留原文件，不自动覆盖为空白。
- 自动保存失败显示重试提示，显式保存失败继续留在编辑页；退出前冻结新输入并等待保存成功。生命周期离开前台时额外尝试保存。
- 视图仅借用会话。入口等待 `route.completed` 后调用 `session.close()`；会话取消自己创建的监听/定时器，再等待最终保存和 `editor.close()`。不要另行dispose `editorState`。

去抖窗口内的编辑不保证在系统突然杀进程时落盘；生命周期回调也不是进程终止通知。需要更强恢复保证时，宿主可采用追加日志/更短保存间隔及业务备份策略。本文模板不提供加密、跨进程锁、Windows替换语义或浏览器存储；Web可换成宿主存储端口，不能直接使用 `dart:io` 版本。

## 4. 注入宿主能力

完整实现见[host_services.dart](integration_app/lib/host_services.dart)。服务在创建控制器时注入一次，未配置项保持空端口，不访问默认业务服务器。现有 `Collab*` 名称是兼容的 Dart 契约，不代表要安装协同原生库。

| 需求 | 公开端口 | 宿主责任与默认行为 |
|---|---|---|
| 人员选择与@ | `pickMentionUser` + `handleEditorUserMentionTrigger` | 宿主搜索、鉴权和选择路由；返回 `CollabMentionUser`，取消返回null；无端口不提供选人 |
| 头像 | `mentionAvatarBuilder` | 宿主决定图片/缓存/占位；模板使用姓名首字，不发网络请求 |
| 人员/任务/会议/文档详情 | `onMentionTap` | 按type/id派发宿主路由，并等待详情完整退场；模板展示明确的宿主详情对话框 |
| 任务卡片数据 | `loadTaskCard` | 返回与请求ID相符的 `CollabTaskCardData`；不存在返回null，失败抛错；模板只识别本地演示任务 |
| 会议、KR、天气、人员卡片 | `pickMeetingReference`、`loadMeetingCard`、`onMeetingCardTap`、`kr`、`loadWeather`、`loadPersonCardCreator` | 可选；宿主提供真实业务服务/本地缓存，未配置不会自动查询业务接口 |
| 媒体文件 | `mediaUpload` / `EditorMediaUploadService` | 宿主选文件、鉴权上传、取消、进度及失败；默认不提供本地上传，不伪造离线上传成功 |
| 错误与ID | `onError`、`createId` | 错误日志由宿主接管；ID默认安全随机生成，无需账号SDK |
| 文档业务元数据与互动 | `documentMetadata`、`showDocumentFeedback`及点赞/评论端口 | 按需显式注入，普通离线正文不需要这些端口 |

`pickMentionUser`收到的 `canEdit`是借用信号，不得保留到其他会话或dispose；确认和返回时都需检查其值以及宿主身份是否仍有效。返回的Future须等选择页面完整退场。模板演示搜索、取消、权限禁用和返回后复核，不直接修改编辑器。

媒体适配器 `HostMediaUpload`已给出完整 `pickFile`/`upload`实现，通过构造参数借用真实App的选择与上传函数。实际上传函数必须使用传入的 `CancelToken`、上报0～1进度，在上传成功后返回 `EditorMediaSource(稳定资源URL)`；失败抛错。模板默认不注入它，因此独立离线运行不需要上传服务器。选择器和HTTP客户端由宿主创建、取消并释放；编辑器不持有登录状态，也不关闭借用的客户端。

如需在键盘栏附加业务动作，可用公开展示配置：

```dart
final viewConfiguration = EditorViewConfiguration(
  keyboardActions: [
    EditorKeyboardAction(
      id: 'host-save',
      label: '保存',
      icon: Icons.save_outlined,
      onPressed: session.flush,
    ),
  ],
);
// DocumentEditorView(configuration: viewConfiguration, editorState: ...)
```

业务动作的异步结果应复核所属文档、账号和权限。实际账号场景捕获 `(companyId, userId, sessionGeneration)`；服务回调只在捕获身份仍等于宿主当前身份时使用结果。账号切换先让旧页拒绝新命令、关闭选择/详情路由并等待保存及释放，再为新分区打开页面。模板的 `active`只演示单次路由有效性，固定的 `local-demo-user`须替换为实际分区；不能拿它跨账号复用。

## 5. 从模板放入你的 App

复制 `integration_app/lib/` 的三个文件到宿主业务目录，保留其同目录import，调整入口并合并第1节依赖。宿主只通过核心包公开入口调用编辑器；不要复制 `lib/src/`，不要添加指向 `example`的依赖或import。

编辑器自身Mermaid资产由根包pubspec自动提供，不需要宿主复制 `example/assets/`。Flutter资产URI中的 `packages/cses_editor/assets/...`是包资源地址，不是磁盘路径。

模板的构建与测试命令见[模板说明](integration_app/README.md)。本轮还将根包运行文件与模板单独复制到临时目录，完全移除 `example`、原工程及其原生构建文件后解析依赖、运行检查并构建Android；证据见[接入验证记录](verification/integration-guide-20261029/report.md)。

## 6. 今日导向与其他平台能力

普通编辑接入到这里即可完成。若App还要今日导向栏目、日期、封面、领航员/都来帮及日记工作流，它们属于宿主业务：迁入 `example/lib/daily_guidance/`、对应业务测试及封面资源，调整包名和宿主直接依赖。迁入后是宿主源码，不把 `cses_offline_example`当成运行时依赖，也不将该业务回填核心包。

今日导向专用入口 `LocalJournalPage`的 `store`、`storageScope`、`sessionIdentity`、`mentionDirectory`、`hostServices`、`jsonFiles`由宿主稳定注入；单草稿只打开一个活动页面，身份变化后旧页永久冻结，改分区必须重建路由。该业务页的存储与转换契约见[数据格式](data-format.md)。

文件目录、WebView、视频、URL打开等仍会使用普通Flutter平台插件，“不带协同原生库”不等于没有任何平台插件。宿主启用网络/媒体能力时按Android/iOS目标配置正常的平台权限和能力；正文离线编辑与本文私有文件保存不需要外部存储权限或协同服务。

网络图片/SVG使用App私有文件缓存，无SQLite；默认最多200张/128MiB，30天尝试刷新，断网可回退旧缓存。未加载或已被系统清理的远程资源仍需网络，不保证所有外链媒体离线可用。通用资源和生成数据已随包提供，普通构建不要求桌面工程、Node或重新生成目录。
