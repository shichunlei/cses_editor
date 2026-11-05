# 当前用户资料调整

日期：2026-11-05。

宿主当前用户改为师春雷、技术部、移动端开发。同一示例用户 ID 在选人目录中的资料同步更新，保留原有稳定身份，不改写正文或引入账号服务。预览与分享继续使用宿主注入的当前用户资料。

验证：

- 两个修改的手写 Dart 文件格式化通过。
- 修改文件与对应消费者静态分析通过，见 [analysis.log](analysis.log)。
- `journal_page_mode_test.dart` 和 `journal_preview_user_test.dart` 共 7 项回归通过，见 [tests.log](tests.log)，首页预览断言已核对姓名和“技术部 · 移动端开发”。
- `git diff --check` 通过。
