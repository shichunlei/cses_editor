# 首栏目标题按 orientType 展示

## 修改

页面将既有的 orientType 标题映射传给首栏目：ORIENT 显示“今日导向”，RESULT 显示“今日成果”。编辑、预览和分享图使用同一展示标题；不修改正文 JSON、栏目身份、保存或字段派生。

JournalSurface 和 JournalSharePage 增加可选 recordTitle 参数，直接调用时保留原默认值；页面入口按实际记录类型传入。UI 技能同步记录此展示规则。

## 验证

- 所属 example 包相关 3 个实现文件分析：通过。
- body_content_api_test.dart 中 ORIENT / RESULT 页面及保存测试：2 项通过。
- journal_page_mode_test.dart、local_journal_page_test.dart：8 项通过，包含编辑/预览、窄屏和大字号布局。
- journal_preview_actions_test.dart：3 项通过，包含完整分享图生成。
- 本次手写 Dart 已格式化；git diff --check：通过。
- 本轮未运行 Android 真机。
