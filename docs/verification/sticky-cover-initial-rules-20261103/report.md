# 今日导向固定封面与初始横格

日期：2026-11-03。

## 变更

- 编辑和预览的雪山封面移到正文滚动区上方，保留透明状态栏和安全区内操作按钮。
- 仅有首栏目时，日期和标题按实际高度布局，横格填满下方剩余视口，不新增正文空段落。
- 添加任意感悟、自检、自定义栏目后恢复原有块间距；撤销添加或关闭至仅剩首栏目时恢复填充。
- 共用根滚动、选区和资源所有权保持原契约；分享图仍按自然内容排版，保留完整封面及品牌页脚。
- 同步 UI 技能与场景参考；保留工作区此前已有的修改。

## 验证

在 example 包执行：

```sh
dart format lib/daily_guidance/local_journal_page.dart lib/daily_guidance/journal_surface.dart test/daily_guidance/journal_sticky_cover_test.dart test/daily_guidance/local_journal_page_test.dart
flutter analyze --no-pub lib/daily_guidance/local_journal_page.dart lib/daily_guidance/journal_surface.dart test/daily_guidance/journal_sticky_cover_test.dart test/daily_guidance/local_journal_page_test.dart
flutter test --no-pub test/daily_guidance/journal_sticky_cover_test.dart test/daily_guidance/journal_preview_spacing_test.dart test/daily_guidance/local_journal_page_test.dart test/daily_guidance/journal_rules_test.dart test/daily_guidance/journal_preview_actions_test.dart --reporter expanded
```

静态分析通过；5 个测试文件共 13 项测试通过。新增回归覆盖 390 宽常规字号、320 宽两倍字号，横线铺满视口、三类附加栏目恢复紧凑布局、撤销恢复补线、长正文滚动时日期移动且封面固定，以及布局不改写正文。既有回归覆盖多栏目编辑与预览间距、空行绘制与留白点击、页面保存和完整品牌图片分享。

仓库根目录执行 `git diff --check` 通过。

本轮未进行设备构建、真机截图或键盘弹出专项验收；不以历史截图作为本轮视觉验收。不涉及块协议或依赖变更。
