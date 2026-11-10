# 非协同编辑器与预览迁移核对

2026-11-10。对照本机 `cses_document_collab` 的 `74c325f` 与 `cses_editor` 的 `d4f50a3` 及当前工作区。范围包括根包、可操作的示例入口和独立接入模板。协同同步、远端修订、协同锁、登录、云文档列表和创建流程不计入差距。本文只记录核对结果。

## 核对结果

核心离线编辑与只读渲染已迁入，原项目的完整非协同用户流程仍有缺口。

| 功能 | 当前状态 | 核对依据 |
|---|---|---|
| 通用正文编辑 | 本地会话、选区、输入、剪贴板、撤销/重做、格式、快捷工具栏和按实例配置均保留。两边 `EditorBlock` 的 30 项声明与默认正文渲染器注册键一致，包含分栏、文本框、表格、媒体、公式、Mermaid、人员/日期/天气卡片和业务引用。 | 两边的 `core/editor_configuration.dart`、`document_editor_view.dart` 与 `local_editor_controller.dart`。默认成果导向是业务预设，只开放段落、标题和三类列表。 |
| 通用只读渲染 | `DocumentEditorView(preview: true)` 会关闭编辑、选区和快捷操作。桌面快照渲染器、根样式及 JSON 编解码仍有公开入口。 | [视图](../../../lib/src/editor/document_editor_view.dart)、[公开入口](../../../lib/cses_editor.dart)。独立快照和编辑/预览导航由宿主装配。 |
| 独立本地编辑及模板预览 | 原示例的“开始离线编辑”入口、通用正文的独立模板预览页、模板切换、预览返回编辑时恢复选区没有对应流程。独立接入模板提供通用编辑、文件保存与重开，页面未接预览。 | 原 `example/lib/src/demo/collab_demo_page.dart`、`example/lib/src/image_composer/`。对照[新示例首页](../../../example/lib/main.dart)和[独立接入模板](../../integration_app/lib/main.dart)。 |
| 成果导向编辑与预览 | 业务栏目、封面、横线、提及、保存后只读预览、从预览打开编辑和长图分享均有实现。默认成果导向/工作成果记录在示例进程内保存，重启后新建空白；原离线日记入口从应用私有文件重开。新项目的公司模板入口和独立接入模板仍使用本地文件。 | 原 `collab_demo_page.dart` 的 `_openLocalJournal`。对照[新示例首页](../../../example/lib/main.dart)、[导向页面](../../../example/lib/daily_guidance/local_journal_page.dart)和[分享页](../../../example/lib/daily_guidance/journal_share_page.dart)。 |
| 用户操作桌面 JSON | 原日记“打开桌面 JSON / 导出桌面 JSON”菜单和导入后的独立路由在当前示例缺失。转换、文件端口和独立存储实现仍在，页面没有调用入口。 | 原 `example/lib/src/daily_guidance/local_journal_page.dart`。对照[文件端口](../../../example/lib/daily_guidance/journal_json_files.dart)、[业务控制器](../../../example/lib/daily_guidance/local_journal_controller.dart)及[当前页面](../../../example/lib/daily_guidance/local_journal_page.dart)。 |
| Markdown 文件导入 | 原通用文档页从宿主选取文件、解码并追加到文末。离线包没有文件导入命令或解析器，保留正文输入的 Markdown 快捷转换。 | 原 `collaborative_editor_page.dart` 的 `_importMarkdown`、`markdown_import.dart` 和示例文件选择器。 |
| 通用文档头尾 | 原通用文档页可按宿主能力改标题、图标、封面和封面位置，并接通点赞成员、计数、全文评论。新包保留元数据模型、互动端口和可注入的 header/footer 槽位。原头尾组件与控制器缺失，成果导向有专用封面和会话内演示点赞。 | 原 `document_header.dart`、`document_feedback_footer.dart` 与关联控制器。对照[宿主契约](../../../lib/src/model/collab_host_services.dart)和[视图](../../../lib/src/editor/document_editor_view.dart)。 |
| 依赖外部数据的块 | 任务、会议、KR、天气、上传等保留宿主注入能力。实际业务接口需要消费者提供，网络嵌入和未缓存资源仍可能需要联网。 | [宿主契约](../../../lib/src/model/collab_host_services.dart)、[接入说明](../../integration.md)。 |

Markdown 文件导入和通用文档头尾原先挂在协同文档页上，表中单列的是其可以由离线宿主复用的编辑与展示功能。仅以原项目的两个离线示例入口为基线，独立模板预览、日记桌面 JSON 菜单和默认文件重开行为已经构成可确认的差异。

## 验证

- 根包 `flutter test --no-pub --reporter expanded` 通过 89 项。
- 从原项目的 `test/offline_all_blocks_test.dart` 提取纯本地场景，替换包导入后在新根包临时运行，18 项通过。覆盖 16 类块插入与撤销/重做、表格单元格粘贴及锁字段拒绝、通过工具栏插表并切换独立只读快照。依赖原全局运行时的两个隔离用例未纳入此次对照。[测试日志](legacy-offline-tests.log)
- 示例同命令通过 294 项、失败 6 项。失败是自定义都来帮确认 1 项、导向记录字段及提及 3 项、H1–H6 预览与重开 2 项，与[前次归档](../appflowy-fork-20261110/report.md)一致。
- `python3 tool/verify_independence.py` 通过，根包和示例锁定到发布包 `applowy_editor_fork 6.2.1`。
- 本轮核对针对本机两份移动端实现，未修改块协议。没有逐种高级块、网络媒体或平台插件做真机对比。
