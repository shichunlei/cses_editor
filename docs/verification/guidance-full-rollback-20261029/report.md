# 回滚到 mock 数据接入之前

日期：2026-10-29（Asia/Shanghai）。

按用户要求继续回滚本聊天中的 mock/API/模板兼容修改，恢复添加 mock 数据前的代码版本。

- 还原首页单入口、本地草稿加载/自动保存、JSON 文件导入导出及原页面与集成测试。
- 删除新增的 mock API、数据加载器、相关测试，撤回 dailyTag 新增兼容和对应文档。
- 撤销之前各轮验证目录，仅保留本轮回滚验证记录。
- 14 个已修改的受跟踪源码/说明文件按最初工作区基线（HEAD）恢复；没有执行整个工作区重置。
- 保留用户的 `example/moke.json` 与 `example/日成果-2026-10-23-完整文档结构.json` 及其暂存状态，两份文件内容哈希在回滚前后相同。

## 验证

- [回滚范围与用户文件保护](preservation.json)
- [手写文件格式检查](format.txt)
- [根包分析](core-analysis.txt)、[example 分析](example-analysis.txt)
- [核心 JSON 目标测试](core-tests.txt)、[example 全量测试](example-tests.txt)
- [git diff --check](diff-check.txt)

未重新安装手机应用。
