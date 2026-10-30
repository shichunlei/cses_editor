# 完整记录提交与业务字段提取验证

日期：2026-10-30。

## 实现范围

- `GuidanceApi.save(recordId, record)` 接收完整记录。`ApiJournalStore` 保留成功读取的完整 JSON 快照，保存时先编码最新 bodyContent，再从同一份正文重算 thinking、selfCheck、helpItems、navigatorItems、customData；其他业务字段及未知扩展字段保留读取值。
- `GuidanceRecordFields` 通过 dailySection / dailyCustomField.key 识别栏目，通过段首 dailyTag=help/pilot 分流条目，避免重复归入栏目摘要；两个数组分别按文档顺序从 1 编号。
- 结构化引用输出 @名称，并按字段/条目收集 mentionId、mentionName，保留人员、任务等引用，按 ID 去重；普通手输 @文本不推测身份。
- 保留段内空格和中间换行，去掉尾部空白段落。空内容全量提交空串、空 mentions/条目数组；空自定义字段保留键和空内容，已移除字段不再进入 customData。
- Mock 深拷贝请求并整体替换完整记录，拒绝部分字段提交与错误身份。保存模式仍由原页面控制，不增加自动提交。
- 更新 docs/data-format.md 与 docs/integration.md。未修改 Flutter UI、根包公开入口或 BlockCraft 块协议，无新增依赖。

## 验证结果

- `dart format`：四个修改/新增的手写 Dart 文件完成格式化。
- example：`flutter analyze --no-pub` 通过，无问题，见 analyze.log。
- example：`flutter test --no-pub test/daily_guidance` 通过，223 项，见 tests.log。包含 API 消费者、编辑/预览、引用头像、键盘菜单和原有业务交互回归。
- 新增专项测试：五类派生结果与原始 JSON 样例逐项完全一致；人员和任务混合引用；引用去重与字段归属；手输 @文本；空标签；编号；换行/空格；清空旧内容与引用；其他业务/扩展字段保留；后台响应隔离；拒绝部分提交和错误身份；读取前拒绝写入。
- 原有保存测试改为断言完整键集及字段值，并核验实时自定义内容、领航员引用和任务引用。失败重试、迟到保存会话检查继续通过。
- 首轮目标测试发现新增测试预期遗漏编辑器插入人员时自带的尾部空格；修正预期以遵循保留正文空格的规则后，全目录回归通过。
- `git diff --check` 通过。

## 接入边界

当前仓库通过宿主注入 GuidanceApi，示例仍使用内存 Mock；本轮验证覆盖完整请求的组装、服务契约和 Mock 落库/重读，未进行真实 HTTP 后端联调。真实宿主的 save 实现应发送完整 record，不再仅发送 bodyContent 补丁。
