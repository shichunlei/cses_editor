# 范围与边界

本仓库是独立离线编辑器。通用能力在根包lib/，example/位于包根目录下并通过path: ..引用根包；今日导向属于 example/lib/daily_guidance 的宿主业务，不独立成包。
禁止引入原协同包、Common SDK、Rust/FRB/Yrs、协同数据库或外部工作区路径依赖。appflowy_editor仅从https://github.com/shichunlei/appflowy-editor.git按固定提交引入，来源、许可证和兼容补丁在该仓库维护；不得恢复packages布局或本地AppFlowy源码副本。

新增/修改Dart声明使用///说明职责、每个参数、异步与资源所有权；公开复用类型提供最小用例。跨目录使用当前包package精确import，跨包仅通过公开入口。
不手改生成文件；不使用ListTile系列，使用Row及既有公共菜单/开关行；仅开关本体触发切换。核心展示图标使用lucide_icons_flutter。
业务资源由宿主注入，禁止进程级账号或服务兜底；迟到异步结果校验页面、会话和文档身份。创建者释放Controller、订阅、定时器和客户端。

修改后格式化手写文件，在所属包分析并运行目标测试。公开API变更同时验证消费者，完成前git diff --check。验证记录归档docs/verification/<功能>-YYYYMMDD并更新索引。
块协议变更前查询桌面配置仓库的@ccc/blockcraft latest，核对声明/锁定/安装版及随包技能、迁移和实现，并更新docs/block-adaptation.md；查询失败明确待核对。
提交信息用中文。保留其他工作区修改，不因维护fork而批量清理上游代码。
