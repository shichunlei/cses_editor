# SaaS 编辑与模板预览详情入口验证

日期：2026-11-08

## 实现范围

已有成果导向/导向成果的编辑、独立模板预览和重开，通过 `GetOrientResultDetailUseCase` 按所点击槽位 `id` 请求 `POST /dailyOrient/detail`。来源的 `rootId`、正文根 ID 和旧 `bodyContent` 都不用于替代本次详情。新建无 ID 时继续选择原表单或公司模板，未增加详情请求。

`GuidanceEditorComposition` 在路由创建时固定账号/公司，通过 `GuidanceDetailGate` 加载完整详情。只有记录 ID、公司、槽位类型、编辑作者及正文格式校验通过后，才创建真正的编辑页面、Store 和宿主端口。`WorkOrientContentDialog` 按有效记录 ID 展示模板预览按钮，列表不含正文不再隐藏入口。

加载、失败与取消复用公共 `LoadingWidget`、`EmptyPage` 和现有按钮；没有新增 AppBar、SnackBar、人员弹窗或请求客户端。null 正文显示“暂无完整正文”，空对象或不支持文档显示兼容提示，并只读展示本次详情的原字段，不挂载可写编辑器。原 `Behavior` 继续保留，避免详情缺少统计字段导致计数清零。

读取通过 `AsyncLifecycleGuard` 隔离重试、切换记录和迟到结果；账号/公司失效后实例永久失效，同记录普通重建不重新读取或覆盖输入。路由累积等待已创建子页面的全部释放任务。

迁移方案、公司模板适配 skill 与 Mutualism `CLAUDE.md` 已同步新的读取约定。

## 验证结果

|检查|结果|证据|
|---|---|---|
|详情适配器契约|6 项通过|`record-tests.log`|
|详情 Gate 与真实路由|33 项通过（Gate 19、路由 14）|`entry-tests.log`|
|有效详情装配真实编辑页|通过|`composition-success.log`|
|数据层、编辑器、原表单结构化粘贴回归|110 项通过，包含上述 Gate 19 和适配器 6 项|`regression-tests.log`|
|目标源码与测试静态检查|无问题|`target-analyze.log`|
|整个 Mutualism 模块静态检查|仅原文件一条未使用导入警告|`mutualism-analyze.log`|
|Dart 格式与两仓库差异空白检查|通过|`format.log`、`diff-check.log`|
|Skill frontmatter 与详情规则检查|通过，使用系统 Ruby YAML 解析|`skill-check.log`|

合计 **124 项不同测试通过**：110 项回归加 14 项路由，不重复累计 Gate 或适配器测试。

全模块唯一警告位于用户原有 `lib/modules/mutualism/domain/entity/orient_result/orient_result_entity.dart:1` 的未使用 `behavior.dart` 导入，该文件未改动。

## 已复现并修正的边界

`body_content:{}` 原先在解码器结构投影时抛出 TypeError，导致无法显示原字段只读页。`gate-empty-body-before-fix.log` 保留失败证据；入口现在明确处理空对象，其他解码器结构不兼容也只读保护，不清理节点后保存。

其余自动化覆盖：

- 有 ID 无列表正文时仍能点击预览；无 ID 隐藏入口，直接打开无 ID 预览也不会生成空稿。
- 真实共享 HTTP 链路只传所选 id；列表 id 与 rootId 不同、ORIENT/RESULT 分别读取、空 ID 在请求前失败。
- 旧正文不回退；详情 null、空对象、未知格式分别只读保护；业务或网络失败可显式重试且不保存。
- 公司、账号、记录、槽位类型或编辑作者不符时不创建会话；退出或换记录后的迟到成功/错误不影响当前页面。
- 新建不读取详情；同记录重建不重复读取；原表单选择、保存返回与待办完成契约继续保留。
- 有效详情经生产 Repository、Gate、Composition 创建真实 `SaasGuidanceEditorPage`，其 Store 的记录身份、作者和正文来自详情，来源快照不变，行为对象和计数保留。
- 原编辑、保存、动态栏目、换图、长图及退出资源释放回归通过。

## 验证边界与待办

后续状态：保存成功后的同页详情读回已在[保存读回与正文无损验证](../saas-save-readback-20261108/report.md)实现并完成 Android 核验。以下保留本报告当时的验证边界。

测试中的 HTTP 响应来自本地服务或共享 Dio 的测试拦截器，没有连接真实业务后端或改写业务记录；本轮未安装 Android 新版或做真机联调。

本轮覆盖进入已有记录编辑/独立模板预览和重开。保存后同页预览仍使用本次服务端已确认的提交快照，来源列表仍由原成功事件刷新。“保存成功后立即再次读详情”的同页流程是独立待办，实施时需要区分保存成功与随后读取失败，避免重试读取变成重复提交。其他 review 发现未混入本轮修改。

人工联调建议：从四类列表分别打开导向/成果，断网后重试，读取期间切换公司或返回，再用长文完成保存、重开和分享；核对新详情中的作者和记录 ID，而非正文内部 ID。
