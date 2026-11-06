# 日导向迁入 SaaS 的全链路与公司模板方案

- 修订日期 2026-11-06。本文是实施方案，SaaS 代码与接口尚未迁移。
- SaaS 核对提交为 `1067d9b94`，编辑器已提交基线为 `a1a63ae`。example 中三套公司模板的试点包含工作区改动，仅作为验证编辑器嵌入的参考。
- 请求结构以[完整数据样例](../example/文档完整数据结构.json)及本文第 2 节为准。正文协议见[数据格式](data-format.md)。

## 1. 范围与固定决策

迁移覆盖成果导向和导向成果在 SaaS 的完整链路，包括入口、列表、详情预览、创建、修改、保存、重开、复制、互动和分享。**模板以 SaaS 现有注册表和页面为唯一视觉基准。每条日导向在 SaaS 选中的原版模板上编辑，替换的是模板正文区域。** 模板周围的构图、图片、品牌装饰、取景、缩放和长图布局继续由原模板负责。

产品展示名称统一为 `ORIENT` →“成果导向”、`RESULT` →“导向成果”，入口、编辑、预览和分享使用同一映射。本次仅展示更名，历史正文与协议标识不改写。

| 边界 | 迁移决策 |
|---|---|
| `cses.saas/lib/modules/mutualism` | 持有版本、记录、权限、编辑会话、业务提交、列表刷新和互动。覆盖 ORIENT 与 RESULT |
| `cses.saas/lib/modules/templates` | 保留原有公司模板注册与分发，提供供日导向宿主注入正文的最小公开接口。各模板保留各自的视觉组件、图库、截图与分享外壳 |
| `cses_editor` 根包 | 提供通用正文视图、命令和键盘等能力。SaaS 通过公开入口接入 |
| `cses_editor/example` | 用于提取和验证日导向正文协议、事务及交互。三套试点的图片、品牌组件和整页布局留在示例，生产视觉直接复用 SaaS 原版 |

- 旧版保留现有入口、字段和行为。新版以 `bodyContent` 恢复正文，并在保存时生成兼容字段。PRE 无显式配置时默认新版，其余环境默认旧版。PRE 开启前须通过协议和模板覆盖验收。
- 已有记录从列表传入完整独立快照。创建与修改沿用 `/dailyOrient/save`，创建省略 ID，修改使用后台正式 ID。顶栏保存成功后当前会话转为只读预览。
- 编辑态保留顶部悬浮返回、保存、撤销、重做及整页滚动。栏目通过键盘菜单按需添加。编辑态隐藏公司 Logo，保存后的预览和分享图显示原版 Logo，满模板画布宽度并保留素材比例。
- 完成范围以生产注册表可达模板为准，覆盖公司、部门、内容变体和兜底分支，包含三套已试点模板及其他所有可达模板。与日导向共用模板的其他调用方沿用原契约。

### 工作区定位

| 标识 | 目录 |
|---|---|
| E | `/System/Volumes/Data/workspace/cses_editor` |
| S | `E/example/lib/daily_guidance` |
| A | `/System/Volumes/Data/workspace/cses/cses.saas` |
| M | `A/lib/modules/mutualism` |
| T | `A/lib/modules/templates` |
| J | `M/presentation/orient_result/journal`，拟新增日导向会话与宿主适配目录 |
| H | `/System/Volumes/Data/workspace/cses/cses.jqdl`，实际应用宿主 |

实际实施前复查目标分支及未提交改动。下面标注新增的文件名是拟定落点，现有入口优先复用。

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
4. `BodyContentCodec.decode` 创建日记草稿，宿主创建唯一正文会话，通过现有公司模板注册表确定外壳。模板正文插槽挂载该会话的编辑视图。
5. 结束输入合成，执行一次可撤销的空可选栏目关闭事务，再捕获独立快照。调用 Codec 生成 bodyContent，从同一正文派生字段。
6. 合并到完整来源记录，覆盖所有派生字段及显式 null；调用现有保存用例。
7. 业务成功后确认保存修订和正式记录，顶栏保存使原会话进入对应公司模板的只读预览。按最终可见内容应用原有模板变体规则，关闭键盘与编辑动作并显示品牌页脚。确认保存后离开直接返回结果。失败保留编辑、撤销和重试能力。
8. 响应完整则更新当前记录；响应不完整则刷新原列表，不补造详情接口。

### 新建记录

1. 迁入 `createEmptyGuidanceRecord(now, orientType: ...)` 的构造逻辑，生成 `daily-writing` v5 根节点和一个空填写区。宿主注入日期、类型和会话身份，类型同步到 `orientType`、`meta.dailyType`、标题和两个派生字段。
2. SaaS 新建会话将模板和块身份与后台正式 ID 分离。示例 Mock 使用的顶层临时 ID 只用于本地关联，序列化创建请求时省略顶层 `id`。日期沿用 `meta.dailyDate`，新建时使用宿主确定的业务日。
3. 用待创建状态明确驱动首次显式提交。即使空白内容没有产生编辑修订，点保存也应按新建流程实际请求一次。example 的空白保存用例直接写 Store，SaaS 需增加真实页面点击保存到收到 ID 的验证。
4. 首次成功接收并固化正式 ID，再冻结为预览或返回。随后从 SaaS 编辑入口重开才按修改提交，携带已保存的正式 ID。创建在途复用同一请求，失败保留待创建态与内容。
5. 对响应丢失或业务成功但 ID 缺失的情形，按已有幂等或列表对账能力恢复身份后再允许下一次写入。PRE 联调确认新建两类的 `bizType`、响应 ID 与必需基础字段。

### 编辑事务与模板模式

| 场景 | 业务规则 |
|---|---|
| 新增与关闭栏目 | 自定义名称先 trim，长度 1–40，独立稳定 key。关闭可选栏目保留草稿，隐藏区与可见正文共同校验容量及身份。恢复时使用原 key 和内容，手动关闭不把焦点跳到其他栏目 |
| 显式保存清理 | 仅顶栏保存或确认保存后离开时执行。首栏、非空正文、待办、提及、人员业务行和非文字块保留。多个空感悟、自检和自定义栏目合为一次可撤销事务。失败仍可编辑、撤销或重试 |
| 都来帮和领航员 | 点击先创建独立业务行，再选人。取消保留空业务行，选中回填原行。创建和回填分别可撤销。空业务行留在正文，空值不产生聚合条目 |
| 沉浸式编辑 | 真实 SaaS 模板容纳一个正文会话，画布整体滚动至透明状态栏。悬浮按钮留在安全区。键盘及菜单变化后以实际正文视口校正焦点行 |
| 保存后预览 | 从已保存的同一修订生成只读正文。继续使用所选 SaaS 模板的原版构图、素材、取景和品牌页脚 |
| 分享 | 通过 SaaS 模板外壳使用独立保存快照、同源的只读正文与测量。沿用图库、图片首帧、截图、像素限制、取消与分享回写流程 |
| 横格与补线 | 编辑区可复用现有能力，以目标模板内容槽和键盘视口验收。纸张高度、留白和页脚位置由各模板原版布局决定 |

### 旧版与版本切换

- 旧版保持原有读取、编辑和提交行为；新版渲染、复制及分享以 bodyContent 为来源。
- 新版不因 bodyContent 缺失自动回退旧字段。旧版编辑已有新版记录后，后台必须同步/标记 bodyContent 的有效性，否则新版可能读取旧正文；环境开关本身不能解决此问题。
- 页面存活期间固定新旧版本，已保存的新版编辑会话可转入只读预览。切换设置后更新列表及后续打开的页面。

## 4. 逐文件：依赖、配置与应用宿主

| 文件 | 动作与改动点 |
|---|---|
| A/pubspec.yaml | 以可复现的固定来源接入 `cses_editor` 根包。联调可在同一工作区使用相对路径，正式验收以可从干净环境解析的固定版本为准。按直接 import 核对宿主依赖 |
| A/pubspec.lock | 由依赖工具生成更新，不手改 |
| A/lib/global/keys.dart | 增加新版成果导向设置 key，不复用其他灰度开关 |
| A/lib/modules/dashboard/presentation/env/environment_toggle.dart | 增加版本开关声明，说明同时影响导向和成果；在现有声明式机制中补齐该开关的环境默认与存储范围能力，不改变其他配置语义 |
| A/lib/modules/dashboard/presentation/env/logic.dart | 显式配置优先；PRE 默认 true，其余 false；存储按设备和环境隔离。切环境时重新解析对应环境的临时/保存值，不把当前环境的值写入其他环境 |
| A/lib/modules/dashboard/presentation/env/page.dart | 复用现有开关行，只有开关本体触发；保存成功后发布必要的设置变更通知 |
| A/lib/shared/presentation/settings/daily_guidance_editor_settings.dart（新增） | 单一版本解析策略及 key/default 规则，参数化接收环境和设置值，供环境页、互生导航和展示消费；避免互生反向导入 Dashboard 私有 Logic |
| H/lib/modules/app/view.dart | 在既有 GetMaterialApp 合并 AppFlowy 本地化 delegate，不新增 MaterialApp 或协同初始化 |
| T 与 H 的素材声明 | 复用 SaaS 模板现有图片、图库、品牌图、字体和宿主资产装配。按实际构建核对缺失项及来源 |

### 依赖前置核对

- 当前 E 的 `pubspec.yaml`、根包锁定及 example 锁定仍声明 AppFlowy 邻接路径。此前文档中的固定 Git 状态不能作为当前验收证据。
- 依照 E 仓库约定，实施前将 AppFlowy 来源收敛到 `https://github.com/shichunlei/appflowy-editor.git` 的固定可获取提交，核对兼容补丁、声明、锁定及实际解析。历史参考提交为 `9e7593134457eac9193a61ee4023a75de55fcc68`，采用前需确认覆盖所需行为。
- 用 SaaS 和实际应用宿主的干净环境验证依赖、素材、本地化、编辑与截图。编辑器根包保持离线边界，宿主的现有服务通过端口注入。

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

## 6. 原版模板复用与正文接入

### 6.1 模板选择与覆盖清单

以 `T/company/registry/company_template_registry.dart` 的实际选择结果为准。当前核对到 **41 个公司映射、公司映射下的 44 个不同页面类、7 个兜底注册项**。公司映射数与模板数分开统计，品牌别名共享组件仍需验证实际 Logo。实施时从目标分支生成覆盖清单，清单随注册表变化更新。

| 分支 | 必验内容 |
|---|---|
| 公司及品牌 | 覆盖注册表中的每项公司映射，包含中企云链及多个公司共享同一模板页面的分支 |
| 部门 | 覆盖恒源亿科的亿科医疗与默认分支，以及国医康的鼎顺利、优米口腔、北区口腔与默认分支，记录实际注册 ID 和页面类 |
| 内容变体 | 汇丰永盛、成塔服饰和爱能智亚分别覆盖原一屏版和动态 V2。以 `CompanyTemplateVariantPolicy` 对最终可见内容的判断为准 |
| 兜底 | 七项都能被测试确定性选中。对同一会话固定选中结果，保存、预览、换图和截图过程中不重新随机 |
| Debug | 指定账号模板切换可用于测试。生产覆盖以 Release/Profile 正式分发为准 |

选择继续消费当前 SaaS 导航使用的公司、记录部门和内容条件。保存修订变化若触发官方一屏/V2 切换，在安全的编辑提交边界重新解析变体，保留文档控制器、图片来源和取景状态。输入合成期间避免销毁重挂。主正文很长、自定义栏目或非文本块可能超出现有变体策略能识别的范围。先实测既有变体能否完整容纳，再决定是否扩充选择能力。固定模板若无法在只扩展内容区的前提下承载全文，该分支保持未完成，待确认布局规则后再放量。

### 6.2 视觉和编辑的分界

| 区域 | 实施要求 |
|---|---|
| 正文槽以外 | 原模板页面负责品牌色、字体、主图、相框、取景、裁剪、几何比例、头像、问候、日期、装饰和层叠位置。保留原模板参数和素材引用，禁止用 example 版式替换 |
| 编辑正文槽 | 挂载一个 `cses_editor` 会话。允许按编辑需要显示横格、选区、输入提示和栏目动作。正文以真实宽度自然增长，模板装饰按原布局约束随正文边界定位 |
| 预览及分享正文槽 | 使用保存修订的同源只读块展示，保留富文本、图片、引用、待办、人员业务行及自定义栏目。预览和截图使用相同宽度、字体和组件配置。原模板的标题、颜色和间距作为正文样式输入。人员行按文档位置渲染一次，兼容摘要和聚合数组用于业务消费 |
| 应用操作层 | 返回、保存、撤销、重做固定悬浮，整页可滚到透明状态栏下。保存后沿用只读预览和现有互动。操作层不进入截图 |
| 品牌页脚 | 编辑时保留模板收边并隐藏 Logo。预览和分享使用 SaaS 品牌图，按用户确认的规则保留满画布宽度和素材比例 |

复用原版模板是还原手段。正文槽与编辑操作层按新流程实现。Logo 显示时机和满宽规则按已确认的要求验收。对比基线使用同模板分支、同实际宽度、同图库图片、同取景、同时间与作者，以及等高正文。模板装饰位置变化若由正文自然增高触发，应与原版使用等高内容时的布局一致。避免把固定封面、末栏补线、示例分享图最少一屏等示例实现当作所有 SaaS 模板的强制约束。

### 6.3 实施接点

| 文件或范围 | 动作 |
|---|---|
| `T/company/registry/company_template_registry.dart`、`company_template_selection.dart`、`company_template_variant_policy.dart` | 在现有分发上承接宿主正文能力，记录稳定的模板与变体身份，保留公司、部门、随机兜底和 Debug 规则 |
| `T/company/widgets/company_template_shell.dart` | 允许注入编辑、预览和捕获用的正文槽，旧调用保持默认。宿主管理文档和保存，模板管理画布、图片取景与分享外壳 |
| `T/company/*_template_page.dart` | 逐个接入真实正文容器，核对每页内边距、定位基准、图片区域和品牌页脚。已有 `OrientResultSectionsView` 或旧单区块渲染仍供旧路径使用 |
| `T/widgets/measured_template_poster_view.dart`、`T/layout/measured_poster_layout.dart` | 注入同版式只读正文测量和内容修订标识，保留原主图下限、布局收敛及图像门禁。测量树使用无输入、无焦点的渲染，避免重复挂载活动编辑器 |
| `T/routes/navigator.dart`、`T/index.dart`、分享完成回调 | 暴露宿主所需的最小公开契约，原模板选择和分享回写入口兼容旧消费者。模板不反向持有业务 UseCase |
| `J/binding.dart`、`J/logic.dart`、`J/page.dart`（拟新增） | 装配真实服务、创建唯一会话、组织编辑与预览、处理保存及页面生命周期。页面承载 SaaS 模板选择结果和应用操作层 |
| `J/editor/` 与 `J/adapters/`（拟新增） | 从 S 提取正文 Codec、派生器、空模板、栏目事务和输入命令。由宿主提供快照、显式保存、真实头像目录及平台能力 |

`LocalJournalPage`、`JournalSurface` 与示例分享页用于参考状态转换、焦点、键盘及快照生命周期。只提取可验证的正文能力和必要交互。示例公司模板 Widget、全屏纸张根布局、文件草稿、Mock 服务和 MethodChannel 留在 example。SaaS 继续通过根包获得光标避让与工具栏能力。

## 7. 逐文件：路由、展示与行为

| 文件 | 动作与改动点 |
|---|---|
| M/routes/route_path.dart | 增加新版编辑/预览路由；保留旧路由供开关关闭时使用 |
| M/routes/mutualism_route_arguments.dart | 不可变参数：完整记录快照或新建类型/日期、固定模式/版本、路由实例身份。校验正式 ID 与快照一致，不携带服务客户端或认证凭据 |
| M/routes/pages.dart | 统一解析参数、注册日导向宿主 Page 与 Binding，模板由 Templates 注册表选择 |
| M/routes/navigator.dart | 单一版本分流入口，不在各业务 Widget 散落环境判断；结果表达已保存、正式记录身份及创建/修改 |
| M/presentation/widgets/item_result_orient_view.dart | 两类入口按已有记录与空白新建分流，沿统一导航传类型及完整快照。保存转预览后仍即时按正式记录刷新列表 |
| M/presentation/widgets/item_todo_oriented.dart | 保存成功返回后才发送带 todoId 的定向完成事件，取消/失败不移除待办 |
| M/presentation/orient_result/widgets/item_orient_result.dart | 新版用 bodyContent 做正文展示/预览入口；列表用轻量只读投影，不为每条记录创建可编辑控制器 |
| M/presentation/orient_result/widgets/item_oriented_date.dart | 核对记录传递和版本展示，确保日期分组不把完整快照裁成摘要 |
| M/presentation/orient_result/widgets/work_orient_dialog.dart | 保持旧版展示；新版打开对应 SaaS 公司模板的只读预览，从正文快照渲染 |
| M/presentation/orient_result/widgets/mentions_highlight_text.dart | 旧版读取新版派生摘要时保留类型，不能把所有引用跳转成人员；按所支持的类型能力显示/禁用，不能按同名任意选实体 |
| M/presentation/orient_result/create/{binding,logic,page}.dart | 保持旧版交互、字段及容量规则；若共享解析工具需回归验证，不把旧请求构造复制进新版 |
| M/presentation/orient_result/list/{logic,page}.dart | 接收版本设置变化及保存刷新，完整记录传递；不修改原筛选、统计行为 |
| M/presentation/orient_result/month_list/{logic,page}.dart | 同步个人月记录展示和完整传数；保持既有实例 tag |
| M/presentation/orient_result/day_statistics/{logic,page}.dart | 核对统计明细打开路径，沿统一导航传完整记录；统计计算本身不因编辑器迁移重写 |
| M/presentation/orient_result/star/ 及跨模块入口 | 核对引导星、首页、待办或外部入口是否打开同一记录。进入日导向详情或编辑时统一路由；引导星专用分享模板继续按原业务契约分发 |
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

## 9. 全链路验证与逐模板验收

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
| example/test/daily_guidance/journal_sticky_cover_test.dart 与 journal_page_layout_regression_test.dart | 参考现有布局回归，SaaS 按实际模板检查整页滚动、安全区、正文槽和自然增长 |
| example/test/daily_guidance/journal_keyboard_caret_visibility_test.dart 与根包 test/editor_shortcut_toolbar_test.dart | 键盘分帧及菜单切换时焦点行可见，待办按钮回显 |
| example/test/daily_guidance/journal_share_minimum_height_test.dart 与 example/integration_test/empty_guidance_flow_device_test.dart | 参照现有截图与设备用例，SaaS 验证原版短图构图、长图全文、页脚及真实平台保存/分享 |
| example/test/daily_guidance/journal_last_section_fill_test.dart | 若目标编辑槽采用补线，验证自然高度、键盘和缩放后测量、跨会话回调隔离 |
| daily_guidance_record_snapshot_test.dart（新增） | 扁平/嵌套响应、wrapper 同名字段、独立深拷贝、完整扩展、正式 ID、只有 bodyContent 的记录保留 |
| daily_guidance_save_request_test.dart（新增） | 无 ID 创建/有 ID 更新、显式 null 真正进入 JSON、最终字段集合、没有新增错误字段、保存与派生同修订 |
| daily_guidance_version_settings_test.dart（新增） | PRE 默认、显式覆盖、环境隔离、设置写入失败、切环境不串值、已打开页版本固定 |
| daily_guidance_route_flow_test.dart（新增） | 列表完整传数、详情请求数为零、创建返回 ID 后进入预览、重新进入编辑时使用修改路径、多实例与单写入者 |
| daily_guidance_business_events_test.dart（新增） | 创建/修改刷新、todoId 精确完成、不重复回写、分享取消/失败不记成功 |

模板覆盖测试放在 `A/test/modules/templates/`，与宿主业务回归分别记录。

1. **分发矩阵**。逐公司及部门生成预期页面与品牌，覆盖一屏/V2、共享页面、全部兜底。检查注册表与矩阵差集为空。
2. **原版视觉对照**。逐模板留存原版和新版截图。固定图片、取景、时间、作者、字体缩放、设备宽度及等高正文夹具，对正文及操作层做独立标注，比较其余画面和几何边界。验收记录列出构图、颜色、遮罩、图层、日期头像、Logo 和截图范围。差异须逐项修正或明确获得验收。
3. **内容与布局**。每个可达模板检查短文和超屏长文，记录正文完整、主图下限、页脚、溢出与截图像素限制。按版式族追加窄屏、大字、折叠屏、长作者名、图库替换、拖动取景、图片失败和截图中换图等覆盖。
4. **真实设备链路**。先用汇丰永盛、成塔服饰和中企云链在 SaaS 宿主验证，覆盖中文输入合成、焦点、保存正式 ID、重开、预览和长图。后续分批实测各版式族，报告逐模板对照与真实账号/平台能力的验证范围。
5. **新旧共存**。旧版及其他共用模板的分享入口保持原行为。检查版本切换、旧版修改后正文同步或失效、新版摘要供旧版读取、事件和平台取消回调。

旧版还要回归原创建页、列表、复制、分享和引用跳转，确保新 parser/开关没有改变旧请求。新版保存后旧版读取需验证新引用字段格式可消费；旧版修改后新版读取必须联调 bodyContent 一致性。

设备验收包括中文输入合成后保存、键盘及菜单退场、窄屏/大字/安全区、长正文截图、微信/朋友圈取消和成功。Widget 端到端测试不能替代平台真机验收。

## 10. 文档与实施批次

### 文档改动清单

| 文件 | 实施时更新内容 |
|---|---|
| M/CLAUDE.md | 新目录、数据源、正文与旧字段边界、生命周期、事件及验证建议 |
| T/CLAUDE.md | 正文插槽、测量契约、模板分发和逐模板视觉覆盖矩阵 |
| A/lib/modules/dashboard/CLAUDE.md | 新开关、PRE 默认、环境范围与生效时机 |
| A/lib/shared/CLAUDE.md | 若新增共享配置策略，记录职责和消费者 |
| H 对应现有 CLAUDE.md | 本地化及应用宿主装配；若没有对应文档，按宿主约定另行确认创建 |
| A/docs/verification/成果导向迁移-<实施日期>/ | 保存真实分析、测试、依赖、设备及协议联调结果，并更新所属索引 |
| E/docs/block-adaptation.md | 仅当实际涉及块协议变更时先核对桌面配置仓库 BlockCraft latest、声明/锁定/安装版和迁移文档后更新；查询失败明确待核对 |

### 分批顺序

1. **依赖、协议与视觉基线**。冻结 SaaS 注册表清单和原版截图，验证固定依赖来源、列表快照及 PRE 两类创建与更新契约。
2. **宿主与首批模板**。接入 Codec、真实服务、唯一编辑会话、正文插槽及模板测量。用汇丰永盛一屏/V2、成塔服饰一屏/V2、中企云链跑通创建、修改、预览和分享。以 SaaS 原版截图完成首批验收。
3. **全部模板和业务入口**。按一屏、动态海报、部门/品牌分支与兜底分批迁移真实正文槽，并补齐首页、待办、列表、月记录、详情、复制和互动。登记每个分支的代码、测试和视觉结果。
4. **灰度与完成验收**。覆盖矩阵无遗漏，真实宿主、数据兼容、旧版回归及平台分享通过后再启用 PRE 默认。上线按已验证的范围推进，未通过的模板不得被当作完成或无提示切换到其他版式。

每批仅格式化手写改动文件，在所属包分析并运行目标测试；公开 API/依赖改动验证 example、SaaS 和实际应用宿主。不得手改生成文件，不能批量格式化无关源码。

## 11. 完成条件与待联调事项

完成条件

- SaaS 可达公司、部门、内容变体和兜底分支均接入原模板。编辑、保存后预览和分享全链路使用对应模板。逐模板视觉证据覆盖正文槽之外的原版构图和素材。
- 已有记录、新建、列表、待办、复制、互动和分享按统一业务入口闭环，首批三家公司验收完成后继续覆盖剩余模板。
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
7. 干净环境的 AppFlowy 解析与构建，以及现有键盘和滚动能力在实际模板中的结果。
8. 历史缺失正文的数据覆盖率及后台补齐范围。缺失记录在放量前需有可验证的兼容路径。
9. 一屏模板对长正文、仅自定义栏目或仅非文本块的容纳结果，以及原版构图与完整长图发生冲突时的分支策略。

现有 example 回归和设备记录是编辑能力参照。生产模板一比一的完成依据是 SaaS 原版与目标宿主的逐模板对照，以及真实接口、构建和真机验收。
