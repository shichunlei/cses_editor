# 会议和任务行内引用的卡片切换配置

`EditorConfiguration` 并列提供 `showMeetingMentionCardAction` 和 `showTaskMentionCardAction`。会议默认开启，任务默认关闭。弹窗展示入口以及退场后执行转换时均通过 `allowsMentionCardAction` 查询当前会话。文档引用没有对应转换。SaaS 在 `journalConfiguration` 同时关闭两项，导入文档继承该配置。

- 配置用例覆盖默认值、宿主继承、分别覆盖、两项关闭及文档引用。
- 编辑器菜单用例覆盖只开会议、只开任务、两项关闭，并验证显式开启的任务引用可转成卡片后撤销。SaaS 用例检查普通与导入配置，以及重开记录后会议、任务详情入口仍可用。
- 两个仓库的 `git diff --check` 通过。执行环境限制 Flutter SDK 缓存写入，格式化、静态分析和目标测试在 SDK 初始化时中止。真机菜单待验收。
