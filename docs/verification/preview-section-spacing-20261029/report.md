# 预览栏目间距最多两行（2026-10-29）

## 修改

根因是 AppFlowy 页面会将 editorStyle.padding 应用于每个根块。此前预览为悬浮按钮预留的 96px（随字号缩放）底部 padding，实际重复加在每个栏目后，造成大块留白。

- 预览根块 padding.bottom 改为 0；悬浮按钮所需留白改为文档 footer，仅在整篇末尾出现一次。
- 预览栏目不再补足编辑态的三行书写区；栏目下方使用一行高度的间距，含下个标题顶部留白仍不超过两行。
- 展示列表折叠栏目末尾的普通空段落；中间空行、非空正文、业务标记和原始节点仍保留，不改变正文 JSON、保存和撤销历史。
- 编辑态保留原来的书写区、段落、间距及键盘自定义菜单。
- 分享/点赞仍浮在页面底部，正文末尾仍可完整滚动到按钮上方。

## 验证

- `flutter test --no-pub --no-test-assets test/daily_guidance/journal_preview_spacing_test.dart test/daily_guidance/local_journal_page_test.dart test/daily_guidance/guidance_entries_layout_test.dart test/daily_guidance/journal_preview_actions_test.dart --reporter expanded`：15 项通过，见 [target-tests.txt](target-tests.txt)。
- 新增几何回归：390px/标准字号和 320px/2 倍字号；含八个尾部空段落及单行短栏目，实测栏目正文末尾到下个栏目标题的距离不超过两行；预览不改 JSON、不保存，编辑仍显示尾部段落及书写留白。
- 既有回归覆盖记事本、真实页面都来帮、原子提及/换行/缩放布局、固定悬浮按钮与复制分享。
- `flutter analyze --no-pub lib/daily_guidance/journal_surface.dart test/daily_guidance/journal_preview_spacing_test.dart test/daily_guidance/journal_preview_actions_test.dart`：No issues found，见 [changed-files-analysis.txt](changed-files-analysis.txt)。
- 手写 Dart 已格式化，`git diff --check` 通过。

## 当前工作区限制

验证期间用户工作区的 `example/moke.json` 被移除，新增了 `example/文档完整数据结构.json`，而 pubspec.yaml 仍声明 moke.json。常规资源构建因此失败，整个 example 分析也报告该资源缺失；保留 [asset-build-blocked.txt](asset-build-blocked.txt) 与 [package-analysis-assets.txt](package-analysis-assets.txt) 作为记录。本次未恢复、替换或重命名用户模板；目标测试使用 `--no-test-assets` 跳过无关的示例资源打包，按上述范围完成排版验证。

未重新安装手机应用，未改核心包公开 API 或块协议。
