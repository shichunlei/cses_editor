# 今日导向 UI 与编辑交互提交检查

日期：2026-11-03。

## 范围

本次提交汇总今日导向保存后预览、封面与首栏目标题、固定封面与初始横格、人员业务行创建及排版、关闭栏目不自动聚焦，以及对应技能、测试和验证记录。仅包含当前已核对的同一功能范围文件。

## 最终合并检查

- 18 个本次修改或新增 Dart 文件格式检查通过，无需重新格式化。
- 在 example 包对这 18 个 Dart 文件执行 `flutter analyze --no-pub`，无问题。
- 在 example 包运行以下 12 个相关测试文件，共 108 项测试通过：body_content_api_test、dynamic_journal_test、journal_host_boundary_test、journal_keyboard_toolbar_test、journal_native_mentions_test、journal_preview_actions_test、local_journal_page_test、journal_page_layout_regression_test、journal_section_close_focus_test、journal_sticky_cover_test、journal_rules_test、journal_preview_spacing_test。
- `git diff --check` 通过；提交前进一步检查暂存区差异。

输出日志见 analyze.log、tests.log；归档日志已去除行尾空白。工具栏/布局切换场景仍有既有卸载 context 诊断打印，未形成测试框架失败。本轮未增加设备构建或真机验收。

前次审查所记横屏键盘下固定封面溢出仍为已知待处理项，未纳入用户指定的两项布局修复。
