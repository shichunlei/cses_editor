# 纯人员业务行回车布局修复

日期：2026-11-03。

## 问题与修复

领航员或都来帮选人后，光标紧贴人员对象、位于尾随空格之前时回车，空格进入下一段，原行只剩 WidgetSpan。缺少普通文字提供行框后，纸张横线位置由 32 缩到 21（两倍字号由 64 缩到 42），姓名与业务标签出现纵向偏移。

在宿主 `decorateGuidanceMention` 中，仅对没有普通正文的原生人员引用提供正文行高的展示约束并居中。保留原生卡片、头像、点击和字号继承；不向正文补空格或隐藏字符，不修改段落拆分、对象身份、历史或块协议。跨目录引用仍走公开入口。其他工作区修改保留。

## 验证

修复前新增回归在四组纯对象场景失败，记录见 `reproduction.log`。修复后使用生产输入法增量提交回车，覆盖 320 宽、1/2 倍字号、pilot/help、对象后/尾随空格后两个光标位置，检查原行及下一行尺寸、姓名居中、横线纵坐标、正文对象保留、撤销重做和只读预览一致。

在 example 包执行：

```sh
dart format lib/daily_guidance/guidance_entries.dart test/daily_guidance/journal_native_mentions_test.dart
flutter analyze --no-pub lib/daily_guidance/guidance_entries.dart test/daily_guidance/journal_native_mentions_test.dart
flutter test --no-pub test/daily_guidance/journal_native_mentions_test.dart test/daily_guidance/dynamic_journal_test.dart test/daily_guidance/journal_rules_test.dart --reporter expanded
```

静态分析无问题；3 个文件共 41 项测试通过。根目录 `git diff --check` 通过。

本轮未构建设备安装包、未做真机输入法与截图验收。此改动仅为宿主展示修复，不改变块协议或依赖。
