# 今日导向迁入 SaaS：逐文件实施方案

- 修订日期：2026-11-05。
- 状态：方案，尚未实施 SaaS 迁移。
- 已提交实现基线为 `e9856a0`，涵盖当天空文档、两类入口、保存后预览、自定义栏目与保存前关闭空栏目。
- SaaS 核对基线为 `1067d9b94`，今日导向仍走现有互生入口和 `/dailyOrient/save`。
- 工作区候选为末栏剩余视口补线，涉及 `journal_surface.dart`、布局测试及 UI 约定。以完成单独评审后的提交作为该项迁移基线。
- 最终提交字段结构：[文档完整数据结构.json](../example/文档完整数据结构.json)。
- 派生实现：[guidance_record_fields.dart](../example/lib/daily_guidance/guidance_record_fields.dart)。
- 提交实现：[guidance_api.dart](../example/lib/daily_guidance/guidance_api.dart)。
- 加载实现：[body_content_codec.dart](../example/lib/daily_guidance/body_content_codec.dart)。
- 当前有效协议：[data-format.md](data-format.md)。历史讨论或验证记录与本文冲突时，以用户最终要求、样例字段结构和基线实现为准。

本文用于安排后续迁移。当前交付为方案与文档校验记录。

## 1. 范围与固定决策

1. 今日导向/成果业务迁入 SaaS 现有互生子域，通用编辑能力依赖 `cses_editor` 根包。不得依赖 example 包，不将业务移入编辑器根包，不新拆业务包。
2. SaaS 通过相对路径 `../../cses_editor` 接入根包。AppFlowy 依赖先完成第 4 节的来源核对，再用于 SaaS 构建与验收。
3. 列表返回完整数据。打开已有记录时传入独立记录快照，不新增详情接口；同一列表外壳中的 orient/result 分别取对应业务记录。
4. 创建、修改共用现有 `/dailyOrient/save`。创建不带 `id`，修改带后台正式 `id`，本地草稿 ID 不得作为后台 ID。
5. 环境配置增加版本开关：PRE 未显式配置时默认新版，其他环境默认旧版；显式选择优先。
6. 旧版继续用原字段和原页面。新版只用 `bodyContent` 恢复和展示正文，保存时同时更新兼容字段；新版不读取旧摘要来补正文。
7. 新版迁入完整记录派生、引用前置校验和显式保存。顶栏保存成功在同一会话进入只读预览，确认保存后离开则提交成功并返回。
8. 新建由 SaaS 宿主确定类型、日期和业务身份，复用空文档构造。已有记录从列表快照打开，新建与修改共享编码和保存适配。
9. 不恢复原协同包、Common SDK 对编辑器根包的反向依赖、Rust/FRB/Yrs 或协同数据库。SaaS 既有服务只在宿主适配层使用，并显式注入。

### 本轮业务差异与迁移安排

| 变化 | 迁移安排 |
|---|---|
| 当天空白文档、导向与成果入口 | 复用空记录构造，接入 SaaS 现有创建入口。示例首页的内存 Mock 与演示开关留作测试参考 |
| 保存成功进入预览 | 合并到编辑保存主流程。保存后由同一个控制器冻结，列表刷新依赖业务成功事件 |
| 自定义栏目与空栏目处理 | 将新增、手动关闭、恢复、批量保存清理与正文 Codec 一起迁入，避免页面能编辑但无法提交或重开 |
| 领航员与都来帮 | 迁入先创建业务行、再选人、取消保留的事务顺序 |
| 固定封面、横格及分享 | 已提交的布局、焦点避让和最小一屏 PNG 进入首版验收。末栏补线工作区版本单独验收 |
| AppFlowy 依赖来源 | 已提交基线使用本机路径，当前工作区已恢复固定 Git 来源。以该来源完成 SaaS 干净环境验收 |

空白入口与类型规则见[双类型入口验证](verification/guidance-type-entry-20261105/report.md)。保存状态转换、清理与分享分别见[保存后预览](verification/save-to-preview-20261103/report.md)、[空栏目关闭](verification/save-close-empty-sections-20261105/report.md)和[分享一屏](verification/share-minimum-screen-20261105/report.md)。

### 工作区定位

| 标识 | 绝对目录 |
|---|---|
| 编辑器仓库 E | `/System/Volumes/Data/workspace/cses_editor` |
| 示例来源 S | `/System/Volumes/Data/workspace/cses_editor/example/lib/daily_guidance` |
| SaaS 仓库 A | `/System/Volumes/Data/workspace/cses/cses.saas` |
| 互生模块 M | `/System/Volumes/Data/workspace/cses/cses.saas/lib/modules/mutualism` |
| 新页面目录 J | `/System/Volumes/Data/workspace/cses/cses.saas/lib/modules/mutualism/presentation/orient_result/journal` |
| 应用宿主 H | `/System/Volumes/Data/workspace/cses/cses.jqdl` |

后文使用这些标识表示文件路径；标注“新增”的文件尚不存在。实际实施前复查目标分支和未提交改动，保留无关修改。

## 2. 最终请求结构与映射

### 2.1 字段契约

样例规定字段结构，当前记录类型、标题与摘要值由实时正文和页面上下文生成。样例是历史数据，包含旧空对象及不同步的类型元数据。验收以非当前类型字段显式为 null、标记内容保留原栏目，以及新建记录的类型与正文元数据一致为准。

| 顶层字段 | 新版取值与处理 |
|---|---|
| `id` | 修改取正式记录 ID；创建时整个 key 省略，不传 null、空串或临时 ID |
| `bizType` | 修改保留合法来源值。新版创建按当前 example 对两类均使用 `DAILY_ORIENT`，用 `orientType` 区分导向和成果。SaaS 旧版成果仍使用 `DAILY_RESULT`，新版成果开放前在 PRE 验证实际路由及落库结果 |
| `orientType` | 固定为当前记录的 `ORIENT` / `RESULT`；非法类型拒绝加载 |
| `todoContent` | 修改保留来源值；创建按现有接口空内容结构初始化 |
| `expectedEffectContent` | 修改保留来源值；创建按现有接口空内容结构初始化 |
| `dailyOrient` | ORIENT：今日记录内容对象；RESULT：显式 `null` |
| `dailyResult` | RESULT：今日记录内容对象；ORIENT：显式 `null` |
| `thinking` | 感悟栏目的完整派生内容对象 |
| `selfCheck` | 自检栏目的完整派生内容对象 |
| `helpItems` | 全文 help 标记段落的独立聚合数组 |
| `navigatorItems` | 全文 pilot 标记段落的独立聚合数组 |
| `customData` | 以自定义字段稳定 key 为键、内容对象为值的 Map |
| `bodyContent` | 完整正文根快照：`id/flavour/nodeType/props/meta/children` |
| 来源中已有未知业务扩展 | 保持深拷贝值；不加入列表响应外壳、成功标志、分页或 UI 状态 |

新版禁止新增错误字段 `dailyOrientContent` / `dailyResultContent`。SaaS 旧链路中已有同名内部模型/请求只在旧版适配中维护，不得泄漏进新版请求。旧版现有 `contentSnapshot` 处理也不能被机械复制为新版新增字段。

### 2.2 栏目与聚合映射

| 正文来源 | 原栏目派生 | 额外聚合 |
|---|---|---|
| `dailySlot=daily-cover/daily-body` 的可编辑内容 | 按文档顺序合并至当前类型的 `dailyOrient` 或 `dailyResult` | help/pilot 同时聚合 |
| `dailySection=record` | 同样作为今日记录 | help/pilot 同时聚合 |
| `dailySection=reflection` | `thinking`，包含其中的 help/pilot | help/pilot 同时聚合 |
| `dailySection=self-check` | `selfCheck`，包含其中的 help/pilot | help/pilot 同时聚合 |
| `dailySection=custom` | `customData[dailyCustomField.key]`，包含其中的 help/pilot | help/pilot 同时聚合 |
| 所有 help 标记段落 | 不从所属栏目移除 | `helpItems` |
| 所有 pilot 标记段落 | 不从所属栏目移除 | `navigatorItems` |

- 聚合只增加结果，不移动正文、不改变栏目归属、不对重复出现的段落做全局合并。
- 每个聚合数组独立生成从 1 开始的 `sortNo`，保持文档顺序。只有标记但无实际内容的段落不生成条目。
- 跳过不参与派生的锁定模板节点；封面模板标题不进入今日记录。
- 段内按序连接实际文本，段间保留换行，保留段内空格及中间空行，只去除末尾空白段落。不把界面标签添加成正文。
- 格式、块属性及非文本对象的完整结构保留在 `bodyContent`；派生摘要仅按现有提取器支持的文字与引用输出，不另造附件摘要规则。
- 隐藏栏目保留正文并参与派生。保存前自动关闭的空栏目继续提交空摘要以清除旧值，保留 `hiddenSections` 及恢复所需结构。已删除的自定义栏目从 `customData` 移除。
- 当前类型空内容输出 `{"content":"","mentions":[]}`；另一类型仍输出 null；空聚合输出 `[]`；不存在的自定义栏目不保留旧摘要。
- 数字型自定义字段仍输出字符串 content，不改变样例数据类型。
- 不按照旧 UI 的字数/条数限制静默截断。后端限制必须实测后形成一致约束。

### 2.3 mentions 契约

所有新派生内容对象中的 mentions 元素为：

```json
{
  "mentionId": "entity-id",
  "mentionName": "显示名称",
  "mentionType": "user"
}
```

1. `mentionType` 只允许 `user/task/meeting/doc`。旧引用缺失（或普通字段、命名空间字段均为 null）时默认 `user`，新版输出显式携带类型。
2. 正文读取 `attributes.mentionId/mentionType`，兼容 `d:mentionId/d:mentionType`。
3. 每个字段/聚合条目按 `(mentionType, mentionId)` 联合去重，保持第一次出现的名称及顺序。同 ID 的不同类型分别保留。
4. 文字中的每次引用仍输出 `@名称`；去重只作用于 mentions 数组，不删除正文中的重复引用。
5. 普通手输 `@名字` 不推断实体身份；不得把任务、会议、文档强制转换为用户。
6. `department`、未知类型、空字符串或其他错误类型不能被当作缺失值降级；加载前明确拒绝，不能让用户编辑后才发现无法保存。
7. 加载和保存复用同一校验函数；锁定模板的排除规则一致，隐藏正文也必须检查。
8. 新版重算字段均按此规则输出；保留型业务字段维持来源，不以本次迁移静默改写未知业务数据。

示例：RESULT 的感悟中含一条 help 段落时，内容同时进入 thinking 与 helpItems；dailyOrient 为 null，dailyResult 取今日记录，不能把感悟内容误写入今日记录。

## 3. 读取、创建、保存和返回流程

### 已有记录

1. 从列表适配层取出当前 orient/result 的完整业务记录，深拷贝为页面快照；正式 ID 与聚合行 ID 分开。
2. 固定版本和初始入口模式，记录账号、企业、文档及路由实例身份。编辑入口允许在成功保存后单向进入预览。
3. 校验 ID、orientType、bodyContent 结构，再执行 `validateMentionTypes`。失败展示具体类型及支持范围，不创建编辑器、不缓存可写来源、不发请求覆盖记录。
4. `BodyContentCodec.decode` 创建日记草稿，页面创建唯一正文会话。
5. 结束输入合成，执行一次可撤销的空可选栏目关闭事务，再捕获独立快照。调用 Codec 生成 bodyContent，从同一正文派生字段。
6. 合并到完整来源记录，覆盖所有派生字段及显式 null；调用现有保存用例。
7. 业务成功后确认保存修订和正式记录，顶栏保存使原页面和控制器进入只读预览，关闭键盘与编辑动作。确认保存后离开直接返回结果。失败保留编辑、撤销和重试能力。
8. 响应完整则更新当前记录；响应不完整则刷新原列表，不补造详情接口。

### 新建记录

1. 迁入 `createEmptyGuidanceRecord(now, orientType: ...)` 的构造逻辑，生成 `daily-writing` v5 根节点和一个空填写区。宿主注入日期、类型和会话身份，类型同步到 `orientType`、`meta.dailyType`、标题和两个派生字段。
2. SaaS 新建会话将模板和块身份与后台正式 ID 分离。示例 Mock 使用的顶层临时 ID 只用于本地关联，序列化创建请求时省略顶层 `id`。日期沿用 `meta.dailyDate`，新建时使用宿主确定的业务日。
3. 用待创建状态明确驱动首次显式提交。即使空白内容没有产生编辑修订，点保存也应按新建流程实际请求一次。example 的空白保存用例直接写 Store，SaaS 需增加真实页面点击保存到收到 ID 的验证。
4. 首次成功接收并固化正式 ID，再冻结为预览或返回。随后从 SaaS 编辑入口重开才按修改提交，携带已保存的正式 ID。创建在途复用同一请求，失败保留待创建态与内容。
5. 对响应丢失或业务成功但 ID 缺失的情形，按已有幂等或列表对账能力恢复身份后再允许下一次写入。PRE 联调确认新建两类的 `bizType`、响应 ID 与必需基础字段。

### 编辑事务与布局

| 场景 | 业务规则 |
|---|---|
| 新增与关闭栏目 | 自定义名称先 trim，长度 1–40，独立稳定 key。关闭可选栏目保留草稿，隐藏区与可见正文共同校验容量及身份。恢复时使用原 key 和内容，手动关闭不把焦点跳到其他栏目 |
| 显式保存清理 | 仅顶栏保存或确认保存后离开时执行。首栏、非空正文、待办、提及、人员业务行和非文字块保留。多个空感悟、自检和自定义栏目合为一次可撤销事务。失败仍可编辑、撤销或重试 |
| 都来帮和领航员 | 点击先创建独立业务行，再选人。取消保留空业务行，选中回填原行。创建和回填分别可撤销。空业务行留在正文，空值不产生聚合条目 |
| 沉浸式编辑与预览 | 复用固定封面与共享正文滚动。键盘及菜单变化后校正被遮挡的焦点行，编辑与预览使用一致的栏目间距 |
| 分享 | 从只读会话捕获全文独立快照，纸张最小高度为当前逻辑屏幕高度，短文补足横格，长文自然增长，保留品牌页脚与现有图片操作端口 |
| 末栏补线候选 | 末个可见栏目承接剩余正文视口，前置栏目按自然高度排版，保留根滚动索引。帧后测量按文档根和栏目身份隔离。该项在工作区版本通过单独验收后并入 |

### 旧版与版本切换

- 旧版保持原有读取、编辑和提交行为；新版渲染、复制及分享以 bodyContent 为来源。
- 新版不因 bodyContent 缺失自动回退旧字段。旧版编辑已有新版记录后，后台必须同步/标记 bodyContent 的有效性，否则新版可能读取旧正文；环境开关本身不能解决此问题。
- 页面存活期间固定新旧版本，已保存的新版编辑会话可转入只读预览。切换设置后更新列表及后续打开的页面。

## 4. 逐文件：依赖、配置与应用宿主

| 文件 | 动作与改动点 |
|---|---|
| A/pubspec.yaml | 增加 `cses_editor: path: ../../cses_editor`；显式声明宿主直接使用的 AppFlowy、Provider、Lucide 等依赖；复用已存在的文件选择、分享等依赖，按直接 import 补齐而非整体复制 example |
| A/pubspec.lock | 由依赖工具生成更新，不手改 |
| A/lib/global/keys.dart | 增加新版今日导向设置 key，不复用其他灰度开关 |
| A/lib/modules/dashboard/presentation/env/environment_toggle.dart | 增加版本开关声明，说明同时影响导向和成果；在现有声明式机制中补齐该开关的环境默认与存储范围能力，不改变其他配置语义 |
| A/lib/modules/dashboard/presentation/env/logic.dart | 显式配置优先；PRE 默认 true，其余 false；存储按设备和环境隔离。切环境时重新解析对应环境的临时/保存值，不把当前环境的值写入其他环境 |
| A/lib/modules/dashboard/presentation/env/page.dart | 复用现有开关行，只有开关本体触发；保存成功后发布必要的设置变更通知 |
| A/lib/shared/presentation/settings/daily_guidance_editor_settings.dart（新增） | 单一版本解析策略及 key/default 规则，参数化接收环境和设置值，供环境页、互生导航和展示消费；避免互生反向导入 Dashboard 私有 Logic |
| H/lib/modules/app/view.dart | 在既有 GetMaterialApp 合并 AppFlowy 本地化 delegate，不新增 MaterialApp 或协同初始化 |
| A/assets/daily_guidance/（新增素材目录） | 迁入封面与品牌图片，并同步页面、预加载及分享页路径；保留米色纸张与品牌底色处理 |

### 依赖前置核对

- 已提交基线 `e9856a0` 的 E/pubspec.yaml 使用 `../appflowy-editor`。本次核对结束时，工作区声明已改回 E/AGENTS.md 要求的 Git 来源 `https://github.com/shichunlei/appflowy-editor.git`，固定提交 `9e7593134457eac9193a61ee4023a75de55fcc68`。根包与 example 的锁定文件及当前解析均指向该 Git 提交。
- example 当前通过根包解析 AppFlowy。邻接 AppFlowy checkout 同为 `9e759313`，其未提交的 file_picker 和 flutter_svg 约束调整不属于 Git 基线。实施时采用固定 Git 版本验证消费者，必要依赖差异先固化到可获取的固定版本。
- 第一次 SaaS 接入验收同时核对声明、锁定和实际解析路径，并用干净构建环境验证依赖、键盘与截图。当前本地 AppFlowy 和 SaaS 的未提交改动独立保留。

## 5. 逐文件：SaaS 数据与业务边界

| 文件 | 动作与改动点 |
|---|---|
| M/domain/entity/orient_result/orient_result.dart | 当前已有 bodyContent 属性，补齐扁平/嵌套响应解析。保留完整记录快照，不能用当前只含 id/date/lastModified 的 toJson 充当完整请求。只有 bodyContent 的记录不能被“旧字段全空”逻辑过滤 |
| 同一实体文件 | 新增字段名与旧内部命名做显式适配：新版读取 dailyOrient/dailyResult；旧模型旧路径仅服务旧版。区分列表嵌套外壳 dailyOrient（整条记录）与整条记录内部 dailyOrient（内容对象），不能按同名键盲取 |
| 同一实体文件 | MentionsUser/ContentBody 补齐类型读取：旧格式 userId/userName 与新格式 mentionId/mentionName 明确兼容，缺类型默认 user，按类型+ID去重。展示/点击按类型处理，不继续把所有 ID 当用户；旧版 serializer 保持旧链路约定 |
| M/domain/entity/orient_result/daily_guidance_record_snapshot.dart（新增） | 以独立完整 JSON 值封装单条业务记录，显式区分创建/修改及正式 ID；保留扩展但不携带分页/响应外壳；不依赖 Flutter/AppFlowy/GetX |
| M/domain/repository/i_orient_result_repository.dart | 复用已有保存方法；需要扩展签名时同时验证旧消费者。不新增详情查询或单独创建接口 |
| M/infrastructure/orient_result_repository_impl.dart | 继续 `/dailyOrient/save`，不滤掉显式 null；解析业务成功与正式 ID。按已确认列表响应形态保留完整单记录，剥离响应外壳 |
| M/application/use_case/update_work_orient_use_case.dart | 复用统一保存入口，拒绝把 HTTP 完成等同业务成功；新旧请求由各自适配器构造 |
| M/application/use_case/get_orient_result_use_case.dart | 保持首页查询职责，不改造成详情接口 |
| M/application/use_case/get_orient_result_list_use_case.dart | 保持列表查询；返回值链路确保完整业务快照可达页面 |
| M/application/use_case/get_orient_result_list_for_member_use_case.dart | 同样保证个人列表记录快照不丢失正文/扩展 |
| M/application/use_case/get_orient_result_list_by_day_use_case.dart | 复核按日入口需要的完整记录来源；不为页面临时补详情接口 |

新增 snapshot 的目的为防止目前旧实体简略序列化丢数据，不是再维护第二份可变正文。正文仍仅由日记控制器持有。

## 6. 逐文件：从 example 迁入业务源码

以下来源为 S，目标为 J。保留 example 的独立可运行示例，不删除来源。公共能力仍只从 `package:cses_editor/cses_editor.dart` 等真实公开入口导入。

| 来源 | 目标 | 迁移处理 |
|---|---|---|
| local_journal_page.dart | page.dart | LocalJournalPage 改为 DailyGuidancePage。接入完整快照与配置，迁入保存前清理、同页只读预览、确认保存离开、错误重试与固定封面。版本及保存策略由配置提供 |
| local_journal_controller.dart | editor/journal_controller.dart | LocalJournalController 改为 JournalController。迁入自定义栏目、关闭与恢复、空栏目批处理、业务行先建后填、只读转换和修订保护。控制器继续独占正文 |
| journal_draft.dart | editor/journal_draft.dart | 迁入可见和隐藏栏目身份、重复键、共用容量校验及编辑配置。依赖 AppFlowy，留在展示层 |
| journal_store.dart | editor/journal_store.dart | 保留 read/write 会话端口，读取失败不创建替代记录；异步写成功才确认保存 |
| guidance_api.dart | editor/api_journal_store.dart | 从列表快照恢复，保存调用注入的统一用例，维护待创建态和正式 ID。生产日志记录请求结果与必要追踪标识，示例完整 JSON 输出用作本机联调参照 |
| empty_guidance_record.dart | editor/empty_guidance_record.dart | 复用已实现的双类型空模板构造。以宿主日期、业务类型和本地块 ID 初始化，顶层正式 ID 由 Store 管理 |
| guidance_record_fields.dart | editor/guidance_record_fields.dart | 按基线迁入字段派生、联合去重、默认类型、专用异常和加载校验；无需另建“旧字段分流器”或第二套投影算法 |
| body_content_codec.dart | editor/body_content_codec.dart | 保留加载校验、块身份、扩展及未编辑节点。编码新增自定义区域及稳定键，按 `mobileGuidanceView.hiddenSections` 往返隐藏内容和恢复状态 |
| journal_blockcraft_codec.dart | editor/journal_blockcraft_codec.dart | 保留块身份恢复、转换、复制相关依赖，首期不扩展协议 |
| journal_exchange_keys.dart | editor/journal_exchange_keys.dart | 持久化字符串不随 Dart 类名变化；不能清理 bc./guidance_ 等来源恢复信息后再保存 |
| journal_input.dart | editor/journal_input.dart | 保留原子提及、输入事务处理及容量保护 |
| journal_editing.dart | editor/journal_editing.dart | 保留格式工具栏和栏目专用编辑规则 |
| guidance_entries.dart | widgets/guidance_entries.dart | 保留业务标记和提及渲染；纯模型/解析按实际依赖拆入 editor/，不复制业务数据 |
| journal_list_markers.dart | widgets/journal_list_markers.dart | 保留编号、列表标记及布局 |
| journal_surface.dart | widgets/journal_surface.dart | 迁入固定封面、初始横格及编辑/预览/截图共享正文。保留唯一页尾。末栏剩余视口补线以候选提交和回归结果决定纳入时点 |
| journal_ruled_content.dart | widgets/journal_ruled_content.dart | 保留横格、真实文本高度及业务标签排除规则 |
| journal_ruled_text_scope.dart | widgets/journal_ruled_text_scope.dart | 与横格绘制一起迁入，标记实际正文扫描区域，保持提及、标签和输入命中语义 |
| guidance_people.dart | editor/guidance_people.dart + widgets/journal_people_picker.dart | 拆分引用模型/端口与 Widget；支持类型以提交契约为准，不允许选入随后不能保存的 department；其他业务使用的组织树不因迁移被改写 |
| mention_picker.dart | widgets/journal_mention_picker.dart（按需） | 优先复用宿主公开选人能力；保留取消、退场完成、会话失效与选区核验 |
| guidance_host.dart | adapters/journal_host_services.dart | 替换演示目录和头像；由 Binding 注入服务，不能自行查全局账号兜底 |
| journal_image_actions.dart | adapters/journal_image_actions.dart | 保留操作端口，替换 example 专用 MethodChannel，复用 SaaS 微信/朋友圈/保存能力 |
| journal_share_page.dart | share/journal_share_page.dart | 保留正文快照、图片加载等待与品牌页脚。成图最少一屏，长文自然增长，保留原像素及长图保护 |
| ui/journal_modal.dart | widgets/modal/journal_modal.dart | 保留 route.completed 后返回、局部主题与焦点约定，不私自导入根包 src/ |
| ui/journal_bottom_sheet.dart | widgets/modal/journal_bottom_sheet.dart | 保留有限高度、安全区与固定头尾 |
| ui/journal_modal_header.dart | widgets/modal/journal_modal_header.dart | 保留标题/说明/关闭行为 |

首期不迁入 `file_journal_store.dart`、`journal_json_files.dart`、示例 main、演示人员或原始记录作为线上业务数据。本地恢复和 JSON 导入导出另行评估，不混入在线保存。

### 根包联动

SaaS 通过根包版本获得以下能力，迁移清单中的业务文件仍位于互生宿主。实施时以依赖解析结果及目标测试确认能力生效。

| 根包文件 | 验收重点 |
|---|---|
| E/lib/src/editor/editor_caret_visibility.dart | 键盘或菜单遮挡折叠光标行后，在排版完成时滚动校正。换会话或路由失效时取消待处理回调 |
| E/lib/src/editor/stable_mobile_toolbar.dart | 使用实际正文视口和工具栏边界，避免重复扣减键盘高度 |
| E/lib/src/editor/editor_shortcut_toolbar.dart | 待办块光标对应一级工具栏选中态 |

### 新增宿主文件

| J 下新增文件 | 职责 |
|---|---|
| binding.dart | Repository/UseCase/服务端口/版本配置装配；按页面实例隔离，避免固定 GetX tag 覆盖 |
| logic.dart | 加载结果、权限、保存反馈、正式 ID、互动状态和业务事件；不直接 HTTP/SDK，不重复持有正文 |
| journal_page_configuration.dart | 固定入口模式、标题、版本和保存策略。运行时只读状态由控制器在保存成功后推进 |
| adapters/journal_mention_directory.dart | 将已有公开组织查询映射为真实人员目录；不伪造身份，不按姓名推测用户 |

## 7. 逐文件：路由、展示与行为

| 文件 | 动作与改动点 |
|---|---|
| M/routes/route_path.dart | 增加新版编辑/预览路由；保留旧路由供开关关闭时使用 |
| M/routes/mutualism_route_arguments.dart | 不可变参数：完整记录快照或新建类型/日期、固定模式/版本、路由实例身份。校验正式 ID 与快照一致，不携带服务客户端或认证凭据 |
| M/routes/pages.dart | 统一解析参数、注册新 Page 与 Binding |
| M/routes/navigator.dart | 单一版本分流入口，不在各业务 Widget 散落环境判断；结果表达已保存、正式记录身份及创建/修改 |
| M/presentation/widgets/item_result_orient_view.dart | 两类入口按已有记录与空白新建分流，沿统一导航传类型及完整快照。保存转预览后仍即时按正式记录刷新列表 |
| M/presentation/widgets/item_todo_oriented.dart | 保存成功返回后才发送带 todoId 的定向完成事件，取消/失败不移除待办 |
| M/presentation/orient_result/widgets/item_orient_result.dart | 新版用 bodyContent 做正文展示/预览入口；列表用轻量只读投影，不为每条记录创建可编辑控制器 |
| M/presentation/orient_result/widgets/item_oriented_date.dart | 核对记录传递和版本展示，确保日期分组不把完整快照裁成摘要 |
| M/presentation/orient_result/widgets/work_orient_dialog.dart | 保持旧版展示；新版跳日记预览，不用旧字段拼新版正文 |
| M/presentation/orient_result/widgets/mentions_highlight_text.dart | 旧版读取新版派生摘要时保留类型，不能把所有引用跳转成人员；按所支持的类型能力显示/禁用，不能按同名任意选实体 |
| M/presentation/orient_result/create/{binding,logic,page}.dart | 保持旧版交互、字段及容量规则；若共享解析工具需回归验证，不把旧请求构造复制进新版 |
| M/presentation/orient_result/list/{logic,page}.dart | 接收版本设置变化及保存刷新，完整记录传递；不修改原筛选、统计行为 |
| M/presentation/orient_result/month_list/{logic,page}.dart | 同步个人月记录展示和完整传数；保持既有实例 tag |
| M/presentation/orient_result/day_statistics/{logic,page}.dart | 核对统计明细打开路径，沿统一导航传完整记录；统计计算本身不因编辑器迁移重写 |
| M/presentation/orient_result/services/work_orient_clipboard_codec.dart | 保留旧复制协议；新版从 bodyContent/同源投影生成复制值，不读取可能过期的旧摘要 |
| M/presentation/orient_result/services/work_orient_share_handler.dart | 复用分享行为回写规则；新版通过注入 UseCase 装配，不复制静态创建 Repository 的做法 |
| M/domain/event/events.dart | 复用首页刷新、互动更新和待办事件；新增与修改区分，避免每次保存都重复发布新增完成 |
| M/index.dart | 只公开必要导航/配置/应用契约，不批量导出 journal 内部 Widget 或 Infrastructure |

以上“核对”文件若实际不承载相关行为且调用链已统一，无需为方案强行产生改动。实施时记录检索证据和最终影响范围。

## 8. 宿主服务、生命周期与权限

- 预览展示记录所属人，不把当前登录用户当作者。
- 真正点赞接现有应用用例、完整状态及计数，替换 example 演示布尔值；失败保留已确认状态。
- 分享截图成功、交给平台、用户分享成功及保存本机分别处理。只在可信成功回调回写分享行为。
- 复用 Templates 等模块能力时走模块根公开入口，不跨 Feature 导入内部 Widget/Logic；现有公开能力不足时先评估最小扩展。
- 页面拥有日记会话，日记会话拥有编辑器；Logic 不重复创建或 dispose 正文。宿主拥有目录、HTTP、认证和平台服务。
- 单记录一个活动写入者；页面重复打开采用既有路由/会话策略隔离，不仅依赖 GetX tag。
- 保存、选人、分享和重试全部校验页面、文档、账号/企业和会话身份；旧会话失效不可因切回账号重新生效。
- 等待视图和关联路由退场后关闭编辑器；不要用同步 onClose 或 unawaited 掩盖必须等待的保存/释放。
- 远端保持显式保存。顶栏成功保存后原会话仅供预览，确认保存离开后返回。输入、切后台、销毁和预览零写入。
- 网络/解析失败和不支持类型不新建空白替代，不覆写原记录；保留具体提示及安全重试。

## 9. 测试逐文件迁移与新增验收

目标测试根目录：`A/test/modules/mutualism/presentation/orient_result/journal/`。

| 测试文件/来源 | 验收重点 |
|---|---|
| example/test/daily_guidance/guidance_record_fields_test.dart → guidance_record_fields_test.dart | 直接迁移当前字段名、原栏目+聚合、customData、空值、sortNo、四种引用、旧默认类型、联合去重及样例键集合断言 |
| example/test/daily_guidance/body_content_api_test.dart → journal_page_api_test.dart | 迁移实际页面编辑、失败重试、加载校验、隐藏栏目、支持类型及默认值、身份失效、原记录保护；Mock 仅用于测试 |
| example/test/daily_guidance/journal_page_mode_test.dart | 初始入口及保存后单向转预览，原正文与控制器复用，预览零写入 |
| example/test/daily_guidance/journal_host_boundary_test.dart | 账号、企业、文档、选人及迟到回调边界 |
| example/test/daily_guidance/journal_native_mentions_test.dart | 原生提及、类型和身份保留 |
| example/test/daily_guidance/journal_blockcraft_integrity_test.dart | 稳定块 ID、正文完整性、未知数据拒绝 |
| example/test/daily_guidance/journal_clipboard_test.dart | 复制/粘贴、引用文本与身份，不把类型抹平 |
| example/test/daily_guidance/journal_preview_actions_test.dart | 分享/点赞入口与只读交互，替换演示业务预期 |
| example/test/daily_guidance/guidance_entries_layout_test.dart | 窄屏、大字及长引用布局 |
| example/test/daily_guidance/empty_guidance_flow_test.dart | 空模板、ORIENT/RESULT、跨年日期、预览、分享与重开。SaaS 补页面首次显式创建、正式 ID 回填及后续重开更新 |
| example/test/daily_guidance/journal_save_empty_sections_test.dart | 保存前空栏目清理、保留待办/提及/业务行、一次撤销、失败重试、确认保存离开、重开恢复 |
| example/test/daily_guidance/dynamic_journal_test.dart 与 journal_section_close_focus_test.dart | 新增自定义栏、连续关闭、恢复原键和内容、关闭不唤起键盘 |
| example/test/daily_guidance/journal_keyboard_toolbar_test.dart 与 journal_native_mentions_test.dart | 点击即建空行、取消、原行回填、分步撤销、失效结果、人员显示 |
| example/test/daily_guidance/journal_sticky_cover_test.dart 与 journal_page_layout_regression_test.dart | 沉浸式封面、横格首帧及各栏目自然高度 |
| example/test/daily_guidance/journal_keyboard_caret_visibility_test.dart 与根包 test/editor_shortcut_toolbar_test.dart | 键盘分帧及菜单切换时焦点行可见，待办按钮回显 |
| example/test/daily_guidance/journal_share_minimum_height_test.dart 与 example/integration_test/empty_guidance_flow_device_test.dart | 短图一屏、长图全文、页脚位置、真实输入与平台保存/分享 |
| example/test/daily_guidance/journal_last_section_fill_test.dart（工作区候选） | 末栏补线、上方内容占满时的自然高度、键盘和缩放后测量，以及跨会话回调隔离 |
| daily_guidance_record_snapshot_test.dart（新增） | 扁平/嵌套响应、wrapper 同名字段、独立深拷贝、完整扩展、正式 ID、只有 bodyContent 的记录保留 |
| daily_guidance_save_request_test.dart（新增） | 无 ID 创建/有 ID 更新、显式 null 真正进入 JSON、最终字段集合、没有新增错误字段、保存与派生同修订 |
| daily_guidance_version_settings_test.dart（新增） | PRE 默认、显式覆盖、环境隔离、设置写入失败、切环境不串值、已打开页版本固定 |
| daily_guidance_route_flow_test.dart（新增） | 列表完整传数、详情请求数为零、创建返回 ID 后进入预览、重新进入编辑时使用修改路径、多实例与单写入者 |
| daily_guidance_business_events_test.dart（新增） | 创建/修改刷新、todoId 精确完成、不重复回写、分享取消/失败不记成功 |

旧版还要回归原创建页、列表、复制、分享和引用跳转，确保新 parser/开关没有改变旧请求。新版保存后旧版读取需验证新引用字段格式可消费；旧版修改后新版读取必须联调 bodyContent 一致性。

设备验收包括中文输入合成后保存、键盘及菜单退场、窄屏/大字/安全区、长正文截图、微信/朋友圈取消和成功。Widget 端到端测试不能替代平台真机验收。

## 10. 文档与实施批次

### 文档改动清单

| 文件 | 实施时更新内容 |
|---|---|
| M/CLAUDE.md | 新目录、数据源、正文与旧字段边界、生命周期、事件及验证建议 |
| A/lib/modules/dashboard/CLAUDE.md | 新开关、PRE 默认、环境范围与生效时机 |
| A/lib/shared/CLAUDE.md | 若新增共享配置策略，记录职责和消费者 |
| H 对应现有 CLAUDE.md | 本地化及应用宿主装配；若没有对应文档，按宿主约定另行确认创建 |
| A/docs/verification/今日导向迁移-<实施日期>/ | 保存真实分析、测试、依赖、设备及协议联调结果，并更新所属索引 |
| E/docs/block-adaptation.md | 仅当实际涉及块协议变更时先核对桌面配置仓库 BlockCraft latest、声明/锁定/安装版和迁移文档后更新；查询失败明确待核对 |

### 分批顺序

1. **依赖与协议**。验证可复现 AppFlowy 来源，完成列表快照、最终请求、PRE 创建两类的业务族及 ID 联调。
2. **数据与编辑闭环**。迁入 Codec、派生器、双类型空模板、事务和加载校验。验收新建、已有修改、自定义及隐藏栏目的保存和恢复。
3. **页面与宿主**。迁入保存后同页预览、焦点避让、固定封面、选人、点赞、分享一屏和资源装配。验收后再纳入末栏候选。
4. **版本与灰度**。统一首页、待办、列表和月记录入口，确认旧版回归与跨版本数据一致性后开启 PRE 新版默认。归档实际构建、测试与设备结果。

每批仅格式化手写改动文件，在所属包分析并运行目标测试；公开 API/依赖改动验证 example、SaaS 和实际应用宿主。不得手改生成文件，不能批量格式化无关源码。

## 11. 完成条件与待联调事项

完成条件：

- 新版完整请求字段与样例一致；dailyOrient/dailyResult 按类型取值及 null，mentions 三字段、默认类型及联合去重全部正确。
- 完整列表记录可直接编辑和预览，详情请求数为零。空白新建显式保存时实际发送无 ID 请求，成功接收正式 ID，进入同会话预览，重新编辑按修改提交。
- unsupported 类型加载前明确拒绝，原记录不变；合法及旧引用可加载、编辑、保存。
- 新旧版本按环境设置独立工作，旧版路径未被新版实现替换。
- 保存前空栏目清理及撤销、业务行创建和填人、失败重试、同页预览、离开、会话失效、资源释放和业务事件通过目标回归。
- 所有新增/改名声明、文件、import/export、Binding、测试及文档一致；相关消费者分析通过，`git diff --check` 通过。

不能仅凭 example Mock 推定已满足的事项：

1. 线上列表实际嵌套位置、正式记录 ID 与完整业务扩展。
2. 保存响应是否包含正式 ID/完整记录，以及创建不确定结果的幂等恢复方式。
3. 后台是否保留显式 null、旧字段清空语义、换行和最大长度/条数。
4. 旧版修改后 bodyContent 的同步或失效策略。
5. 空模板 v5 在 PRE 的接收、两类新建的 `DAILY_ORIENT` 业务路由、必要基础字段及业务日规则。
6. 四种 mentionType 在真实接口及旧版展示和跳转中的支持。
7. 干净环境的 AppFlowy 解析与构建，以及末栏补线候选版本的纳入结果。

现有 example 回归和设备记录为迁移参照。SaaS 编译、测试、依赖解析及真机验证安排在实施批次。
