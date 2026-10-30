# 最终提交结构与今日记录字段名校正

日期：2026-10-30。

## 最终契约

以 example/文档完整数据结构.json 为最终提交字段结构基准。

- ORIENT：dailyOrient 为实时今日记录，dailyResult 显式为 null。
- RESULT：dailyResult 为实时今日记录，dailyOrient 显式为 null。
- 不再派生 dailyOrientContent / dailyResultContent；它们是此前错误命名。
- 覆盖样例已有的今日记录字段，不增加新的 Content 后缀字段；样例的摘要值根据实时正文重算。
- help/pilot 保留原栏目并聚合，mentions 携带 mentionId/mentionName/mentionType，缺失类型按 user，并按类型和 ID 联合去重。
- Mock 取消两个今日记录字段必须同时为 Map 的旧校验，改为当前类型为 Map、另一类型存在且为 null。

新增最终结构回归测试：完整保存后顶层键集合与样例一致、内容对象及 mentions 结构正确、聚合 sortNo 正确、bodyContent 不变。两种类型和清空回归均更新到正确字段名。

本轮未修改原始样例 JSON；其已有改动保持原样。未修改 SaaS、UI 或块协议。历史验证记录中的 Content 后缀字段名以本记录和当前数据格式文档为准。

## 验证

格式化四个受影响 Dart 文件；在 example 包执行：

```sh
flutter test --no-pub test/daily_guidance/guidance_record_fields_test.dart test/daily_guidance/body_content_api_test.dart --reporter expanded
flutter analyze --no-pub lib/daily_guidance/guidance_record_fields.dart lib/daily_guidance/guidance_api.dart test/daily_guidance/guidance_record_fields_test.dart test/daily_guidance/body_content_api_test.dart
```

26 项目标测试全部通过：[test.log](test.log)。静态分析无问题：[analyze.log](analyze.log)。

检索 example/lib、example/test、docs/data-format.md，无错误字段名残留。git diff --check 通过。

未连接真实后台、执行真机或全仓测试。
