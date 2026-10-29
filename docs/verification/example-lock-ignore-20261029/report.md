# 示例锁文件取消跟踪

日期：2026-10-29。

按用户最新要求，移除 `example/.gitignore` 中的锁文件例外，恢复由 `*.lock` 忽略 `example/pubspec.lock`。使用 `git rm --cached` 仅取消Git跟踪，本地文件完整保留。

验证：本地文件SHA256在操作前后相同；`git ls-files` 不再包含该路径；`git check-ignore` 确认忽略规则生效；工作区及暂存区 `git diff --check` 通过。本轮仅调整版本控制规则，无Dart或依赖版本修改，不重复运行Flutter分析和测试。

此前gitignore及首次提交复查记录描述当时状态；本记录为当前锁文件提交策略。已有首次提交保留历史，通过后续中文提交修正。
