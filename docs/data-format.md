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

宿主通过 `GuidanceApi.fetch(recordId)` 获取数据，以 `id` 做身份核验、`orientType` 选择头部标题、`bodyContent` 作为编辑内容，同时保留完整记录快照供保存使用。ORIENT 显示“今日导向”，RESULT 显示“今日成果”，未知类型拒绝加载。

`BodyContentCodec` 将日成果模板的 daily-cover/daily-body 可编辑节点投影到原“今日记录”栏目，reflection/self-check 投影到“感悟/自检”，custom 以稳定 key 呈现原名称。锁定模板标题及日期容器保留在来源模板中，页面继续使用原封面、日期、横格和键盘菜单，不进入普通桌面文档渲染模式。日记配置仅扩展已有自定义栏目及原生实体引用的业务校验。

编辑会话创建前，`BodyContentCodec.decode` 校验可编辑正文的引用类型（包括隐藏栏目），与字段派生共用类型规则。遇到 `department` 等不支持类型时，页面明确显示类型及支持范围，不分配编辑器、不提交、不覆盖原记录；后台修正后可重试加载。缺少类型仍按 `user`。

原区域、块身份、props/meta 和未编辑节点保留；help/pilot 的 dailyTag 前缀转换为原有业务行，保存时还原；人员与任务等引用不混淆。未知块/标签或无法安全编辑的锁定正文拒绝加载，不以空白或丢字段代替。

`example/文档完整数据结构.json` 是最终提交的字段结构基准，今日记录使用 `dailyOrient` / `dailyResult`；其具体值由实时正文重新派生，非当前类型显式置 null，不以样例中的历史摘要或空对象作为保存值。

点击保存捕获实时正文，经 `BodyContentCodec.encode` 还原原始嵌套根快照，由 `GuidanceRecordFields.extract(body, orientType: record['orientType'])` 从同一份正文派生字段，然后覆盖读取到的完整记录中的 `bodyContent`、`dailyOrient`、`dailyResult`、`thinking`、`selfCheck`、`helpItems`、`navigatorItems`、`customData`，一次提交完整记录（保留 `example/文档完整数据结构.json` 的全部原字段，重算已有今日记录字段，非当前类型显式为 null）。`id`、`bizType`、`orientType`、`todoContent`、`expectedEffectContent` 及未知扩展字段保留读取值。不套 JournalDraft，也不向接口泄露本地来源属性。读取成功前拒绝保存。

派生规则：`dailySlot=daily-cover/daily-body` 的可编辑正文合并为今日记录（同样支持 `dailySection=record`），`orientType=ORIENT` 派生 `dailyOrient`，`orientType=RESULT` 派生 `dailyResult`；另一类型字段显式设为 `null`，覆盖来源记录中的旧值；非法类型拒绝提取。锁定模板标题不计入今日记录。`dailySection=reflection/self-check` 对应感悟/自检；`dailySection=custom` 以 `dailyCustomField.key` 作为 `customData` 的稳定键。每个字段为 `{content, mentions}`，包括 number 类型的自定义字段也保持字符串内容。help/pilot 前缀段落仍完整进入所属栏目的摘要（含今日记录、感悟、自检和自定义栏目），同时按全篇出现顺序分别聚合到 `helpItems` / `navigatorItems`，每条附加从 1 开始的 `sortNo`；空标签段落不生成条目。锁定模板节点和非文本对象不进入摘要。

段内按序连接文本，段间以 `\n` 分隔，保留段内空格和中间空行，仅删除末尾空白段落。结构化 mention 输出 `@名称`，从 attributes 的 `mentionId`（兼容 `d:mentionId`）生成 `{mentionId, mentionName, mentionType}`，引用类型读取 `mentionType`（兼容 `d:mentionType`），缺失时默认为 `user`，仅接受 `user/task/meeting/doc`，非法类型拒绝派生；每个字段/条目内按 `mentionType + mentionId` 联合去重，保持首次出现顺序，普通手输 `@名字` 不推测身份。当前类型的今日记录及其余派生字段每次全量重算，清空内容或移除字段时提交空串、空数组或删除后的 customData，避免残留旧摘要及引用。API 模式不在输入、切后台或资源销毁时自动提交。退出有修改时提供继续编辑、保存后离开和放弃修改。

栏目关闭继续保留正文，使用可选 `bodyContent.meta.mobileGuidanceView.hiddenSections` 数组记录隐藏的 reflection/self-check，重开可恢复；重新添加后清除视图扩展。自定义栏目本轮只支持已有字段编辑，未增加菜单入口或移除其内容。

mock 实现是当前宿主拥有的内存接口替身，不是真实 HTTP 服务器。重开页面读取已保存完整记录，应用重启重置为原 文档完整数据结构.json；真实接口地址、请求方法及鉴权由宿主的 GuidanceApi 实现决定。


## 固定编辑与预览模式

模式由宿主导航字段 `JournalPageMode.edit/preview` 决定，不属于 bodyContent 或保存请求。编辑页保留原工具栏与显式保存；预览页直接创建只读会话，沿用相同纸张和内容展示，没有页内切换按钮。只读控制器拒绝正文事务、日期更新及 flush 写入，自动保存被强制关闭；返回或销毁只释放资源。改变同一页面实例的模式会撤销旧会话，须从首页重新进入。
