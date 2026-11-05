# 保存提交参数控制台输出

日期：2026-11-05。

在 `ApiJournalStore.write` 完成正文和派生业务字段组装后、调用 `api.save` 前，以 `debugPrint` 打印当前 `recordId` 和实际提交的完整 JSON。日志标记为 `[ApiJournalStore.write]`，JSON 使用两空格缩进，长行按 1000 字符换行输出。导向、成果及重试均经过相同日志位置，日志表示提交请求，不代表保存成功。

验证：

- 修改的手写 Dart 文件格式化通过。
- example 全部 lib 与目标测试静态分析通过，见 [analysis.log](analysis.log)。
- `empty_guidance_flow_test.dart` 的 5 项既有回归全部通过，覆盖两类空文档、编辑保存、分享和重开。实际控制台输出亦归档于 [tests.log](tests.log)，包含记录身份与完整 JSON。
- `git diff --check` 通过。
