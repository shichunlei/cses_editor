# 汇丰永盛 V2 模板内编辑试点

日期 2026-11-05

## 范围

- 从 example 首页的「汇丰永盛 V2 · 模板编辑」进入独立路由。倾斜相框、日期牌、深色画布、撕纸正文和品牌页脚沿用 HFYS V2 的布局。主图使用 example 随包山景。原公司图库、换图和取景留在 SaaS。
- 正文复用一个块编辑会话。感悟、自检按需开栏，都来帮、领航员按需添加人员业务行。顶部添加入口和键盘快捷栏共用业务动作。
- 使用应用支持目录内独立的 `hfys-v2-daily-guidance.json`。保存后进入同版只读预览，重新打开从文件恢复编辑。分享使用保存后的正文快照、同版画布及页脚，支持输出完整 PNG。
- 品牌图来自 SaaS 的 `HfysV2TemplatePage` 使用的 `hfyongsheng_logo.webp`，原始资源路径为 `company_logo/hfyongsheng_logo.webp`。素材随 example 打包，SHA-256 为 `c238a44336537bce458b907cb471f98fc141918b531df00b9cf867714425e41e`。

## 验证

```sh
cd example
flutter analyze --no-pub lib/main.dart lib/daily_guidance/journal_surface.dart lib/daily_guidance/journal_share_page.dart lib/daily_guidance/local_journal_page.dart lib/daily_guidance/ui/hfys_v2_poster.dart integration_test/hfys_v2_pilot_device_test.dart
flutter test --no-pub test/file_journal_store_test.dart test/daily_guidance/{empty_guidance_flow,journal_last_section_fill,journal_share_minimum_height,journal_page_mode,journal_sticky_cover,journal_save_empty_sections}_test.dart --reporter expanded
flutter test --no-pub integration_test/hfys_v2_pilot_device_test.dart -d A92G6R5704004108 --reporter expanded
```

- 静态分析通过。文件存储、原今日导向/成果、预览、末栏、长图布局与空栏目清理共 26 项回归通过。
- Android 16 真机通过试点链路。点击纸面定位正文，追加长文和感悟、自检、都来帮、领航员。保存切换只读，校验文件落盘。从分享页导出的 PNG 超过一屏且包含底部画布，导出端口收到原始 PNG。关闭后以新的文件存储实例重开，正文快照一致，并能继续编辑和再次保存。
- [真机分享预览](hfys-v2-share-preview.png)由 `flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/hfys_v2_pilot_device_test.dart --dart-define=HFYS_DEVICE_SCREENSHOT=true -d A92G6R5704004108` 生成。导出使用测试端口，未向外部应用发送图片。
- 使用 `flutter run --no-pub --no-resident -d A92G6R5704004108` 安装并启动常规应用入口。通过真机触屏打开试点、添加感悟，使用系统键盘输入 `qwe`，保存后查看分享图，返回首页重开确认文字仍在且页面恢复编辑。检查结束时试点页面保持打开。
