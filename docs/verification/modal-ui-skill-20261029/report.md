# 项目 UI skill 与开发规范接入

日期：2026-10-29。

## 改动

项目 skill 位于 `.agents/skills/cses_editor_ui/`，名称为 `cses_editor_ui`，保持隐式调用配置。

- 根 `AGENTS.md` 要求根包及 example 的 Flutter UI 新增、修改和审查先读取 skill。
- 规范包含公共弹窗、菜单/开关行、危险操作、固定头尾、键盘安全区、Lucide 图标和编辑会话规则。
- 明确根包与 example 的职责及精确 package import；宿主不能通过根包 src 复用内部组件。普通页面保留今日导向纸张、封面及栏目风格。
- 场景参考只列本项目入口和可用测试，保留实例注入、只读及迟到结果校验要求。
- 移除 skill 及相关说明中的来源叙述，同步目录、名称、展示名称和项目引用。
- 未修改 Dart、公开 API、块协议、依赖或既有 UI 实现，保留其他工作区修改。

## 验证

- YAML、元数据及路径检查：通过；名称与目录均为用户指定的 `cses_editor_ui`，隐式调用开启，Markdown 相对链接有效。
- 旧 skill 名称及来源叙述检查：通过。
- `git diff --check`：通过。

本轮只有 skill/文档修改，未运行 Flutter 分析、Widget 测试、截图及设备验收。
