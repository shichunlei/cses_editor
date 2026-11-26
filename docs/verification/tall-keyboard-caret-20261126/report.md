# 极高键盘下的光标行可见性与滚动稳定性

日期：2026-11-26。

## 行为与边界

`EditorCaretVisibility` 使用扣除工具栏后的实际正文视口，并以系统键盘上沿限制可见底边。可见区域足够时保留上下各 8 逻辑像素留白；不足时将留白缩减为行外余量的一半，优先显示完整行框。可见高度小于行高时稳定对齐行顶，无可用高度或无效行框时不滚动。滚动目标仍受已有最小/最大滚动范围约束，不增加正文占位，不调整封面和工具栏布局。

正常的只读、暂停、路由、选区及会话守卫保留。纠偏不改变正文、选区或输入法显示状态，重复窗口通知不应改变已稳定的滚动位置。

## 复现及验证

SaaS 的 680 高屏幕、410 高键盘场景留下 38 高正文视口，光标行高 32。固定上下各 8 的留白导致行顶或行底超出 2 像素，重复通知时两种位置交替出现。强化两类日填写的测试后，修复前均在完整行可见性断言失败，见 [saas-red.log](saas-red.log)。

- 根包 `test/editor_caret_visibility_test.dart` 新增 8 项真实编辑器 Widget 测试，按实际行高构造常规余量、仅余 6 像素、恰好一行和不足一行的视口，分别覆盖 1 倍与 2 倍文字缩放。检查完整行或稳定行顶对齐，以及 4 次相同窗口通知后滚动、选区、正文及输入法显示状态不变。
- 根包结合既有 `editor_shortcut_toolbar_test.dart` 共 36 项通过，见 [editor-regression.log](editor-regression.log)。
- SaaS `saas_guidance_editor_flow_test.dart` 对导向与成果的 300/410 两档键盘均要求完整行可见、真实末字命中及 3 次重复通知后位置不变；与预览、正文颜色及模板测试共 132 项通过，见 [saas-regression.log](saas-regression.log)。
- example 既有 `journal_keyboard_caret_visibility_test.dart` 的多段/单段长文、常规/大字和菜单变化 4 项通过，见 [example-regression.log](example-regression.log)。
- 目标 Dart 格式化、根包及 SaaS 静态分析通过，见 [editor-analyze.log](editor-analyze.log)、[saas-analyze.log](saas-analyze.log)。两仓库均执行 `git diff --check`。

## 验证范围

本轮使用 Flutter Widget 测试模拟窗口与键盘尺寸，未进行新的 Android 真机验收。视口小于一行时物理上无法显示整行，固定行顶对齐用于保持可见位置稳定。没有修改依赖版本或任一 pubspec；SaaS 通过已有本地编辑器依赖运行验证。
