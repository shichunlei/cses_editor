# SaaS 公司模板四项复核修正（2026-11-09）

| 问题 | 修复和验证 |
| --- | --- |
| 中企云链工作成果英文名 | 恢复 SaaS 原版 `GONGZUO CHENGGUO`。从 Android 历史工作成果进入预览并输出 739 × 2593 长图。 |
| 字体未完成就截图 | 首次画布绘制后等待当前字体请求结束，再等待重绘。字体失败沿用回退，等待超时可重试。回归测试延迟字体完成，断言完成前不显示分享面板。 |
| 窄屏日期与问候溢出 | 聚艺堂日期带保留最小高度并随日期内容布局，呈诺医学与久宴在原装饰区域内约束字号。360 逻辑像素宽度、1 倍和 2 倍字号回归通过。聚艺堂标准尺寸仍与原版像素一致。 |
| 六套随机模板 Logo 实际绘制偏窄 | 复用 `BottomLogoImageView`，按素材原比例计算高度并铺满画布。测试用窄源图检查长图的两侧实际像素，暖色波浪在 Android 生成 739 × 1625 长图。 |

荣耀 MTN-AN00 使用临时模板分发依次验证聚艺堂、暖色波浪与中企云链。三张长图均保存到相册，渠道页显示微信、朋友圈和保存。使用既有测试记录，四项复核未修改业务正文。聚艺堂原圆角方形头像也改为复用模板已有头像方法，后续编辑流程回归覆盖。

| 模板 | 真机证据 |
| --- | --- |
| 聚艺堂 | [预览](result-review-jyt-preview-small.png) · [分享面板](result-review-jyt-share-small.png) · [相册长图](jyt-album.jpg) |
| 暖色波浪 | [预览](result-review-warm-preview-small.png) · [分享面板](result-review-warm-share-small.png) · [相册长图](warm-album.jpg) |
| 中企云链工作成果 | [预览](result-review-zqyl-top-small.png) · [分享面板](result-review-zqyl-share-small.png) · [相册长图](zqyl-result-album.jpg) |
