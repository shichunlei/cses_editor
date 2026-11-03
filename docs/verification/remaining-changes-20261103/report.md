# 剩余修改提交检查

## 内容

- 光标处于待办块时，一级菜单待办图标使用选中样式。
- 样例记录由今日成果切换为今日导向。
- 根包 AppFlowy 依赖使用 `../appflowy-editor` 本地路径，示例移除重复声明。
- 示例 `file_picker` 约束调整为 `^13.3.2`。

本轮按用户“剩余修改也提交”的要求提交上述现有差异。当前依赖验证使用本机 AppFlowy 工作区。

## 检查结果

- `flutter analyze --no-pub lib/src/editor/editor_shortcut_toolbar.dart`：通过。
- `flutter test --no-pub test/editor_shortcut_toolbar_test.dart --reporter expanded`：27 项通过。
- 样例 JSON 解析及 `bizType` / `orientType` 一致性：通过。
- `git diff --check`：通过。
