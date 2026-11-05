# 汇丰永盛 V2 沉浸式编辑

日期 2026-11-05

HFYS V2 试点页面移除顶部操作栏。海报从系统安全区开始，键盘收起后底部提供返回、保存、撤销和重做。键盘打开时只保留编辑器键盘菜单，感悟、自检、都来帮和领航员由菜单按需添加。保存后继续使用只读预览和分享入口。

验证命令在 `example/` 执行。

```sh
flutter analyze --no-pub lib/daily_guidance/local_journal_page.dart integration_test/hfys_v2_pilot_device_test.dart
flutter test --no-pub test/daily_guidance/{journal_page_mode,journal_sticky_cover,journal_keyboard_toolbar}_test.dart --reporter expanded
flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/hfys_v2_pilot_device_test.dart -d A92G6R5704004108
```

静态分析及 20 项相关回归通过。Android 16 真机集成测试确认页面没有 AppBar 或顶部添加入口，四项均可从键盘横向菜单添加。键盘打开时底部保存隐藏，收起后可保存，随后能生成分享长图并从本机文件重开续编。
