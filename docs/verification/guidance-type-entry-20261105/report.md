# 空文档类型参数与首页选择

日期：2026-11-05。

## 变更

- `createEmptyGuidanceRecord(now, orientType: ...)` 新增必填命名参数：`ORIENT` 为今日导向，`RESULT` 为今日成果；其他值抛出 `ArgumentError`。所有当前调用方已更新。
- 创建日期仍按传入时间的本地年月日。类型同步到 `orientType`、正文 `meta.dailyType`、填写区标题以及派生的 `dailyOrient` / `dailyResult`；另一类型的字段显式为 null。
- `bizType` 保留原业务族 `DAILY_ORIENT`，通过已有 `orientType` 区分导向/成果；没有新增或改变正文协议。
- 首页通过可换行的选择控件选择“今日导向 / 今日成果”，默认导向，再进入编辑或预览。打开页面期间禁用选择，当前路由绑定固定存储身份。
- 首页分别持有两类记录的 mock API 和存储；类型切换不覆盖另一类保存结果。同次启动重开恢复各自已保存内容，应用重启后重新创建当天空文档。
- README 与项目 UI 技能已同步对应规则。保留此前工作区变更。

## 验证

- 本次 4 个手写 Dart 文件格式化通过。
- example 全部 `lib`、受影响测试和全部 `integration_test` 静态分析通过，见 [analysis.log](analysis.log)。
- 27 项相关测试全部通过，见 [tests.log](tests.log)：
  - `empty_guidance_flow_test.dart`：两类文档跨年日期、空白保存、非法类型、独立记录身份、切换保留正文、成果预览，以及 ORIENT/RESULT 各自的编辑、完整保存字段、分享页标题/PNG 和重开恢复。
  - `journal_page_mode_test.dart`：既有默认导向入口和只读边界。
  - `journal_device_layout_regression_test.dart`：320dp、大字与键盘布局下，成果类型选择和预览入口可达。
  - `body_content_api_test.dart`：既有完整记录保存、引用、失败重试及迟到结果保护。
- 本轮未重新安装手机，前轮真机截图不作为新增类型选择界面的截图验收。
- `git diff --check` 通过。
