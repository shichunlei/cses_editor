# 分享图正文与 logo 紧凑衔接（2026-10-30）

收紧分享长图正文末尾与 logo 之间的留白，继续使用与纸张一致的米色。

- 分享截图的最后一个栏目不再补一行自动底部留白，交由品牌页脚单独控制间距。
- logo 外层改为左右 16px、上 8px、下 16px；保留原图片尺寸比例、原图白底米色混合与完整 slogan。
- 普通编辑及预览页面的栏目间距保持原规则；不改变正文数据、分享动作、截图宽度或其他栏目。
- 同步 UI skill、场景参考及接入说明。

验证：

- `flutter test --no-pub --dart-define=SAVE_BEIGE_BRAND_SCREENSHOT=true --dart-define=BRAND_POSTER_PATH=../docs/verification/share-brand-spacing-20261030/poster.png test/daily_guidance/journal_preview_actions_test.dart test/daily_guidance/journal_preview_spacing_test.dart --reporter expanded`：5 项通过，见 [target-tests.txt](target-tests.txt)。覆盖完整 PNG、米色像素、分享防重入/会话失效、窄屏大字及普通编辑/预览间距。
- `flutter analyze --no-pub lib/daily_guidance/journal_surface.dart lib/daily_guidance/journal_share_page.dart test/daily_guidance/journal_preview_actions_test.dart`：No issues found，见 [analysis.txt](analysis.txt)。
- [poster.png](poster.png)：本轮实际生成并查看的长图，同一样例从 780×3072 缩短到 780×2976，去除叠加留白，正文与 logo 均完整保留。正文为默认测试字体，此图只用于页尾衔接检查，不代表真机中文字体。
- 手写 Dart 已格式化，`git diff --check` 通过；未重新安装手机应用。

保留原 logo 图片、正文 JSON 和其他工作区修改，无核心公开 API 或块协议变更。
