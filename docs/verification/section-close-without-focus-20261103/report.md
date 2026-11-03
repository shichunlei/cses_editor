# 关闭栏目不自动聚焦正文

日期：2026-11-03。

## 变更

关闭感悟、自检或自定义栏目时，页面先收起正文键盘并释放当前输入焦点；关闭事务清除正文选区，不再把光标移到今日记录首段。新增栏目继续沿用原输入定位行为。

保留栏目完整关闭草稿、撤销重做、持久化及后续编辑能力；用户再次点击正文才恢复输入。同步 UI 技能的关闭焦点约定，不涉及块协议或依赖变更，保留工作区其他修改。

## 验证

新增 `journal_section_close_focus_test.dart` 的 6 项 Widget 回归，覆盖三类栏目与键盘原先关闭/打开两种状态。检查关闭后无正文选区、无输入焦点、键盘关闭、内容完整保留，随后真实点击正文可输入，并可撤销及重做关闭。修复前复现关闭后 selection 被移到 [0, 0]，见 reproduction.log。

在 example 包执行：

```sh
dart format lib/daily_guidance/local_journal_page.dart lib/daily_guidance/local_journal_controller.dart test/daily_guidance/journal_section_close_focus_test.dart
flutter analyze --no-pub lib/daily_guidance/local_journal_page.dart lib/daily_guidance/local_journal_controller.dart test/daily_guidance/journal_section_close_focus_test.dart
flutter test --no-pub test/daily_guidance/journal_section_close_focus_test.dart test/daily_guidance/dynamic_journal_test.dart test/daily_guidance/journal_keyboard_toolbar_test.dart --reporter expanded
```

3 个测试文件共 42 项通过，静态分析无问题；根目录 `git diff --check` 通过。工具栏既有卸载 context 诊断仍按原样记录，测试框架未报告异常。

未进行设备构建或真机验收。
