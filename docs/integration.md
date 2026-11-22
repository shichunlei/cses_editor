# 其他 App 接入 cses_editor

接入 App 只引用仓库根包 `cses_editor`，无需依赖或运行 `example/`。成果导向是宿主业务源码，不是核心包 API。包不初始化协同引擎、Common 账号 SDK、Rust/FRB/Yrs 或协同数据库。

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
  applowy_editor_fork: ^6.2.1
  path_provider: ^2.1.6
  crypto: ^3.0.7
  dio: ^5.11.1
```

`cses_editor` 的 path 指向根包，不指向 `example` 或旧的 `packages` 目录。宿主直接使用 `Document`、`EditorState` 或本地化 delegate，所以也声明 `applowy_editor_fork: ^6.2.1`，并从 `package:applowy_editor_fork/applowy_editor_fork.dart` 导入。`path_provider`/`crypto`用于本文宿主文件保存模板，`dio`用于上传适配器的取消信号；只接入内存编辑且未导入这些 API 时不必逐项添加。

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

上面仅展示层级；可读文档须有至少一个正文节点。该格式是本模板自定义的 v1 文件格式，与成果导向 `JournalDraft` 的 v2、桌面JSON均不同。不要混用版本字段或直接删除 `cses_`/`bc.`等已有数据属性。

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
| 人员/任务/会议/文档详情 | `onMentionTap`、`onMeetingMentionTap`、`onTaskMentionTap` | 编辑态保留引用操作面板；显式启用的只读预览直接派发会议、任务和人员，宿主提供详情导航 |
| 任务卡片数据 | `loadTaskCard` | 返回与请求ID相符的 `CollabTaskCardData`；不存在返回null，失败抛错；模板只识别本地演示任务 |
| 会议、KR、天气、人员卡片 | `pickMeetingReference`、`createMeetingFromText`、`onMeetingMentionTap`、`loadMeetingCard`、`onMeetingCardTap`、`kr`、`loadWeather`、`loadPersonCardCreator` | 可选；宿主提供真实业务服务或本地缓存 |

移动正文允许行内引用时，配置 `createMeetingFromText` 及会议详情回调可启用「创建会议」。发布页使用传入标题预填，提交前检查借用的 `canEdit`，完整退场后返回带稳定 ID 和标题的 `CollabMeetingReference`。正文将单段选区替换为已有协议的会议引用，一次撤销恢复原文。会议发布由宿主负责，引用随文档保存，详情优先派发 `onMeetingMentionTap`。
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

## 6. 成果导向与其他平台能力

普通编辑接入到这里即可完成。若App还要成果导向栏目、日期、封面、领航员/都来帮及日记工作流，它们属于宿主业务：迁入 `example/lib/daily_guidance/`、对应业务测试及封面资源，调整包名和宿主直接依赖。迁入后是宿主源码，不把 `cses_offline_example`当成运行时依赖，也不将该业务回填核心包。

成果导向专用入口 `LocalJournalPage`的 `store`、`storageScope`、`sessionIdentity`、`mentionDirectory`、`hostServices`由宿主稳定注入；单草稿只打开一个活动页面，身份变化后旧页永久冻结，改分区必须重建路由。示例通过 `ApiJournalStore(api: api, recordId: id)` 使用固定记录身份的 `GuidanceApi`，页面自动选择显式服务保存模式。真实接入实现 `fetch` 和 `save`，客户端认证与释放由宿主负责。`fetch` 返回与 `example/文档完整数据结构.json` 同结构的完整记录；`save(recordId, record)` 接收完整记录。适配器从最新 bodyContent 重算 thinking、selfCheck、helpItems、navigatorItems、customData（含人员及任务 mentions），其余业务字段与扩展字段保留读取值，并在同一请求内提交。宿主实现若此前仅发送 bodyContent 补丁，需改为发送完整 record。存储实例须在路由 builder 外创建并保持稳定。该业务页的存储与转换契约见[数据格式](data-format.md)。

文件目录、WebView、视频、URL打开等仍会使用普通Flutter平台插件，“不带协同原生库”不等于没有任何平台插件。宿主启用网络/媒体能力时按Android/iOS目标配置正常的平台权限和能力；正文离线编辑与本文私有文件保存不需要外部存储权限或协同服务。

网络图片/SVG使用App私有文件缓存，无SQLite；类型识别先检查文件起始内容，PNG/JPEG 等二进制文件中的 C2PA/EXIF SVG 元数据不作为 SVG 根文档，真实 SVG 允许 UTF-8 BOM、空白和 XML 声明，位图交由原生解码器。默认最多200张/128MiB，30天尝试刷新，断网可回退旧缓存。未加载或已被系统清理的远程资源仍需网络，不保证所有外链媒体离线可用。通用资源和生成数据已随包提供，普通构建不要求桌面工程、Node或重新生成目录。


成果导向路由使用 `LocalJournalPage(store: store, mode: JournalPageMode.edit)` 或 `mode: JournalPageMode.preview`。模式默认 edit 兼容既有调用；首页显式传入模式。当前路由不接受编辑/预览切换，改变 mode 必须创建新路由，否则旧会话冻结。预览会话在控制器层固定 readOnly，隐藏保存、撤销/重做、栏目关闭、日期修改及键盘编辑操作，加载、切后台、返回和销毁均不提交数据。两个入口可读取同一服务记录，存储实例仍由宿主持有。

头像继续使用公开 `CollabHostServices.mentionAvatarBuilder` 注入。example 提供 `createDemoGuidanceHostServices(avatarUrls: {...})` 演示按用户 ID 注入图片地址，映射创建时复制，无地址/加载失败使用姓名首字。服务实例由首页持有，进入编辑和预览时稳定传入；核心编辑器不拼接用户图片地址、不查询全局账号。真实宿主可替换为自己的头像 Widget、缓存和鉴权实现。

成果导向预览页底部提供固定悬浮分享与点赞按钮。分享从独立只读快照生成完整 PNG，包含封面、用户信息、正文和米色品牌页脚；可查看长图并选择微信、朋友圈或系统文件保存。`LocalJournalPage.imageActions` 支持宿主注入；默认 Android 通过临时文件授权交给微信，iOS 打开系统图片分享面板，返回仅表示交接结果，不代表用户已发送。点赞为本次预览内的 0/1 演示状态，不调用后端互动服务、不写入正文 JSON；重新打开页面重置点赞。正文为悬浮按钮保留可滚动底部空间，编辑页不显示该按钮组。

预览封面下方的当前用户栏由宿主显式传入 `LocalJournalPage.currentUser`（`CollabMentionUser`，包含 id、name、avatarUrl、department、position）。未传 currentUser 时隐藏整行；用户栏不显示右侧时间。头像优先使用注入的头像构建器，无头像构建器时使用 example 的姓名首字/显式图片地址展示。资料不解析 moke 顶层字段，也不写入 bodyContent。切换当前用户 ID 会冻结旧页面，须重新打开路由。

```dart
LocalJournalPage(
  store: store,
  mode: JournalPageMode.preview,
  currentUser: const CollabMentionUser(
    id: 'current-user',
    name: '当前用户',
    department: '技术部',
    position: '前端开发',
  ),
  hostServices: services,
);
```

example 首页注入虚构用户“示例小陈 / 示例团队 · 前端开发”，仅显示头像、姓名及部门职位，右侧不显示时间。编辑页不显示此栏。

编辑和预览使用相同的栏目间隔，最多两行，不额外补足三行书写区。两种模式的尾部留白均放在整篇文档 footer 中，仅出现一次，不通过根块 padding 重复加在每个栏目后。编辑保留用户实际输入的空段落、光标及回车能力；仅预览折叠栏目末尾普通空段落，正文 JSON 保留。

分享长图的品牌页脚与纸张保持米色，logo 上边距为 8px；截图时最后一个栏目不再叠加自动底部留白，让正文与品牌图片紧凑衔接，普通编辑/预览栏目间距保持原规则。


### 会议与任务图标回调

`CollabHostServices.mentionIconResolver` 为可选的 `IconData? Function(CollabMentionType type)`。只为 meeting/task 调用；未配置或返回 null 时使用库原默认图标，人员和文档不调用。编辑行内、跨行投影及编辑引用底部面板标题共用映射，颜色、尺寸、基线及换行仍由各原展示位置控制。回调应为无副作用的纯同步映射，不发请求、导航或修改正文；错误沿当前构建/交互边界传播，不静默兜底。

```dart
import 'package:flutter/material.dart';
import 'package:cses_editor/cses_editor.dart';

final services = CollabHostServices(
  mentionIconResolver: (type) => switch (type) {
    CollabMentionType.meeting => Icons.event_note,
    CollabMentionType.task => Icons.assignment,
    _ => null,
  },
);
// 将 services 交给当前文档的 EditorCommandContext；自定义字体由宿主声明和加载。
```

`withMentionUserPicker` 创建服务视图时保留原回调；宿主另外构造测量、预览或静态分享服务时也须透传它，不依靠正文数据携带图标。测量只配置展示端口，截图禁止导航但保留图标。回调不接收账号或业务对象、不序列化进 JSON，不改变引用 ID、名称、选区或原子协议。现有会议/任务卡片的其他图标不受此行内接口影响。

回归及消费者记录见 [图标回调验收](verification/mention-icon-resolver-20261122/report.md)。

### 可见预览的行内引用详情

会议与任务行内引用共用无底色蓝字，保留会议/剪贴板图标及正文的字号、字重和删除线，按正文前景亮度选择深蓝或浅蓝。标题完整显示，随段落剩余空间自然换行，不使用单行省略。编辑、普通预览、自然高度预览和静态分享图使用同一显示投影；正文仍保存单个引用原子，UTF-16 选区、光标、删除及撤销通过原子映射处理。同段多个会议和任务引用分别命中对应 ID，显示换行不改变协议或原属性。

实体引用底部操作面板（会议、任务、文档）的标题最多显示一行，超出可用宽度以省略号展示；空名称保留“未命名＋类型”兜底。图标、副标题和关闭入口沿用原面板，详情回调携带完整名称及原 ID，显示截断不改写正文，也不限制正文中引用标题的自然换行。

`DocumentEditorView(preview: true, previewMentionInteractions: true)` 显式允许会议、任务及人员引用直接通知宿主；默认关闭。会议与任务优先调用 `onMeetingMentionTap`、`onTaskMentionTap`，未配置时回退 `onMentionTap`；人员只调用 `onMentionTap`，未配置不打开默认人员页面。`CollabMentionTap` 交付稳定 ID、名称和深只读原属性，包不读取企业资料或创建业务详情页。

```dart
import 'package:cses_editor/cses_editor.dart';

final editor = DocumentEditorController(
  commandContext: EditorCommandContext(localOnly: true, services: CollabHostServices(
    onMeetingMentionTap: (mention) async { /* 宿主按 mention.id 打开会议详情并等待返回 */ },
    onTaskMentionTap: (mention) async { /* 宿主按 mention.id 打开任务详情并等待返回 */ },
    onMentionTap: (mention) async { /* 宿主处理人员 ID/名称/attributes */ },
  )),
);
editor.editorState
  ..editable = false
  ..transactionGuard = (_) => false;
final view = DocumentEditorView(
  editorState: editor.editorState, preview: true,
  embeddedPreview: true, previewMentionInteractions: true,
);
// 将 view 移出组件树后 await editor.close()。
```

该开关与编辑权限独立，返回不恢复选区或键盘，不执行块锁租约、删除或卡片转换。详情回调在同一编辑器内共享防重复锁，Future 应等待详情返回；失败交由原错误报告及宿主 showFeedback，失效页面不显示迟到提示。块内引用使用原原子定位校验，嵌套容器与人员标签的局部作用域必须透传预览配置。

`enabled: false`、`EditorResourceScope(staticMedia: true)` 及宿主关闭该开关时均不派发引用；测量/截图不能仅依赖只读事务权限阻止导航。原 `previewTaskMentionInteractions` 保持任务专用的只读操作面板行为，与新开关分开，其他文档引用不因新开关自动开放。

回归见 `test/preview_inline_mentions_test.dart` 和 `docs/verification/preview-inline-mentions-20261122/report.md`。正文协议、缓存及块类型未变化。
