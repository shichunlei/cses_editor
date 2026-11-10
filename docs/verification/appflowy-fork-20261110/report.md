# AppFlowy 编辑器 fork 发布包迁移

根包、`example/` 和 `docs/integration_app/` 统一使用 pub.dev 的 `applowy_editor_fork: ^6.2.1`，通过 `package:applowy_editor_fork/applowy_editor_fork.dart` 访问公开 API。独立性检查改为校验发布源、锁定版本、校验和以及实际解析路径，并继续扫描依赖的运行源码。

- 三个包执行 `flutter pub get --offline`，均解析为 `6.2.1`，锁文件记录相同的包校验和。锁文件沿用仓库的忽略规则。
- 168 个手写 Dart 文件执行 `dart format`，无需额外格式调整。三个包的 `flutter analyze --no-pub` 均通过。
- `flutter test --no-pub` 在根包通过 89 项，在接入模板通过 6 项。
- 独立性检查及其 14 项单元测试通过。未运行真机集成测试。

示例全量测试通过 294 项，失败 6 项。以迁移前的 HEAD 创建临时副本，使用原固定 Git 依赖 `de71028ab4146d76e5059e59273d10bf17df5dd6` 离线解析并运行同一套测试，结果同为 294 项通过，且复现同样的 6 项失败。

- `guidance_entries_layout_test.dart` 的自定义都来帮流程，1 项。
- `guidance_record_fields_test.dart` 的导向记录字段与提及，3 项。
- `journal_format_toolbar_test.dart` 的 H1–H6 预览和重开，2 项。
