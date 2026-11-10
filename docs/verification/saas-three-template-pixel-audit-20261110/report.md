# SaaS 中企云链、汇丰永盛 V2、成塔服饰 V2 像素与真机验收

2026-11-10。三套模板加入 SaaS 的统一原版对照。用例直接渲染原模板的视觉构建器和对应的编辑器模板。每套覆盖 0、3、30 行正文槽，画布宽 414 逻辑像素，短图高 896，长图高 2500，设备像素比 1，顶部安全区 24。两边使用相同的本地图、作者头像、日期、下午问候和正文占位组件。

三套首次比较的差异都集中在头像。编辑器原先在宿主通用头像外加一层白色圆底，和 SaaS 原头像的白边绘制及裁切方式有出入。成塔服饰的通用头像直径也小于原白边内圈。已复用 SaaS 的 `CircleAvatarImage`，恢复中企云链 29.w、汇丰永盛 V2 25.w、成塔服饰 V2 30.w 的头像半径及 3.w 白边。九组的差异均为 0 像素。

对照图中的色块主图、测试字形与紫色品牌占位用于复现版式。中企云链的品牌占位在对照中按原版宽度布置，实际预览及分享沿用满宽 Logo；编辑态隐藏 Logo、顶部悬浮操作和短文编辑横格继续沿用。预览短文的额外高度仍由主图补足，正文自然收尾。现有预览及分享用例分别验证这些行为。

| 模板 | 空正文 | 3 行 | 30 行 |
| --- | --- | --- | --- |
| 中企云链 | [原版](zqyl-0-original.png) / [新版](zqyl-0-editor.png) | [原版](zqyl-3-original.png) / [新版](zqyl-3-editor.png) | [原版](zqyl-30-original.png) / [新版](zqyl-30-editor.png) |
| 汇丰永盛 V2 | [原版](hfys-v2-0-original.png) / [新版](hfys-v2-0-editor.png) | [原版](hfys-v2-3-original.png) / [新版](hfys-v2-3-editor.png) | [原版](hfys-v2-30-original.png) / [新版](hfys-v2-30-editor.png) |
| 成塔服饰 V2 | [原版](ctfs-v2-0-original.png) / [新版](ctfs-v2-0-editor.png) | [原版](ctfs-v2-3-original.png) / [新版](ctfs-v2-3-editor.png) | [原版](ctfs-v2-30-original.png) / [新版](ctfs-v2-30-editor.png) |

统一套件 48 套共 144 项通过。三套模板的成果导向和工作成果共 6 项流程测试通过，覆盖创建、保存、重开继续编辑和长图生成。SaaS 互生模块全量回归 722 项通过，变更文件通过 Dart 静态分析。

中企云链使用宿主已有的问候图标字体及波浪装饰。测试使用现有字体夹具，本次未增加字体文件。以上证据为固定条件下的像素对照。

## Android 真机复测

2026-11-10，荣耀 MTN-AN00，Android 16。手机上使用北京一起嗨网络科技有限公司的测试账号和同一条已有成果导向。验收包仅指定所选模板、品牌和中企云链展示简称，账号、记录、保存及详情均走原测试接口。该账号的公司列表无三家公司，实际公司成员账号自动分发及权限另计。

每套在编辑页检查原头像，弹出键盘并追加标记，保存后检查预览，再从互生入口重开确认标记读回。三套都打开微信、朋友圈、保存渠道面板，实际保存到系统相册。相册 JPEG 均为 739 × 1625，包含正文和相应公司 Logo。测试执行到相册保存，微信与朋友圈未外发。

| 模板 | 头像复测 | 真机证据 |
| --- | --- | --- |
| 中企云链 | 头像在白卡左上跨绿底，白边连续，图片圆形裁切完整。 | [编辑](android/zqyl-edit.png) · [预览](android/zqyl-preview.png) · [重开](android/zqyl-reopen.png) · [分享渠道](android/zqyl-share.png) · [相册原图](android/zqyl-long.jpg) |
| 汇丰永盛 V2 | 头像保留在倾斜相框左下，白边连续，照片框没有截断头像。 | [编辑](android/hfys-v2-edit.png) · [预览](android/hfys-v2-preview.png) · [重开](android/hfys-v2-reopen.png) · [分享渠道](android/hfys-v2-share.png) · [相册原图](android/hfys-v2-long.jpg) |
| 成塔服饰 V2 | 头像居中跨越主图与正文白卡，白边上下完整，交界处没有缺口。 | [编辑](android/ctfs-v2-edit.png) · [预览](android/ctfs-v2-preview.png) · [重开](android/ctfs-v2-reopen.png) · [分享渠道](android/ctfs-v2-share.png) · [相册原图](android/ctfs-v2-long.jpg) |

[头像局部对照](android/avatar-crops.png)上排为预览截图，下排为相册实际文件，列顺序同表。验收期间应用日志中 Flutter 框架异常、布局溢出、销毁后刷新、未处理异常及 Android 崩溃均为 0。[运行检查](android/runtime-check.json)

复测结束后删除三个测试标记并保存，清除临时模板选择，装回正式分发包。冷启动后正式版按测试公司原规则选择随机模板，重开同一记录读回原正文。[正式版重开](android/normal-final-reopen.png)
