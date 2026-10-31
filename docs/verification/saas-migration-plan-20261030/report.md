# SaaS 今日导向迁移方案文档校验

日期：2026-10-30。

## 交付

新增 [完整逐文件方案](../../saas-daily-guidance-migration.md)，以 example 已提交基线 fa5ba74、原始最终提交样例及当前字段提取/提交/加载实现为依据。

明确 dailyOrient/dailyResult 命名与另一类型为 null、mentions 三字段与默认 user/联合去重、help/pilot 保留栏目并聚合、加载前拒绝不支持类型、相对路径、PRE 开关、列表传数和统一保存接口。

列出 SaaS 依赖/环境/实体/Repository/UseCase/路由/页面/素材/应用宿主/文档/测试改动，以及所有 example 来源文件的迁移或不迁移处理。

## 文档验证

- 所有现有本地 Markdown 链接可解析。
- JSON 示例可解析，代码围栏成对。
- 覆盖最终样例全部顶层字段及 mentionId/mentionName/mentionType/sortNo。
- 方案声明基线与当前 HEAD 一致。
- git diff --check 通过。
- 检查明细：[checks.json](checks.json)。

## 范围

仅新增方案、验证记录和索引；不修改 Dart、SaaS、依赖、素材、原始 JSON。未执行代码分析、测试、依赖解析或真机操作；31 项 example 基线测试仅被引用，不声称完成 SaaS 验证。本轮未提交。
