# 领航员和都来帮点击菜单即创建业务行

日期：2026-11-03。

## 行为

- 点击领航员/都来帮菜单后，先创建独立空业务行，再打开原生选人面板。
- 取消选人保留该空行并恢复输入；选中用户后填入原行，不再新建一行。
- 创建与填人分别形成可撤销事务。未选人的空行可保存并重开。
- 创建期间阻止重复操作，选人期间保留事务暂停与页面/会话/目标修订校验；迟到或失效结果不回填。
- 同步 UI 技能及场景参考，保留此前工作区改动。

## 验证

在 example 执行：

```sh
dart format lib/daily_guidance/local_journal_controller.dart lib/daily_guidance/local_journal_page.dart test/daily_guidance/journal_keyboard_toolbar_test.dart test/daily_guidance/dynamic_journal_test.dart
flutter analyze --no-pub lib/daily_guidance/local_journal_controller.dart lib/daily_guidance/local_journal_page.dart test/daily_guidance/journal_keyboard_toolbar_test.dart test/daily_guidance/dynamic_journal_test.dart
flutter test --no-pub test/daily_guidance/journal_keyboard_toolbar_test.dart test/daily_guidance/dynamic_journal_test.dart test/daily_guidance/journal_native_mentions_test.dart --reporter expanded
```

3 个文件共 59 项测试通过，覆盖点击即创建、取消保留、原行填人、空行保存重开、分步撤销重做、旧会话目标拒绝、账号变化和人员输入/删除排版。

静态分析提出异步创建后使用页面 context 需显式 mounted 检查，已补齐；工具栏 14 项测试在此调整后复验通过。最终静态分析无问题；根目录 `git diff --check` 通过。

工具栏两个既有可达性用例在卸载时打印 context 诊断，测试框架未报失败；日志原样保留。本轮未进行设备构建或真机验收，不涉及块协议或依赖变更。
