# 今日导向栏目保留与今日记录字段派生

日期：2026-10-30。

## 范围与行为

仅修改 example 的字段提取、保存接入、目标测试及协议说明，未修改 SaaS、UI、BlockCraft 块协议或原始示例 JSON。

- help/pilot 段落同时保留于原栏目和聚合列表；今日记录、感悟、自检、自定义栏目均适用。
- daily-cover/daily-body 的可编辑正文按顺序合并为今日记录；跳过锁定模板标题，保留标记内容与引用。
- ORIENT 仅派生 dailyOrientContent，RESULT 仅派生 dailyResultContent；另一类型字段保留来源值。
- 正文与派生字段来自同一保存快照；清空后输出空内容和引用，避免旧摘要残留。
- 提取器显式接收 orientType；非法类型抛出 FormatException，所有实际消费者已更新。
- Mock 保存校验当前类型对应的今日记录字段；其他业务字段、未知扩展值和 bodyContent 往返规则保持。

## 验证

在 example 包执行：

```sh
dart format lib/daily_guidance/guidance_record_fields.dart lib/daily_guidance/guidance_api.dart test/daily_guidance/guidance_record_fields_test.dart test/daily_guidance/body_content_api_test.dart
flutter analyze --no-pub lib/daily_guidance/guidance_record_fields.dart lib/daily_guidance/guidance_api.dart test/daily_guidance/guidance_record_fields_test.dart test/daily_guidance/body_content_api_test.dart
flutter test --no-pub test/daily_guidance/guidance_record_fields_test.dart test/daily_guidance/body_content_api_test.dart --reporter expanded
```

结果：静态分析无问题；两份目标测试共 19 项全部通过。根目录 git diff --check 通过。

证据：[静态分析日志](analyze.log)、[测试日志](test.log)。

覆盖真实样例、ORIENT/RESULT 保存与清空、另一类型值保留、完整正文不变、聚合顺序、空标记、跨栏目引用去重、标记自检/自定义栏目、非法类型，以及页面编辑、失败重试、预览/会话隔离等既有回归。首轮发现的旧栏目排除预期与字段键集合断言已按新契约更新，最终复验通过。

## 未验证范围

未连接真实后台，未执行真机验证或全仓测试；本轮未修改 UI 或块结构，不涉及新的块协议适配。
