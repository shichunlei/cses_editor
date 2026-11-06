# 成果导向与导向成果名称调整

日期：2026-11-06。

- `ORIENT` 展示为“成果导向”，`RESULT` 展示为“导向成果”。同步首页、应用名称、编辑封面、首栏目、预览、分享图、新建记录标题及默认图片文件名前缀。
- 汇丰永盛 V2、成塔服饰 V2 的预览首栏目改用宿主传入的标题，避免 RESULT 被固定显示为“成果导向”；中企云链继续使用同一标题来源。
- 更新活跃接入文档、迁移方案、公司模板适配 skill 与 UI 规范。保持 ORIENT/RESULT、dailyType、存储身份和历史正文原值；旧 JSON 样例及历史验证记录保留。
- 保留此前关闭按钮对齐和自定义栏目修复等工作区修改。

验证：

- 已格式化本次修改的手写 Dart 文件。
- example 所属包静态分析通过，见 [分析日志](analyze.txt)。
- `empty_guidance_flow_test.dart`、`body_content_api_test.dart`、`local_journal_page_test.dart`、`journal_page_mode_test.dart` 共 33 项通过，见 [测试日志](tests.txt)。覆盖类型切换、编辑、保存、重开、预览和分享，以及三个公司模板的保存预览流程。
- iOS Info.plist 语法检查和 `git diff --check` 通过。

本轮未重新构建、安装或执行 Android/iOS 真机验证；SaaS 生产代码仍未迁移。
