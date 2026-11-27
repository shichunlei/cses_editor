# iOS 光标菜单选择局部文字

日期：2026-11-27。

## 行为与范围

`CollabMobileSelectionMenu` 仅在 iOS 折叠光标有有效词边界时提供「选择」。通过已挂载 Selectable 的 `getWordBoundaryInPosition` 取得正文偏移；段尾使用 Delta 的 `prevRunePosition` 查询末词，段内空白不猜测相邻词。选择只更新会话选区，复用现有手柄、浮栏和宿主业务入口，不修改正文、撤销历史、底层 fork、原生配置或 Android 长按行为。

菜单展示和执行均复核组件、编辑器身份、当前光标及 `CollabTextRange` 快照。空白、空段落和无有效边界时隐藏入口；只读正文保留选择与复制；会议、任务和公式行内对象保持完整原子。现有集成文档与 UI skill 记录当前约束；按用户选择不创建 `CLAUDE.md`。

## 自动验证

- 首先添加 iOS 光标菜单回归，修改前在找不到「选择」按钮的断言失败。
- `flutter test --no-pub test/editor_ios_selection_menu_test.dart --reporter expanded`：19 项通过。覆盖英文词首/词中、中文边界、段尾、空白/空段落、只读、旧光标/正文/卸载/替换会话、会议/任务/公式原子、Android 菜单，以及 iOS 选词后传给创建会议/任务的精确标题。中文测试引擎将样例解析成单字，菜单沿用底层边界，不自行分词。
- `flutter test --no-pub test/editor_ios_selection_menu_test.dart test/editor_selection_meeting_test.dart test/editor_selection_task_test.dart --reporter expanded`：在加入最后两项 iOS 宿主回调测试前共 25 项通过，其中既有会议 5 项、任务 3 项，覆盖创建、取消、正文变化、事务拒绝、权限失效和撤销。最终新增测试单独运行 19 项全部通过，合计覆盖 27 个用例。
- `dart format lib/src/editor/collab_mobile_selection_menu.dart test/editor_ios_selection_menu_test.dart`：通过。
- `flutter analyze --no-pub lib/src/editor/collab_mobile_selection_menu.dart test/editor_ios_selection_menu_test.dart`：No issues found。
- `git diff --check` 与提交前 `git diff --cached --check`：通过。

## 验证限制与真机建议

Widget 测试使用 iOS/Android 的 Flutter 平台变体检查真实编辑器、浮层及选区状态；依赖的底层手势实现还按宿主操作系统选择分支，因此这些测试不代表 iOS 长按或手柄触摸的真机验收。`xcrun simctl list devices booted` 无启动设备，本轮未运行 iOS 模拟器/真机、未构建宿主安装包。

建议在 iOS 宿主验证：

1. 长按仍可移动光标，松手后点击「选择」，出现局部高亮与两个手柄；拖动左右手柄扩大/缩小选区，覆盖跨行、跨段及屏幕边缘自动滚动。
2. 英文、中文、词间空白、段尾、Emoji、只读正文及长行内引用；检查引用不会被拆开。
3. 拖动期间菜单隐藏，松手后恢复；在窄屏/大字下翻页访问会议、任务按钮，确认预填标题等于选中文字。
4. 保存后切只读、关闭页面、替换文档和快速重复点击，确认不产生迟到选区或多次业务命令。

验证使用当时已解析依赖（`--no-pub`）。按用户要求，提交同时包含 `pubspec.yaml` 的 `flutter_svg ^2.5.1`、`lucide_icons_flutter ^4.0.5`、`file_picker ^13.4.1` 版本约束升级；这些升级未重新解析验证，前述菜单测试结果不作为新依赖组合的验证结论。
