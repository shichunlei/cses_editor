# 示例 JSON 文件改名引用更新（2026-10-29）

用户已将 `moke.json` 改名为 `文档完整数据结构.json`。本次统一更新首页资源读取、pubspec.yaml 资源声明、bodyContent API/头像/固定模式测试和当前 README/数据格式说明；历史验证归档保留原文件名记录。

JSON 文件本身没有修改，SHA-256 前后相同，见 [preservation.json](preservation.json)。bodyContent 适配、保存协议及界面保持原行为。此前示例资源缺失问题已经消除。

## 验证

- `flutter test --no-pub test/daily_guidance/body_content_api_test.dart test/daily_guidance/journal_page_mode_test.dart test/daily_guidance/mention_avatar_test.dart test/daily_guidance/journal_preview_spacing_test.dart --reporter expanded`：21 项通过，见 [target-tests.txt](target-tests.txt)。本轮正常构建测试资源，未使用 --no-test-assets；覆盖新文件读写、真实首页编辑/预览、头像、任务图标、原键盘菜单和预览两行间距。
- `flutter analyze --no-pub`：整个 example No issues found，见 [example-analysis.txt](example-analysis.txt)。
- 当前源码、资源配置、测试和当前接入说明中无 moke.json 残留引用；历史报告不改写。
- 修改的 Dart 已格式化，`git diff --check` 通过；未重新安装手机应用。

未修改核心公开 API 或块协议，保留用户其他工作区改动和暂存状态。
