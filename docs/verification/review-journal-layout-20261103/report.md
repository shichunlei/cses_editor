# 今日导向当前未提交修改审查

日期：2026-11-03。范围为当前未提交修改和新增文件，重点为固定封面、初始横格、业务人员行与选人流程。遵循 cses_editor_ui 技能；未修改业务实现。

## 发现

1. **P1：初始单栏目布局破坏可见节点索引，点击正文不能放置光标。** `journal_surface.dart` 514–523 行把 header 移到第 0 个正文项内，却仍由上层 DocumentEditorView/AppFlowyEditor 提供非空 header，使 EditorState.showHeader 仍为 true。滚动控制器把唯一正文项再次当成 header 扣除，得到 (0, -1)。实际点击首行后 selection 仍为 null。应保留编辑器头部与正文滚动索引契约。
2. **P2：横屏键盘使固定封面挤占全部视口并溢出。** `local_journal_page.dart` 916–919 行把封面作为 Column 的非弹性子项，封面按宽度固定到 260 高。800×390 逻辑视口和底部键盘 220 时，正文可用高度仅 170，出现 RenderFlex bottom overflow 90。应按键盘和实际剩余视口限制封面并保留可编辑区域。
3. **P2：无封面文档的正文被透明 AppBar 遮挡。** `local_journal_page.dart` 797 和 905–915 行无条件让正文延伸到 AppBar 下并关闭顶部安全区，但 plainDesktop 分支不展示封面或头部。首段从 y=0 开始，返回按钮至 y=52；正文和操作按钮重叠。应按是否显示封面选择顶部避让。

## 证据

临时 Widget 测试三项均失败，日志见 layout-tests.log。第一项追加真实点击测试，可见范围 (0, -1)，点击后 selection 为 null，见 selection-test.log。完整复现源代码及运行方法见 reproduction.md。审查后移除临时测试文件。

`git diff --check` 通过。未进行设备构建或真机验收。
