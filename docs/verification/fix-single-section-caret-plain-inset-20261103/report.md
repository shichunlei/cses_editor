# 修复单栏目点击定位与无封面正文顶部遮挡

日期：2026-11-03。

## 本轮修改

- **P1**：在单栏目根布局保留编辑器声明的头部索引槽，视觉头部继续在首栏目内参与视口补高。可见节点不再被误过滤，初始空正文可直接点击定位、接收真实输入法增量；增加可选栏目并撤销后也能定位。
- **P2**：页面根据是否显示封面选择 `extendBodyBehindAppBar`。无封面文档由 Scaffold 避让操作栏与状态栏，编辑及预览首行均位于 AppBar 下方。
- 补充永久回归 `journal_page_layout_regression_test.dart`，同步技能中无封面页面的顶部避让说明。保留其他工作区修改。

## 验证

在 example 包执行：

```sh
dart format lib/daily_guidance/journal_surface.dart lib/daily_guidance/local_journal_page.dart test/daily_guidance/journal_page_layout_regression_test.dart
flutter analyze --no-pub lib/daily_guidance/local_journal_page.dart lib/daily_guidance/journal_surface.dart test/daily_guidance/journal_page_layout_regression_test.dart
flutter test --no-pub test/daily_guidance/journal_page_layout_regression_test.dart test/daily_guidance/journal_sticky_cover_test.dart test/daily_guidance/local_journal_page_test.dart test/daily_guidance/journal_keyboard_toolbar_test.dart test/daily_guidance/journal_native_mentions_test.dart test/daily_guidance/journal_preview_spacing_test.dart --reporter expanded
```

6 个测试文件共 48 项回归通过。新增 3 项测试覆盖真实点击选区、输入法写入、感悟与自定义栏目增删后的定位，以及 320 宽/两倍字号/32 顶部安全区下无封面编辑和预览的首行位置。首项进一步改用完全空白的初始正文并复验，3 项均通过，见 regression-recheck.log。

静态分析无问题；根目录 `git diff --check` 通过。测试中仍有编辑器内部打印的卸载 context 诊断，未形成测试框架异常，日志原样保留。

未构建设备安装包或进行真机验收。不涉及块协议或依赖变更。本轮按用户指定处理上述两项；前次审查的横屏键盘固定封面溢出仍待处理。
