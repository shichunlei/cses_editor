# 编辑与预览统一栏目间距（2026-10-30）

按用户要求，将编辑页的自动栏目留白改为与预览一致，保留现有记事本、输入、菜单和正文协议。

- 两种模式都不在每个根栏目底部重复增加 padding，也不补足三行书写区。
- 每个栏目下方统一使用一行正文高度的留白，加上下个标题顶部间距不超过两行。
- 文档底部留白只出现在 footer 一次：编辑保留 40px，预览保留原悬浮按钮空间，宿主自定义 footer 继续优先。
- 编辑中的实际空段落仍可输入、回车、定位和撤销，不为了视觉压缩隐藏可输入节点；预览仍仅在展示时折叠末尾普通空段落。因此有意输入的空行属于正文，不计入自动栏目留白。
- 同步当前接入说明、cses_editor_ui skill 及场景参考的产品规则，不修改根包或块协议。

## 验证

- `flutter test --no-pub test/daily_guidance/journal_preview_spacing_test.dart test/daily_guidance/local_journal_page_test.dart test/daily_guidance/guidance_entries_layout_test.dart test/daily_guidance/journal_keyboard_toolbar_test.dart --reporter expanded`：27 项通过，见 [target-tests.txt](target-tests.txt)。
- `flutter test --no-pub test/daily_guidance/journal_preview_actions_test.dart --plain-name 'actions fit small preview' --reporter expanded`：1 项通过，见 [mode-layout-tests.txt](mode-layout-tests.txt)。共 28 项间距、页面、输入及菜单目标测试通过。
- 几何回归覆盖 390px/标准字号、320px/2 倍字号；编辑和预览的自动间隔相等且均不超过两行，短栏目不额外补高，实际空段落保留、输入及撤销恢复 JSON。
- 既有业务条目布局测试改为比较相对栏目顶部的位置，保留首行标记、行高、横线、提及和选区断言；排除工作区已采用的沉浸式预览页头与编辑页头 56px 的整体位置差异。
- 修改的 Dart 已格式化；`git diff --check` 通过。未做本轮真机安装或截图验收。

## 工作区并行改动与验证限制

工作区同时包含图片分享、平台文件保存及预览页面相关改动，本轮保留其逻辑和资源，不将它们纳入间距实现。

扩大运行整个 `journal_preview_actions_test.dart` 时，图片分享测试 `preview shares the full branded PNG to each target without saving the document` 未通过：初次为无界布局，当前复验为分享后 `pumpAndSettle timed out`。最新日志见 [preview-actions-tests.txt](preview-actions-tests.txt)，未声称图片分享验证通过。

整个 example 分析记录在 [example-analysis.txt](example-analysis.txt)，该次有图片保存参数弃用和页面 if 风格共 3 条 info；随后针对四个相关文件的分析见 [changed-files-analysis.txt](changed-files-analysis.txt)，当前仅图片分享新增截图构建器的一条 `use_null_aware_elements` info，无 error。初次分析捕获到同文件正在变化的截图构建器签名错误，后续复验已消除。未在本次间距修改中调整截图、保存或分享实现。

保留其他工作区改动和暂存状态，不修改示例 JSON 数据。
