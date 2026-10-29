# 去掉预览用户栏右侧时间（2026-10-29）

按用户要求删除预览封面下用户信息行的右侧时间，保留头像、姓名、部门和职位。同步移除 example 页面及私有组件的时间参数、首页时间生成和传递，并更新接入说明。日期头部、正文、编辑菜单及底部分享点赞保持原有行为，不改变 bodyContent JSON。

验证：

- 修改的手写 Dart 已格式化，见 [format.txt](format.txt)。
- `flutter test --no-pub test/daily_guidance/journal_preview_user_test.dart test/daily_guidance/journal_page_mode_test.dart --reporter expanded`：7 项通过；覆盖用户栏、时间不显示、窄屏大字号、用户切换撤销、固定只读和真实首页消费者，见 [target-tests.txt](target-tests.txt)。
- `flutter analyze --no-pub`：No issues found，见 [example-analysis.txt](example-analysis.txt)。
- `git diff --check` 通过，见 [diff-check.txt](diff-check.txt)。

核心包公开 API、块协议、用户模板和 moke.json 未改动。本轮未重新安装手机应用，上一轮截图归档保留为历史证据。
