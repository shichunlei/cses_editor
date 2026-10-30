# 今日记录另一类型字段显式置空

日期：2026-10-30。

## 当前契约

- ORIENT：dailyOrientContent 为今日记录正文对象，dailyResultContent 显式为 null。
- RESULT：dailyResultContent 为今日记录正文对象，dailyOrientContent 显式为 null。
- 每次提取均输出两个 key，完整记录合并提交会覆盖另一类型的旧值，不能仅省略字段。
- help/pilot 继续保留于原栏目并独立聚合；正文、其他业务字段和 SaaS 不在本次调整范围。

本契约取代前一轮验证记录中“另一类型字段保留来源值”的规则。测试为两种类型预置了另一类型非空旧值，并验证正常保存、清空后保存以及页面实际请求均显式置空。

## 验证

在 example 包格式化受影响 Dart 文件，并执行：

```sh
flutter test --no-pub test/daily_guidance/guidance_record_fields_test.dart test/daily_guidance/body_content_api_test.dart --reporter expanded
flutter analyze --no-pub lib/daily_guidance/guidance_record_fields.dart lib/daily_guidance/guidance_api.dart test/daily_guidance/guidance_record_fields_test.dart test/daily_guidance/body_content_api_test.dart
```

目标测试 19 项全部通过；静态分析结果见 [analyze.log](analyze.log)，测试日志见 [test.log](test.log)。根目录 git diff --check 通过。

未连接真实后台或执行真机验证；不涉及 UI 与块协议修改。
