# SaaS 树人教育、灵兰中医和锋创科技验收（2026-11-09）

树人教育复用原弧形裁剪，浅绿正文与页脚连续。灵兰中医复用原斜切裁剪和背景图组件，主图补高时保持原斜切深度。锋创科技保留白色主图框、红色装饰和双层正文卡，头像与作者行仍在两层卡片之间。正文少时编辑态用横格补到屏底，预览由主图补高，Logo 只在预览和分享显示。

| 公司 | 原品牌文件 |
| --- | --- |
| 树人教育 | `shuren_logo_02.webp` |
| 灵兰中医 | `linglanzhongyi_logo_02.webp` |
| 锋创科技 | `69b79d28669bd30d669950ac_02.webp` |

固定日期、图片、字体替身和正文槽后，空正文、3 行和 30 行共九组与 SaaS 原版像素一致。树人教育和灵兰中医的字体沿用内存加载与回退机制，验收包和正常分发包均未打包本批字体。[原版对照](original-comparison/)

荣耀 MTN-AN00 使用同一账号和真实测试后端。验收包只在模板解析处轮换三套视觉，公司身份和接口仍走正式业务。逐套打开已有工作成果，弹出键盘追加测试标记，保存后检查预览，首次分享进入微信、朋友圈和保存渠道页，保存长图至相册，再重开确认各次修改均由详情读回。

| 模板 | 真机证据 |
| --- | --- |
| 树人教育 | [编辑](result-p4c-srjy-keyboard-small.png) · [预览](result-p4c-srjy-preview-small.png) · [重开](result-p4c-srjy-reopen-small.png) · [分享页](result-p4c-srjy-share-small.png) · [相册长图](srjy-album.jpg) |
| 灵兰中医 | [编辑](result-p4c-llzy-keyboard-small.png) · [预览](result-p4c-llzy-preview-small.png) · [重开](result-p4c-llzy-reopen-small.png) · [分享页](result-p4c-llzy-share-small.png) · [相册长图](llzy-album.jpg) |
| 锋创科技 | [编辑](result-p4c-fckj-keyboard-small.png) · [预览](result-p4c-fckj-preview-small.png) · [重开](result-p4c-fckj-reopen-small.png) · [分享页](result-p4c-fckj-share-small.png) · [相册长图](fckj-album.jpg) |

本批 31 项定向测试通过，覆盖公司分发、短文编辑横格、预览主图补高、长文分享，以及成果导向和工作成果两类创建、保存与重开。编辑器、路由及对应测试的静态分析通过。SaaS 全量回归 2308 项通过，另有 11 项失败，其中 2 项是爱能智亚 V2 的既有品牌文件名断言，9 项来自声纹和会议字幕接口相关测试。

手机已安装正常公司分发包，重开后仍能读到三次保存的标记。[正常分发重开](result-p4c-normal-reopen-small.png)
