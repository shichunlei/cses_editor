# SaaS 卡思琦教育、润通求本及锦味康验收（2026-11-09）

卡思琦教育复用原邮票框、虚化背景、头像与正文框。润通求本保留橙色画布、原日期牌和底部装饰。锦味康使用原裁剪器，按实际图文位置保留主图两侧卡口、圆角、底部红带和品牌图案。润通求本与锦味康的原字体由已有加载器注册到内存，字体超时时同一会话的预览与长图共用回退字形。

| 公司 | 原彩色或主品牌文件 |
| --- | --- |
| 卡思琦教育 | `kasq_logo_02.webp` |
| 润通求本 | `runtongqiuben_logo.webp` |
| 锦味康 | `jinweikang_logo.webp` |

固定画布、照片、时间、作者、字体替身与 Logo 槽后，空正文、3 行、30 行共 9 组原版像素对照一致。短文预览只增加主图高度，润通求本的 205.h 和锦味康的 100.h 原底部装饰净空保持固定。[原版对照](original-comparison/)

在荣耀 MTN-AN00 上用同一测试账号连接真实测试后端。验收包将三个公司 ID 轮流交给正式模板解析器。用系统输入法新建一条工作成果，在卡思琦教育模板保存并重开，再用润通求本追加多行，最后用锦味康继续编辑。每个模板都验证保存后详情预览、退出重开、长图渠道页及保存到相册。测试使用同一账号，正式公司分发另由自动化验证。

| 模板 | 真机证据 |
| --- | --- |
| 卡思琦教育 | [编辑](result-p4b-kasq-keyboard-small.png) · [预览](result-p4b-kasq-preview-small.png) · [重开](result-p4b-kasq-reopen-small.png) · [长图](kasq-album.jpg) |
| 润通求本 | [编辑](result-p4b-rtqb-keyboard-small.png) · [预览](result-p4b-rtqb-preview-small.png) · [重开](result-p4b-rtqb-reopen-small.png) · [长图](rtqb-album.jpg) |
| 锦味康 | [编辑](result-p4b-jwk-keyboard-small.png) · [预览](result-p4b-jwk-preview-small.png) · [重开](result-p4b-jwk-reopen-small.png) · [长图](jwk-album.jpg) |

本批 32 项测试及静态检查通过，自动化覆盖成果导向和工作成果两类保存、重开和分享。全量回归 506 项通过，爱能智亚 V2 的两项既有断言仍因品牌文件名差异失败。

手机已恢复正常分发版本，并通过真实详情重开读到全部测试标记。验收包和正常分发包均未打包本批字体文件。[正常分发重开](result-p4b-normal-reopen-small.png)
