# 图片菜单配置验证

日期：2026-11-22。

## 当前行为

`EditorConfiguration.showImageEditAction` 与 `showImageCaptionAction` 默认开启；`withHost` 未传时继承原值，可分别覆盖。图片更多菜单按会话配置过滤入口，不修改正文。SaaS 日导向普通与导入文档均关闭两项；原图片及题注继续展示、保存，其他操作沿用原能力。

## 已执行验证

- 根包 `dart format`：本次四个 Dart 文件完成。
- 根包 `flutter analyze --no-pub lib/src/editor/core/editor_configuration.dart lib/src/editor/collab_image_block.dart test/editor_configuration_test.dart test/collab_image_layout_test.dart`：无问题。
- 根包 `flutter test --no-pub test/editor_configuration_test.dart test/collab_image_layout_test.dart --reporter expanded`：23 项通过。
- Widget 回归覆盖两个开关的四种组合 × 无题注/已有题注，验证添加及编辑题注入口、图片编辑入口、已有题注渲染、下方插入/替换/复制链接/删除入口及正文 JSON 不变；既有横/方/竖图编辑和预览布局回归通过。
- 配置测试覆盖默认开启、宿主复制继承及独立覆盖。
- example 消费者 `flutter analyze --no-pub lib/daily_guidance/journal_draft.dart lib/daily_guidance/local_journal_controller.dart lib/daily_guidance/journal_surface.dart`：无问题。
- SaaS 日导向配置及流程测试文件的目标静态分析：无问题。
- SaaS `flutter test --no-pub test/modules/mutualism/presentation/orient_result/editor/saas_guidance_editor_flow_test.dart --plain-name "普通和导入日导向均关闭图片编辑和题注入口并保留图片能力" --reporter expanded`：1 项通过；启动阶段出现已有依赖的 Material Icons 配置提示，未导致测试失败。
- 两仓库 `git diff --check`：通过；本次文件均未暂存，既有 pubspec 改动保持原状态。

## 验证边界

未连接真机检查菜单视觉；建议补测成果导向/工作成果中打开图片更多菜单、已有题注的保存重开，以及替换和删除后的撤销。菜单开关不改变正文协议或异步生命周期。
