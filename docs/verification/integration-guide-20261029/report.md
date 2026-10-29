# 其他App独立接入文档与模板验证

日期：2026-10-29。项目：`/System/Volumes/Data/workspace/cses_editor`。

## 交付

- [完整接入文档](../../integration.md)：根包依赖、固定AppFlowy Git提交、Flutter初始化/本地化、内存编辑与完整JSON恢复、离线存储、宿主服务、账号/资源边界、今日导向业务迁入范围及平台插件说明。
- [独立宿主模板](../../integration_app/README.md)：普通Flutter应用源码、依赖配置、文件保存会话、宿主服务适配器和测试。模板不是运行时依赖，宿主复制所需代码后只引用根包。
- 根README增加文档与模板入口，数据格式文档区分普通模板v1、今日导向v2及桌面JSON。

模板的生产源码只导入`package:cses_editor/cses_editor.dart`等公开入口。没有引用`cses_offline_example`、`example`源码/资产或`cses_editor/src`。核心库和既有今日导向源码未修改，187份生产文件与此前验证基线一致，见[范围核对](scope.json)。

## 验证

| 检查 | 结果 |
|---|---|
| 手写Dart格式化 | 4份模板源码/测试已格式化，[日志](format.txt) |
| 模板独立静态分析 | 无问题，[日志](host-analysis.txt) |
| 模板6项测试 | 全部通过：[日志](host-tests.txt)。覆盖富文本格式恢复、账号/文档分区、保存中新编辑与并发flush、损坏/未知版本保留、失败重试、系统返回保存/释放/重开及本地化初始化 |
| 无example的临时发行目录 | 只复制根包lib/assets/third_party及包配置/说明，目录中没有example、原工程或协同原生构建文件；根包之外新建普通Flutter Android宿主 |
| 发行目录消费者 | 重新解析依赖、静态分析无问题，6项测试通过：[解析](isolated-pub-get.txt)、[分析](isolated-analysis.txt)、[测试](isolated-tests.txt) |
| 实际依赖图和import | 没有example、原工作区路径、原协同包、Common、FRB/Yrs/协同数据库；只使用公开入口。Git依赖解析到指定固定提交，完整包清单见[结果](isolated-result.json)，版本证据见[锁定图](isolated-host-lock.txt) |
| 消费者Android构建 | 普通Flutter脚手架构建成功，[日志](isolated-android-build.txt)；APK路径、大小与SHA256见[结果](isolated-result.json) |
| 源码/依赖/APK边界检查 | 通过，[独立性结果](isolated-apk-independence.json)。APK仅检出普通Flutter/Dart JNI运行库，无协同原生库 |
| 文档相对链接、依赖旧路径与空白检查 | 见[最终检查](final-checks.json)、[git diff --check](diff-check.txt) |

日志仅规范化行尾空白，保留输出、失败说明和构建提示。

独立验证使用的[脚本](isolated-validation.py)保留在本分类。执行期间工作区被重新创建，Android构建已完成，但验证脚本随后写结果时一度找不到原路径。恢复后核对当前模板源码与临时宿主逐文件一致，保留原构建日志，检查实际APK并完成依赖图和产物审查；没有将脚本的记录写入失败算作构建失败或额外构建通过。

早期模板测试曾因缺少测试中的AppFlowy扩展import而未编译，补充后通过；新增路由测试最初未等待最终释放即尝试重开，已改为等待文件任务和路由状态，最终6项测试通过。正式业务库没有因此修改。

## 使用和限制

离线保存模板面向Android/iOS私有文件：500ms去抖，独立快照、后台JSON/文件操作、串行提交及最终flush；每文件单写入者由宿主保证。保存失败留在当前编辑页重试；突然强杀仍可能丢失去抖窗口内的编辑，文档已写明。

人员选择、头像、详情和任务查询以明确的本地演示数据展示注入方式；未接入真实登录、人员服务器或上传服务器。媒体适配器完整转交宿主的文件选择/上传函数，默认未注入，不伪造上传成功。没有验证实际业务HTTP、鉴权或媒体上传。

本轮消费者完成Android构建和Widget/单元测试，未安装到手机或做iOS完整构建；之前今日导向手机验收见[结构调整后真机复验](../package-layout-20261029/phone-verification.md)，不当作此模板的手机验收。Android构建有上游keyboard_height_plugin的Kotlin Gradle Plugin未来迁移提示，当前构建成功，本轮未修改上游插件或扩大升级范围。
