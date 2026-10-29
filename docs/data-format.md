# 数据格式与存储

通用编辑器使用 AppFlowy 文档 JSON；今日导向业务草稿由 `JournalDraft` 封装。
当前沿用既有 v2 草稿和旧三栏迁移逻辑，不因项目改名重命名持久化节点/属性键。

业务草稿包含文档身份、日期、创建/更新时间、时区偏移、正文JSON和桌面块身份映射。
`JournalDraft.fromJson`负责校验；非法数据抛错，不以新空白草稿覆盖失败记录。

`FileJournalStore`按宿主给定分区生成文件名，写入沿用临时文件与替换流程，旧格式升级保留备份。
编辑去抖保存默认500毫秒；关闭时等待未完成保存，保存失败页面保留内容并允许重试。

桌面JSON使用通用 `BlockCraftJsonCodec` 和业务 `JournalBlockCraftCodec` 双向转换。
导出捕获已完成事务的实时正文；导入创建独立草稿，不覆盖来源文件和当前草稿。
JSON转换不建立协同连接，也不据业务对象创建任务、会议或通知。

新示例具有独立应用ID和存储目录，因此不会自动读取原App私有目录。跨App迁移应通过用户选择的文件或宿主明确提供的迁移流程。

本轮以迁入的虚构 JSON 样例验证旧草稿及桌面JSON兼容；不读取用户真实草稿，不宣称覆盖所有桌面高级块行为。

## 普通宿主文件模板

普通编辑接入见[完整接入说明](integration.md)与[独立文件实现](integration_app/lib/offline_document.dart)。该模板用自身schemaVersion=1封装完整AppFlowy文档JSON，不依赖JournalDraft；它与今日导向v2、桌面JSON是不同格式，不能按版本号互相推断。宿主负责自己的版本迁移、分区、容量与恢复策略。
