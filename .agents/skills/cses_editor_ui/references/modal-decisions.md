# 本项目 UI 场景与验证定位

修改具体入口、核对默认样式或选择目标回归时读取。路径均相对本仓库根目录；数值用于理解既有实现，应复用组件而非复制常量建立第二套主题。

## 公共组件设计基线

公共目录 `lib/src/ui/modal/`；路由、外壳、主题、颜色、标题、操作区、字段、分段、菜单/开关行各自独立文件。`collab_modal.dart` 不聚合导出组件；宿主跨包边界见主 skill。

| 项目 | 当前实现基线 |
|---|---|
| 主色/浅底 | 亮色 `#6558D9` / `#F0EDFF`；暗色 `#B0A5FF` / `#302947` |
| 危险色 | 亮色 `#CC4E62`；暗色 `#FF94A4`，可用文字与图标同色 |
| 表面/边线 | 亮色 `#FFFFFF` / `#ECECF2`；暗色 `#202126` / `#383941` |
| 圆角 | 底部24、居中20、锚点13、输入10、按钮11逻辑像素 |
| 标题图标 | 38像素槽、19像素图标，避免重复无障碍名称 |
| 标题/说明 | 底部18、居中17、说明11；标题可换行，说明单行省略 |
| 操作区 | 水平20、按钮间距10、最小高度42；左侧自然宽度，右侧贴右 |
| 菜单行 | 常规/紧凑最小高度51/42，大字自然增高 |
| 锚点宽度 | 默认265；编号、绘图视图/类型/模板220 |

底部外壳最大高度637，受屏幕90%、键盘及父约束限制；可用高度小于360时紧凑显示。`expand` 默认 false，展开只使正文填满剩余高度；底部留白与安全区取最大值而非累加。具体值以本次读取的实现为准。

## 根包调用方

下表除特别标注均在 `lib/src/editor/`，按需读取，不要求每次 UI 修改遍历所有入口。

| 场景 | 实现文件 | 修改时关注 |
|---|---|---|
| 添加、字号、字间距、行距 | `editor_shortcut_toolbar.dart` | 配置可见性、行内横向子菜单、选区/键盘保持、默认清覆盖 |
| 块更多、分页符 | `collab_block_actions.dart`、`collab_page_divider_block.dart` | 类型头部、只读/能力、插入与删除完整性、不增加普通正文更多入口 |
| 日期/天气 | `collab_date_card_settings.dart`、`collab_weather_settings.dart` | 固定预览/名称/箭头、独立滚动、取消与一次应用、切回原尺寸 |
| 图片/资源 | `collab_image_editor.dart`、`collab_resource_settings.dart`、`collab_resource_block_base.dart` | 居中编辑、原始链接复制、删除及资源释放 |
| 媒体来源 | `editor_media_source_sheet.dart`、`lib/src/ui/modal/editor_media_source_panel.dart` | 展示与上传注入分离，上传归当前宿主实例 |
| 宿主封面/预览 | `example/lib/daily_guidance/local_journal_page.dart`（宿主） | 保留当前封面展示；后续增加编辑时按 skill 的移除/保存与拖动规则设计 |
| 链接/网页 | `collab_link_actions.dart`、`collab_web_embed_block.dart` | 完整 URL、视图分组、宿主能力与旧菜单失效 |
| 提及 | `collab_inline_entity_mention.dart`、`editor_user_mentions.dart` | 仅删提及、实体不受影响、头像/目录/点击由宿主注入 |
| 公式/绘图 | `collab_formula_sheet.dart`、`collab_mermaid_sheet.dart` | 新建/编辑区分、草稿、块动作与固定操作栏、长菜单滚动 |
| 分割线 | `collab_divider_settings.dart` | 新建暂存与取消、编辑即时应用、整条点击 |
| 表格/代码/编号 | `collab_table_controls.dart`、`collab_table_sheet.dart`、`collab_code_menu.dart`、`collab_ordered_marker.dart` | 精确锚点、当前勾选、最后行列保护、语言列表保留默认宽度 |
| 高亮与表情 | `collab_callout_block.dart`、`lib/src/ui/modal/collab_emoji_picker.dart` | 固定搜索/Tab、完整惰性目录联动、异步中断、防重入、外置移除错误边界 |
| 任务/会议卡片 | `collab_task_card_block.dart`、`collab_meeting_block.dart` | 专用头部、当前实例详情/跳转回调、无服务时不兜底 |

卡片外框、标题与锁覆盖在 `lib/src/ui/modal/collab_card_frame.dart`、`collab_card_header.dart`、`collab_card_lock_overlay.dart`。已有锁能力时保留布局和授权检查；本地模式不凭空添加锁服务。

## example 宿主

`example/lib/daily_guidance/local_journal_page.dart` 负责页面导航、编辑/预览、离开确认、分享及预览操作；`journal_surface.dart` 负责正文纸张展示；`guidance_entries.dart` 负责业务条目；`mention_picker.dart` 负责宿主候选选择。其他入口按当前调用链检索。

- 页面继续使用现有纸张色、封面、栏目和预览交互；弹窗规则不覆盖正文排版与业务配色。
- 宿主弹窗路由与局部主题位于 `example/lib/daily_guidance/ui/journal_modal.dart`，底部外壳与标题分别位于 `journal_bottom_sheet.dart`、`journal_modal_header.dart`；离开确认、分享及两类人员选择复用这些组件。保留保存/放弃/继续编辑返回值、关闭及会话检查，不跨包导入根库内部弹窗。
- 不将本轮 skill 引入描述为已完成所有既有 UI 的迁移；具体入口迁移需要相应代码和验证证据。

## 当前可用回归

下面列出本仓库实际存在的测试入口。先读测试确认覆盖的具体断言；文件存在不等于已经覆盖全部弹窗。

| 影响范围 | 现有测试 |
|---|---|
| 工具栏/能力显示 | `test/editor_shortcut_toolbar_test.dart`、`test/editor_configuration_test.dart` |
| 字号/颜色/间距 | `test/document_editor_text_color_test.dart`、`test/editor_spacing_test.dart` |
| 命令、撤销及输入 | `test/document_editor_commands_test.dart`、`test/local_editor_command_regression_test.dart`、`test/local_editor_input_test.dart` |
| 实例隔离/生命周期 | `test/editor_service_isolation_test.dart`、`test/local_editor_controller_test.dart` |
| 宿主弹窗主题、键盘/大字与固定头尾 | `example/test/daily_guidance/journal_modal_ui_test.dart` |
| 入口页窄屏大字/键盘滚动与真机弹窗 | `example/test/daily_guidance/journal_device_layout_regression_test.dart`、`example/integration_test/modal_ui_device_test.dart` |
| 宿主页及只读模式 | `example/test/daily_guidance/local_journal_page_test.dart`、`example/test/daily_guidance/journal_page_mode_test.dart` |
| 宿主键盘/格式菜单 | `example/test/daily_guidance/journal_keyboard_toolbar_test.dart`、`example/test/daily_guidance/journal_format_toolbar_test.dart` |
| 宿主分享/预览 | `example/test/daily_guidance/journal_preview_actions_test.dart`、`example/test/daily_guidance/journal_preview_spacing_test.dart` |
| 宿主边界与提及 | `example/test/daily_guidance/journal_host_boundary_test.dart`、`example/test/daily_guidance/mention_avatar_test.dart` |

涉及协议才使用 `test/blockcraft_json_codec_test.dart` 等协议回归并按根规范核对 BlockCraft。UI 行为没有现成覆盖时，按真实行为新增有意义的目标测试；不运行无关的原生构建或使用不存在的截图工具。

纯 skill 变更验证 frontmatter、元数据、相对链接、项目路径和 `git diff --check`；不声称做过 Flutter 布局、设备或截图验收。每轮新增验证归档并追加索引，历史证据不作为本轮自动通过依据。
