# 分享图片 logo 米色底（2026-10-30）

将分享长图的 logo 页脚背景改为与正文相同的 `#FAF8F0`。图片自身的白色留白在展示时通过 multiply 色彩混合融入相同米色，保留 logo 图形、深色文字和 slogan；原始 PNG 资源不修改。正文、图片大小、分享与保存流程均保持原有实现。

同步 cses_editor_ui skill 与场景参考中的品牌页脚背景规则，不扩大到其他界面或根包。

验证：

- `flutter test --no-pub --dart-define=SAVE_BEIGE_BRAND_SCREENSHOT=true test/daily_guidance/journal_preview_actions_test.dart --reporter expanded`：3 项通过，见 [target-tests.txt](target-tests.txt)。包含完整分享 PNG、分享防重入/会话变化、窄屏大字及固定操作。
- 在已有生成图片测试中读取导出 PNG 的 RGBA，验证页脚外层与图片底部留白均为 `[250, 248, 240, 255]`，防止只改容器后仍留下白块；不增加镜像实现的独立测试。
- `flutter analyze --no-pub lib/daily_guidance/journal_share_page.dart test/daily_guidance/journal_preview_actions_test.dart`：No issues found，见 [analysis.txt](analysis.txt)。
- [poster.png](poster.png)：本轮实际生成的分享长图，已查看并确认 logo 背景与纸张连续。正文采用默认测试字体，仅用于底色检查，不代表真机中文排版。
- 手写 Dart 已格式化，`git diff --check` 通过。原 logo PNG、正文 JSON 与其他工作区改动保留，未重新安装手机应用。
