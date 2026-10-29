# 数据格式与存储

通用编辑器使用 AppFlowy 文档 JSON；今日导向业务草稿由 `JournalDraft` 封装。
当前沿用既有 v2 草稿和旧三栏迁移逻辑，不因项目改名重命名持久化节点/属性键。

业务草稿包含文档身份、日期、创建/更新时间、时区偏移、正文JSON和桌面块身份映射。
`JournalDraft.fromJson`负责校验；非法数据抛错，不以新空白草稿覆盖失败记录。

`FileJournalStore`按宿主给定分区生成文件名，写入沿用临时文件与替换流程，旧格式升级保留备份。
编辑去抖保存默认500毫秒；关闭时等待未完成保存，保存失败页面保留内容并允许重试。

桌面JSON使用通用 `BlockCraftJsonCodec` 和业务 `JournalBlockCraftCodec` 双向转换。
既有编解码器仍可用于 JSON 转换回归；示例头部不再提供文件导入导出。
JSON转换不建立协同连接，也不据业务对象创建任务、会议或通知。

新示例具有独立应用ID和存储目录，因此不会自动读取原App私有目录。跨App迁移应通过用户选择的文件或宿主明确提供的迁移流程。

本轮以迁入的虚构 JSON 样例验证旧草稿及桌面JSON兼容；不读取用户真实草稿，不宣称覆盖所有桌面高级块行为。

## 普通宿主文件模板

普通编辑接入见[完整接入说明](integration.md)与[独立文件实现](integration_app/lib/offline_document.dart)。该模板用自身schemaVersion=1封装完整AppFlowy文档JSON，不依赖JournalDraft；它与今日导向v2、桌面JSON是不同格式，不能按版本号互相推断。宿主负责自己的版本迁移、分区、容量与恢复策略。

## 服务正文接入

宿主通过 `GuidanceApi.fetch(recordId)` 获取数据，只使用 `id` 做身份核验、`orientType` 选择头部标题、`bodyContent` 作为编辑内容；不处理其他业务字段。ORIENT 显示“今日导向”，RESULT 显示“今日成果”，未知类型拒绝加载。

`BodyContentCodec` 将日成果模板的 daily-cover/daily-body 可编辑节点投影到原“今日记录”栏目，reflection/self-check 投影到“感悟/自检”，custom 以稳定 key 呈现原名称。锁定模板标题及日期容器保留在来源模板中，页面继续使用原封面、日期、横格和键盘菜单，不进入普通桌面文档渲染模式。日记配置仅扩展已有自定义栏目及原生实体引用的业务校验。

原区域、块身份、props/meta 和未编辑节点保留；help/pilot 的 dailyTag 前缀转换为原有业务行，保存时还原；人员与任务等引用不混淆。未知块/标签或无法安全编辑的锁定正文拒绝加载，不以空白或丢字段代替。

点击保存捕获实时正文，经 `BodyContentCodec.encode` 还原原始嵌套根快照，提交 `{"bodyContent": ...}`。不套 JournalDraft，不生成 dailyResult/thinking/helpItems 等摘要，也不向接口泄露本地来源属性。API 模式不在输入、切后台或资源销毁时自动提交。退出有修改时提供继续编辑、保存后离开和放弃修改。

栏目关闭继续保留正文，使用可选 `bodyContent.meta.mobileGuidanceView.hiddenSections` 数组记录隐藏的 reflection/self-check，重开可恢复；重新添加后清除视图扩展。自定义栏目本轮只支持已有字段编辑，未增加菜单入口或移除其内容。

mock 实现是当前宿主拥有的内存接口替身，不是真实 HTTP 服务器。重开页面读取已保存正文，应用重启重置为原 文档完整数据结构.json；真实接口地址、请求方法及鉴权由宿主的 GuidanceApi 实现决定。


## 固定编辑与预览模式

模式由宿主导航字段 `JournalPageMode.edit/preview` 决定，不属于 bodyContent 或保存请求。编辑页保留原工具栏与显式保存；预览页直接创建只读会话，沿用相同纸张和内容展示，没有页内切换按钮。只读控制器拒绝正文事务、日期更新及 flush 写入，自动保存被强制关闭；返回或销毁只释放资源。改变同一页面实例的模式会撤销旧会话，须从首页重新进入。
