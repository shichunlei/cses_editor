# SaaS 鸿尊餐饮、老淮安和隆阳电器验收（2026-11-09）

| 模板 | 原品牌文件 | 原版构图 |
| --- | --- | --- |
| 鸿尊餐饮 | `hongzuncanyin_logo.webp` | 原邮票整卡按正文实测高度定位凹口，前景主图与虚化衬图分别取景 |
| 老淮安 | `laohuaian_logo.webp` | 保留 480.h 主图下限、原边花、环形题字、红底和日期牌 |
| 隆阳电器 | `longyangdianqi_logo.webp` | 主图铺满原画布，旋转后卡借用前卡尺寸，正文只渲染一次 |

固定图片、日期、作者、字体替身和 Logo 槽，按空正文、3 行、30 行对照。老淮安和隆阳电器像素一致。鸿尊餐饮凹口、底色分界和装饰一致，每组只有头像圆边 8 个像素的抗锯齿差异，单颜色通道最大差值 7。隆阳电器沿用已有的内存字体加载机制，两种安装包均未打包本批字体。[原版对照](original-comparison/)

上一批回归同时覆盖树人教育、灵兰中医及锋创科技的 Logo 自然高度。展开屏测试在 800 × 896 逻辑像素窗口中验证预览和截图宽度都是原版的 414。锋创科技底部斜带按正文卡尾定位，三组原版像素对照通过。展开屏验证使用自动化尺寸模拟。

本批定向测试 33 项通过，包含成果导向、工作成果两类创建、保存、详情重开和长图。模板、相关组件和测试静态检查通过。

日导向模块回归 619 项通过，爱能智亚 V2 两项既有测试仍因品牌文件名断言失败。

荣耀 MTN-AN00 真机连接测试后端，验收包用同一账号轮换三个模板，公司身份及保存、详情接口走正常业务。三套均已编辑、保存、重新打开、预览并首次生成长图，微信、朋友圈、保存渠道页正常显示，实际保存到相册。鸿尊预览随机换图也通过。隆阳首次分享的英文字体和日期使用回退字形，预览与长图一致。

| 模板 | 真机证据 |
| --- | --- |
| 鸿尊餐饮 | [编辑](result-p5a-hzcy-keyboard-small.png) · [预览](result-p5a-hzcy-preview-small.png) · [换图](result-p5a-hzcy-random-small.png) · [重开](result-p5a-hzcy-reopen-small.png) · [分享页](result-p5a-hzcy-share-small.png) · [相册长图](hzcy-album.jpg) |
| 老淮安 | [编辑](result-p5a-lha-keyboard-small.png) · [预览](result-p5a-lha-preview-small.png) · [重开](result-p5a-lha-reopen-small.png) · [分享页](result-p5a-lha-share-small.png) · [相册长图](lha-album.jpg) |
| 隆阳电器 | [编辑](result-p5a-lydq-keyboard-small.png) · [预览](result-p5a-lydq-preview-small.png) · [重开](result-p5a-lydq-reopen-small.png) · [分享页](result-p5a-lydq-share-small.png) · [相册长图](lydq-album.jpg) |

手机已恢复正常公司分发包，重开后从详情读到三次验收标记。[正常分发重开](result-p5a-normal-reopen-small.png)
