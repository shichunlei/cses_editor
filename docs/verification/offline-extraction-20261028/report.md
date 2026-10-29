# 独立编辑器与今日导向拆出

日期：2026-10-28。项目位于 `workspace/cses_offline_editor/`，新建独立Git仓库，未提交或推送。
原项目只读，已提取源文件与开始时记录的SHA-256保持一致。来源与版本见[来源说明](../../source.md)。

## 实施结果

- `packages/cses_editor`提供纯内存会话、通用视图、工具栏、输入/选区/历史、标准块与宿主端口。
- `example/lib/daily_guidance`承载今日导向业务，包含栏目、纸张、草稿、迁移、自动保存、预览与JSON交换；没有今日导向独立包。
- `packages/appflowy_editor`保留当前本地fork、许可证及测试，不复制其上游Demo与构建缓存。
- 公共组件移除CollabRuntime引用，服务按实例注入；未绑定组件使用空端口，诊断输出到控制台。
- 图片改用当前视图内存下载，去除默认磁盘缓存带入的SQLite插件。下载客户端由视图创建和关闭，旧Future与URL身份隔离。
- 宿主移除Common账号和HTTP业务实现，人员目录、服务和会话身份由调用方注入；示例仅提供明确标注的虚构人员。页面的选人权限、过期请求和身份变化保护保留。
- 修复资源包名路径，两个生成目录文件原样迁入，补齐生成工具和第三方表情许可证。
- 提供[接入说明](../../integration.md)、[数据说明](../../data-format.md)和可复跑的[独立性检查](../../../tool/verify_independence.py)。

## 自动验证

| 范围 | 结果 | 证据 |
|---|---|---|
| 通用编辑器 | 78项通过，含Android/iOS参数化输入、历史、菜单、格式、JSON与实例隔离 | [日志](core-tests.txt) |
| 今日导向业务 | 184项通过，含草稿迁移、文件失败保护、原生提及、业务行、键盘菜单、格式、预览和JSON | [日志](example-tests.txt) |
| 底层fork的输入/历史 | 6项通过；没有改fork编辑实现 | [日志](appflowy-tests.txt) |
| 最后标题布局调整 | 18项页面及键盘回归通过，与184项有重叠，不累加 | [日志](page-final-tests.txt) |
| 静态检查 | 编辑器、宿主、fork均无问题 | [编辑器](core-analysis-final.txt)、[宿主](example-analysis.txt)、[fork](appflowy-analysis.txt) |
| Android构建 | 成功，普通App入口 | [日志](android-build-final.txt) |
| 独立性 | 源码、实际解析依赖及APK检查通过 | [结果](independence.json) |
| 格式与空白检查 | 手写代码已格式化，git diff --check通过 | [检查](diff-check.txt) |

原始迁入的JSON回归因缺少样例路径出现5项宿主失败、4项包内失败；补齐本仓库内夹具并修正路径后通过。
宿主首轮失败日志见[记录](example-tests-initial.txt)。这些是夹具搬迁遗漏，未通过跳过测试处理。

生成文件保留源字节，不以手写代码规则格式化；[字节核对](generated-preservation.json)。
`.gitattributes`仅为第三方目录中的两份原始文件、生成Mermaid发布资产及原始文本日志保留原有空白，不修改供应商或机器记录以满足检查。

## Android真机

设备：vivo V2353A，Android 14/API34，arm64。独立应用ID：`com.cses.offline.cses_offline_example`。
使用独立应用目录，不覆盖或清空原App数据，不修改手机安装安全或无障碍设置。

一项真实设备集成场景通过（驱动另统计tearDownAll，不计作第二业务场景）：打开业务页、正文事务、撤销/重做、预览切换、JSON入口、等待退出保存、读取App私有目录中的实际JSON、重开验证正文。
见[驱动日志](device-integration.txt)、[预览](device-preview.png)和[重开](device-reopened.png)。正文事务由测试API驱动；不将其描述为人工中文输入法验收。

首轮结束校验受并发UI层级抓取触发的语义状态变化影响；单独重跑通过，未跳过测试断言或更改生产无障碍能力。失败与处理见[记录](device-integration-initial.txt)。驱动中其他App进程的日志已按PID剔除，保留本App及测试输出。

随后安装普通App，实际点击正文并通过Android输入事件输入 `Offline editor phone test`，使用键盘工具栏转换为待办。
验证预览、返回保存，并强制关闭该独立App进程后重新打开；实际文件包含输入文字与 `todo_list`。
最终手机安装包SHA-256与本机构建产物一致，见[安装核对](installed-artifact.json)。
见[键盘](device-keyboard.png)、[待办](device-todo.png)、[进程重开](device-process-reopened.png)和[实际草稿](device-draft.json)。这些均为新App内本轮创建的虚构测试数据。

## 范围与限制

- 本轮完成Android手机验证；iOS仅创建工程，未新增iOS构建、签名或真机验收。单元测试中的iOS参数化场景不等于iOS手机通过。
- 手机验证了JSON菜单入口；系统文件框的实际导入/导出未在设备上逐项验收，已有业务转换和文件端口回归通过。
- 示例没有接入真实账号、企业人员、天气、任务/会议/KR、上传服务。能力通过宿主端口提供，缺省不发起这些业务请求。
- 桌面latest查询ECONNRESET，最新版待核对；本轮不升级桌面、不宣称新增块或所有高级对象完整兼容。见[版本跟踪](../../block-adaptation.md)。
- 首次构建保留keyboard_height_plugin的Kotlin兼容提示与Android SDK工具版本提示；当前Android构建成功。后续升级Flutter/AGP时需重新验证该插件。
- 原协同项目没有改为依赖本新包；两边后续共享维护属于另一次原项目迁移。
