# Android 真机自定义字段保存验证

## 结果

Android 16 真机验证“关闭原金额自定义栏目，新增多个自定义栏目，保存并重开”时发现读取失败。关闭栏目会把 `custom:<key>` 写入 `mobileGuidanceView.hiddenSections`，但 `BodyContentCodec.decode` 只允许 `reflection` / `self-check`，因此拒绝了合法的隐藏自定义栏目，页面显示保存失败。

校验现已改为允许模板中实际存在的栏目身份，同时仍拒绝未知字段。Android 16 真机关闭金额、添加三个字段、分别写入正文、保存并重新打开后通过。另增加隐藏自定义字段的编码往返回归测试。

## 验证

- Android 16 MTN AN00：`daily guidance saves bodyContent through the host API` 真机集成流程通过。
- `flutter test --no-pub test/daily_guidance/body_content_api_test.dart --plain-name 'hidden custom field remains valid and round trips' --reporter expanded`：通过。
- 相关文件 `flutter analyze --no-pub`：通过。
- `git diff --check`：通过。
