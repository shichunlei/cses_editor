# 自定义栏目关闭入口

## 修改

自定义栏目（`custom:`）标题栏现在显示“关闭”，点击继续调用宿主传入的 `onCloseSection`，由页面既有流程负责保存和撤销。今日记录仍不显示关闭入口；预览仍不显示。

## 验证

- `cd example && flutter analyze --no-pub lib/daily_guidance/journal_surface.dart`：通过。
- `cd example && flutter test --no-pub test/daily_guidance/local_journal_page_test.dart --reporter expanded`：通过（4 项）。
- `git diff --check`：通过。
