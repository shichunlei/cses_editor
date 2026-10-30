# 编辑会话加载前引用类型校验

日期：2026-10-30。

## 修复边界

此前 bodyContent 可以加载含 department 引用的正文，但保存派生只接受 user/task/meeting/doc，导致编辑后才发现无法保存。

- BodyContentCodec.decode 在块结构校验后、编辑树和会话创建前，调用 GuidanceRecordFields.validateMentionTypes。
- 加载与保存派生共用类型读取和白名单规则：支持 user/task/meeting/doc，兼容 d:mentionType，缺失按 user。
- 校验包含隐藏栏目的可编辑正文，锁定模板节点沿用字段派生的排除规则。
- 不支持类型抛出专用 FormatException 子类 UnsupportedGuidanceMentionType，页面显示具体类型、支持范围及原记录保护说明。
- 页面继续复用现有加载失败和重试布局，不创建可编辑会话、不提交或覆盖来源；后台修正后可重试编辑保存。
- 仅调整 example 与文档，不修改 SaaS、原始样例、编辑器根包或块协议。

## 端到端回归

通过真实页面、控制器、Codec、ApiJournalStore 和 MockGuidanceApi 验证：

1. department、unknown、命名空间 department、隐藏自检中的 department 均在加载时明确提示，AppFlowyEditor 不出现，保存次数为 0，原记录不变。
2. 加载失败不留下可提交的完整记录快照；直接写入也被拒绝。
3. 后台纠正后重试成功，实际输入、保存正确生成 dailyResult，dailyOrient 为 null，卸载不重复提交。
4. user/task/meeting/doc 及旧引用缺少类型均可正常加载、编辑、保存；同 ID 不同类型保留，旧引用输出 user。

## 验证命令

在 example 包格式化四个受影响 Dart 文件，执行：

```sh
flutter test --no-pub test/daily_guidance/guidance_record_fields_test.dart test/daily_guidance/body_content_api_test.dart --reporter expanded
flutter analyze --no-pub lib/daily_guidance/guidance_record_fields.dart lib/daily_guidance/body_content_codec.dart lib/daily_guidance/guidance_api.dart lib/daily_guidance/local_journal_page.dart test/daily_guidance/guidance_record_fields_test.dart test/daily_guidance/body_content_api_test.dart
```

31 项目标测试全部通过：[test.log](test.log)；静态分析无问题：[analyze.log](analyze.log)。根目录 git diff --check 通过。

未连接真实后台、执行真机或全仓测试；页面级端到端验证使用 Widget 测试与内存 Mock API。
