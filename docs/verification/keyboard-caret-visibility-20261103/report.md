# 键盘与菜单上方的焦点行避让

日期：2026-11-03。

## 问题与修复

键盘逐帧弹起或子菜单改变高度时，焦点可能保持原位置，等现有延迟滚动后才恢复可见。新增回归在键盘高度变化后两个渲染帧内检查，修复前 4 项失败，焦点行底部仍低于菜单顶部，见 reproduction.log。

根包新增内部 `EditorCaretVisibility`，接入移动工具栏主菜单/子菜单已扣除后的正文区域，监听选区、窗口指标及正文尺寸变化，在最终排版后仅滚动被遮挡的折叠光标行，并保留 8 逻辑像素间距。使用实际视口与系统键盘上沿限幅，不重复增加键盘或菜单 padding；按当前行而非整个长段落滚动。

仅同步调整当前正文滚动位置，不改写正文、历史、选区或输入连接。只读、暂停、非当前路由、空选区和范围选区不处理；替换会话或卸载后帧请求失效，监听由组件自己注销。正常手动滚动不主动发起校正。未改变块协议或依赖。

## 验证

新增 `journal_keyboard_caret_visibility_test.dart` 的 4 项 Widget 回归，覆盖 390 宽常规字号、320 宽 1.5 倍字号、多段正文及单段多行。真实点击靠近底部的输入行后，在不改选区的情况下依次模拟 120/240/320 高的键盘；两个渲染帧内验证焦点行位于菜单上方。继续检查子菜单展开和光标移至文末、正文与选区保持、关闭键盘不被重新打开。

根包执行：

```sh
dart format lib/src/editor/editor_caret_visibility.dart lib/src/editor/stable_mobile_toolbar.dart
flutter analyze --no-pub lib/src/editor/editor_caret_visibility.dart lib/src/editor/stable_mobile_toolbar.dart
flutter test --no-pub test/editor_shortcut_toolbar_test.dart --reporter expanded
```

根包静态分析通过，27 项工具栏回归通过。

example 包执行：

```sh
dart format test/daily_guidance/journal_keyboard_caret_visibility_test.dart
flutter analyze --no-pub test/daily_guidance/journal_keyboard_caret_visibility_test.dart lib/daily_guidance/journal_surface.dart
flutter test --no-pub test/daily_guidance/journal_keyboard_caret_visibility_test.dart test/daily_guidance/journal_keyboard_toolbar_test.dart test/daily_guidance/journal_section_close_focus_test.dart test/daily_guidance/journal_host_boundary_test.dart test/daily_guidance/journal_page_layout_regression_test.dart test/daily_guidance/journal_sticky_cover_test.dart --reporter expanded
```

example 静态分析通过，39 项回归通过。合计 66 项测试通过，根目录 `git diff --check` 通过。归档日志去除行尾空白。既有卸载 context 诊断仍原样记录，未形成最终测试框架失败。

## 验证边界

Widget 测试运行于 macOS，AppFlowy 使用其桌面选区服务；移动工具栏与窗口尺寸按移动场景模拟。测试关闭键盘前等待宿主桌面服务的指标防抖，并先完成清除选区的排版，再模拟键盘隐藏，避免桌面服务的既有空选区防抖问题干扰移动场景。尚未做真机键盘动画、系统输入法或设备构建验收。

此前记录的极短横屏视口下固定封面挤占编辑区域问题不在本轮修改范围，本次滚动校正要求正文仍有可用高度。
