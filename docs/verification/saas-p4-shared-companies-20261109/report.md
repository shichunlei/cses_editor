# SaaS 诚兴伟业、大国食安及江阴顺航模板验收（2026-11-09）

诚兴伟业沿用原圆顶相框、日期、拼音署名和正文锯齿裁剪。Play 和 Noto Serif 通过既有加载器注册到内存，超时由同一预览会话与长图使用一致的回退。大国食安和江阴顺航直接复用编辑器已适配的邮票构图、原邮票边框、头像与背景组件。短文预览由主图吸收缺口，长文在主图下限下自然增长。

| 公司入口 | 预览与长图品牌 |
| --- | --- |
| 诚兴伟业 | `chengxingweiye_logo_02.webp` |
| 大国食安 | `daguoshian_logo_02.webp` |
| 江阴顺航化工 | `jyshunhang_logo_02.webp` |
| 江阴顺航汽车拆解 | `jyshunhang_logo_02.webp` |

江阴顺航两个公司 ID 分别核对原注册页、品牌目录和新模板品牌。固定画布、照片、作者、日期、字体替身及 Logo 槽后，三套模板空正文、3 行及 30 行共 9 组对照像素一致。[原版对照](original-comparison/)

在荣耀 MTN-AN00 上使用既有测试账号和真实测试后端。临时构建轮流将四个公司 ID 传给正式模板解析器，账号、保存和详情仍使用测试账号。四次分别在编辑页追加标记，通过原接口保存，检查保存后预览、分享渠道页、本地相册和退出后重新进入。四次重开均读到最新标记；化工和汽车拆解分别生成了各自验收长图，底栏按原版显示同一江阴顺航品牌。

| 公司入口 | 真机证据 |
| --- | --- |
| 诚兴伟业 | [编辑](result-p4-cxwy-keyboard-small.png) · [预览](result-p4-cxwy-preview-small.png) · [重开](result-p4-cxwy-reopen-small.png) · [分享](result-p4-cxwy-share-small.png) · [相册](cxwy-album.jpg) |
| 大国食安 | [编辑](result-p4-dgsa-keyboard-small.png) · [预览](result-p4-dgsa-preview-small.png) · [重开](result-p4-dgsa-reopen-small.png) · [分享](result-p4-dgsa-share-small.png) · [相册](dgsa-album.jpg) |
| 江阴顺航化工 | [编辑](result-p4-jysh-keyboard-small.png) · [预览](result-p4-jysh-preview-small.png) · [重开](result-p4-jysh-reopen-small.png) · [分享](result-p4-jysh-share-small.png) · [相册](jysh-album.jpg) |
| 江阴顺航汽车拆解 | [编辑](result-p4-qccj-keyboard-small.png) · [预览](result-p4-qccj-preview-small.png) · [重开](result-p4-qccj-reopen-small.png) · [分享](result-p4-qccj-share-small.png) · [相册](qccj-album.jpg) |

本批 32 项测试全部通过，包含成果导向和工作成果的保存重开及分享。静态检查通过。全量回归 476 项通过，另两项失败来自工作区既有的爱能智亚 V2 品牌文件名不一致，现有实现指定 `_02.webp`，测试期望 `.webp`。真机测试类型为成果导向。

验收后手机已恢复正常公司分发版本，安装包资源清单无本次字体文件。[正常分发首页](result-p4-normal-home-small.png)
