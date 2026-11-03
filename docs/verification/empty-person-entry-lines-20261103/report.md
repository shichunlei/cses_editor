# 删除人员后的业务空行横格修复

日期：2026-11-03。

## 原因与调整

删除领航员或都来帮的人员后，业务标签仍保留。横格绘制原本扫描整行并选择最宽文字；正文为空时，较宽的业务标签被误选为正文，横线按较小标签的行框绘制，从而出现行距变窄。

增加宿主正文扫描边界 `JournalRuledTextScope`，业务行只标记原生正文子树。横格优先使用显式正文边界，未配置边界的普通正文保持原有扫描方式。标签不再参与横格行框计算；不增加正文字符，不修改删除、身份或历史事务，不引入资源或协议改动。此前工作区修改保留。

## 验证

新增回归在修复前 4 项失败，证据见 `reproduction.log`：空业务行横线位于约 24/47.5 而非正常 32/64。

使用生产输入法删除增量验证 pilot/help、320 宽、1/2 倍字号、仅删除人员且保留空格/连同空格全部删除，检查行尺寸和横线位置、保留业务标签、撤销重做及预览一致。既有纯人员回车、大字、正文换行和栏目间距测试一并通过。

在 example 包执行：

```sh
dart format lib/daily_guidance/guidance_entries.dart lib/daily_guidance/journal_ruled_content.dart lib/daily_guidance/journal_ruled_text_scope.dart test/daily_guidance/journal_native_mentions_test.dart
flutter analyze --no-pub lib/daily_guidance/guidance_entries.dart lib/daily_guidance/journal_ruled_content.dart lib/daily_guidance/journal_ruled_text_scope.dart test/daily_guidance/journal_native_mentions_test.dart
flutter test --no-pub test/daily_guidance/journal_native_mentions_test.dart test/daily_guidance/journal_rules_test.dart test/daily_guidance/journal_preview_spacing_test.dart test/daily_guidance/dynamic_journal_test.dart --reporter expanded
```

4 个测试文件共 47 项测试通过；静态分析无问题，根目录 `git diff --check` 通过。

本轮未构建设备安装包或进行真机验收。不涉及块协议、依赖或宿主服务变更。
