# 连续关闭栏目失败修复（2026-11-03）

## 原因与修复

在 MTN AN00（Android 16 / API 36）当前编辑页直接点击“金额”的关闭入口，捕获 `FormatException: 关闭栏目无效`，堆栈为 `closedJournalSections → validateJournalDocument → _allows → closeSection`。

隐藏区仍沿用仅有“感悟、自检”时的最多两个栏目限制。关闭这两个栏目后，再关闭“金额”会使隐藏区长度成为 3，预演校验拒绝整个事务。上轮放宽自定义栏目身份的改动未解决该问题，本轮已恢复原身份校验。

隐藏区数量现在按正文块总容量限幅；身份、唯一性、结构、可见与隐藏正文共用总容量的校验继续生效。页面栏目操作异常交给 Flutter 错误管道报告，同时保留原失败提示和内容。

## 回归证据

- 扩展接口样例回归：依次关闭感悟、自检、金额，验证仅余首栏目、三个隐藏栏目、撤销恢复金额原节点、重做隐藏、保存重开隐藏内容完整、恢复感悟正文。
- 修复前该回归稳定失败，见 [regression-before.txt](regression-before.txt)。
- 修复后接口与动态栏目回归共 37 项通过，见 [tests-after.txt](tests-after.txt)。
- `cd example && flutter analyze --no-pub`：无问题，见 [analyze.txt](analyze.txt)。
- 已格式化修改的手写 Dart；`git diff --check` 通过。

## 真机验证

保留手机当前页面和编辑会话，热更新修复后点击同一关闭入口：“金额”消失且无失败提示；点击撤销后“金额”和正文 `11111` 完整恢复，再重做成功关闭。未点击保存提交用户当前记录。

- [原页面](device-before.png)
- [关闭成功](device-after.png)
- [撤销恢复正文](device-undo.png)
- [重做后最终页面](device-final.png)
- 最新 debug APK 构建成功，见 [build.txt](build.txt)。
- 使用 `adb install -r --dont-kill` 覆盖安装返回 Success；系统仍结束了旧进程。随后启动正常入口并打开编辑页，应用按示例既有规则重新加载初始样例。热更新阶段的关闭/撤销证据不作为重装后的页面状态。
