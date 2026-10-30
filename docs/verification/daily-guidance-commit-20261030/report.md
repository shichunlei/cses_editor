# 今日导向预览与图片分享提交前验证（2026-10-30）

用户确认正文与 logo 间距后要求提交。提交基于 main / b30ccab，包含当前相关的预览、图片分享、平台适配、纸张布局、UI 规则及验证归档。

## 最终行为与范围

- 预览采用沉浸式封面及安全区返回入口，分享和点赞继续固定悬浮；此前滚动隐藏按钮的改动已回滚，仅保留历史归档。
- 完整只读长图包含原封面、当前用户、日期、正文及品牌图片；提供图片查看、微信/朋友圈交接和系统文件保存，校验会话、拒绝重入并保留错误/取消边界。
- Android 的 FileProvider 仅授权应用临时分享目录；iOS 使用系统图片分享面板。示例 iOS 最低目标版本为 14，满足现有保存插件要求。
- 编辑与预览使用紧凑栏目间隔；用户实际空行及编辑能力保留。logo 白底与纸张米色一致，品牌页脚上边距 8px，最后栏目不重复补空白，保留用户已确认的效果。
- 同步 README、宿主接入说明及 UI skill，不修改核心包、块协议、AppFlowy 固定来源或正文 JSON 样例。

## 本轮验证

- `flutter test --no-pub --reporter expanded`：整个 example 共 223 项测试全部通过，见 [tests.txt](tests.txt)。
- `flutter analyze --no-pub`：整个 example No issues found，见 [analysis.txt](analysis.txt)。
- 本次涉及的 9 个 Dart 文件格式化完成，见 [format.txt](format.txt) 和 [regression-test-format.txt](regression-test-format.txt)。
- 首轮全量发现 6 项旧布局断言：4 项列表标记仍比较绝对屏幕坐标，与沉浸式预览的页头差异冲突；2 项软换行仍预期补足三行。改为相对栏目坐标及实际软行数，保留标记对齐、横线、换行、缩放及勾选保存断言；未改产品效果以迁就旧测试。初轮记录见 [initial-tests.txt](initial-tests.txt)。
- Android Manifest 与 FileProvider XML 已解析通过；Dart 核心库没有本轮改动。
- 工具日志仅清理行尾空格，不改结果内容；完成前运行工作区和暂存区 `git diff --check`，均通过。

## 已有平台与图片证据

本轮不重复执行原生构建、安装或真实外部发送。当前改动已有 [Android debug 构建](../journal-image-share-20261030/android-build.log)、[iOS 模拟器构建](../journal-image-share-20261030/ios-build.log) 通过的归档，来源和未验证边界见 [图片分享报告](../journal-image-share-20261030/report.md)。真实微信发送、朋友圈发布及 iOS 真机端行为仍未自动验证。

用户确认的实际样例图片见 [底部效果](../share-brand-confirmation-20261030/footer-detail.png) 与 [完整分享图](../share-brand-confirmation-20261030/full-share.png)。它们由当前 Flutter 分享流程生成，本轮提交未调整已确认的间距。
