# 派生引用类型与联合去重

日期：2026-10-30。

## 范围与行为

仅修改 example 的业务字段提取器、对应测试及协议文档，不迁移 SaaS，不修改块协议或 UI。

- 派生 mentions 输出 mentionId、mentionName、mentionType，支持 user/task/meeting/doc。
- 从引用片段 attributes.mentionType 读取类型，兼容 d:mentionType；旧正文缺失时按 user。
- 每个栏目/聚合条目按 (mentionType, mentionId) 联合去重，保留首次名称及出现顺序；同 ID 不同类型分别保留。
- help/pilot 在原栏目及聚合数组中的引用类型一致；两种今日记录字段与空值规则不变。
- 非法类型拒绝派生；不修改输入正文，返回的引用对象由输出独占。
- 任务、会议、文档类型不会被转换成人员；手输 @文本仍不推断实体身份。

开始时工作区已有原始样例 JSON 的 mentionType 补充，本轮保留未修改；测试以当前样例执行。

## 验证

在 example 包执行格式化及以下检查：

```sh
flutter test --no-pub test/daily_guidance/guidance_record_fields_test.dart test/daily_guidance/body_content_api_test.dart --reporter expanded
flutter analyze --no-pub lib/daily_guidance/guidance_record_fields.dart test/daily_guidance/guidance_record_fields_test.dart test/daily_guidance/body_content_api_test.dart
```

25 项目标测试全部通过，包含四种类型在所有派生字段/聚合中的保留、同类型同 ID 去重、跨类型同 ID 不合并、旧类型默认值及显式 user 合并、命名空间兼容、旧正文完整保存和非法类型。

静态分析无问题，证据：[analyze.log](analyze.log)。测试证据：[test.log](test.log)。根目录 git diff --check 通过。

未连接真实后台、运行真机或全仓测试；本轮不修改正文块协议。
