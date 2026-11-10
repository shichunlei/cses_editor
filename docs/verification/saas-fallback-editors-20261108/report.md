# SaaS 三套随机公司模板迁移与 Android 验收

2026-11-08。新增 **默认邮票、弧顶名片、品牌双域** 三套独立编辑器视觉。原公司模板页面、Shell、注册表、原表单和原分享流程不改。新编辑器未知公司从这三套已迁移候选随机选择，一次路由固定，重开可重新抽取；原 templates 七套池保持不变，其余四套待迁移。已登记但未迁移的公司仍保持原中企云链兼容，不算完成公司原版还原。

## 实现与复用

- Mutualism 独立适配原裁剪、装饰、边框、日期、问候、头像、作者卡、品牌底色及叠压；正文区继续使用同一编辑器会话。
- 主图、整页虚化背景、头像、满宽品牌和邮票外形分别复用 `TemplateImageView`、`TemplateBackgroundView`、`CircleAvatarImage`、`BottomLogoImageView`、原 `ShareShapeBorder`。图库、取景、加载门禁、固定磨砂操作栏和平台分享沿用已有组件及流程。
- templates 只补充公开能力查询和原邮票外形导出，不复制公司 ID 清单。整画布背景不参与正文测量，保留短文预览仅主图补高、编辑主图最小高、长文自然延伸及编辑期隐藏 Logo 的规则。
- 原字段、详情和保存接口不变，随机视觉不写入 `bodyContent`。新建原表单与编辑器入口继续共存，已有记录经新详情进入编辑器。

## 原版对照与自动化

在同一 414×896 设计缩放、日期、问候、照片、作者、Logo 槽和正文槽条件下，直接调用真实原页面 `visualBuilder` 与新视觉层对照，不启动旧 Shell 的账号/截图状态机。分别使用 0、3、30 行正文槽；长图画布为 2500 逻辑像素。**9 组逐像素一致**，原图与新图 PNG 字节也一致，见 [对照图目录](original-comparison/) 和 [检查结果](checks.json)。

正文槽在对照测试中使用同一旧展示组件，以隔离允许升级的富文本编辑区。真实编辑器另行验证短文图片补高、长文完整性、键盘缩放、唯一输入会话、文档 JSON 不因布局变化；不能把测试字体的像素结果当作真机中文字体金图。Android 实际界面另见下表。

最终目标回归 **196 项通过**，分析无问题，包含已接入六种视觉 × ORIENT/RESULT 的长文、动态栏目、人员聚合、原接口保存、详情读回、重开再编辑及真实 PNG 生成。另覆盖原三套布局和保存异常、只读零写入、取景、冷头像加载。格式化和两仓 `git diff --check` 通过。

```sh
# 在 cses.saas 中执行
flutter test --no-pub test/modules/mutualism/presentation/orient_result/editor test/modules/mutualism/routes/editor_entry_choice_test.dart
flutter analyze --no-pub lib/modules/mutualism/presentation/orient_result/editor lib/modules/mutualism/routes/editor_composition.dart lib/modules/templates/index.dart lib/modules/templates/company/registry/company_template_capabilities.dart test/modules/mutualism/presentation/orient_result/editor test/modules/mutualism/routes/editor_entry_choice_test.dart
```

## Android 实际链路

设备为 HONOR MTN-AN00，1200×2640；当前测试公司“北京一起嗨网络科技有限公司”为未登记公司，走正式随机入口。成果导向填写时段已关闭，本轮真机操作 **工作成果 RESULT**；两类记录覆盖来自上述自动化，不记为本轮两类真机验收。

| 模板 | 键盘与编辑 | 保存、重开与预览分享 | 相册实际输出 |
|---|---|---|---|
| 默认邮票 | [编辑页](default-editor.png)、[键盘](default-keyboard.png)；邮票边缘、黑框、竖排问候、日期和作者保留，编辑不显示 Logo | 主正文新增 `RANDOM-DEFAULT-MAIN-D1`，保存详情读回，重开保留；[分享渠道页](default-share.png)包含全部栏目及 Logo | [739×2469 长图](default-album.jpg)，[相册成功提示](default-album-confirmation.png) |
| 弧顶名片 | [编辑页](arc-editor.png)、[键盘](arc-keyboard.png)；弧深、主图覆盖层、作者白卡、描边和阴影保留 | 主正文新增 `RANDOM-ARC-MAIN-C1`；重开保留前次内容，保存读回并生成[完整长图](arc-share.png)；最终 APK 也重开验证了该模板 | [739×2033 长图](arc-album.jpg) |
| 品牌双域 | [最终版编辑页](brand-editor.png)、[键盘](brand-keyboard.png)；整页品牌侧带、固定切角、日期和后卡阴影保留 | 两次修改保存，最终新增 `RANDOM-BRAND-REOPEN-E1`；[分享渠道页](brand-share.png)包含原栏目及默认品牌图 | [739×2257 长图](brand-album.jpg)，[相册成功提示](brand-album-confirmation.png) |

预览已验证随机换图、原图片拖动取景，并通过[原云图库](brand-cloud-gallery.png)选图：[换图后预览](brand-cloud-selected.png)、[同图长图分享](brand-cloud-share.png)。这些只读图片操作不再提交正文。平台渠道界面包含微信、朋友圈、保存；实际保存到相册，未外发微信或朋友圈。

最终[重新进入编辑页](final-reopened.png)，通过新详情取得最后已保存内容；检查了四个主正文标记、感悟、自检、一条含两个人员的帮助条目及一条含一人的领航条目。帮助/领航数组各 1 条，帮助 mentions 2 人、领航 mentions 1 人；感悟、自检与起始详情一致，没有因模板切换重复收集。验收输入在帮助行也保留了一个标记和空业务行；空行留在完整正文，不进入原数组。

本轮四次实际保存及多次详情的 HTTP 200、业务成功、提交正文与读回/最终重开完全一致，见[脱敏请求核对](request-checks.json)。只保存字段名、计数、布尔值、摘要和记录别名，不归档真实记录 ID、请求头或 VM 地址。

## 真机发现并修复

测试公司的原公司 Logo URL 返回 404。`BottomLogoImageView` 已按原规则显示默认品牌图，但截图仍按原网络资源失败中止，导致无法分享。

先增加真实原组件的 404 复现测试，再调整截图等待：只允许原 Logo 网络资源走其既有降级，默认素材仍须严格解码和实际绘制；主图和其他素材继续严格校验。回归断言生成图片包含默认品牌实际像素。修复后弧顶、邮票、品牌双域均成功生成长图并保存相册，云图库换图后的再次分享也通过。

最终安装包 SHA-256：
`b553efd68e0cbf0345accaef2890d36057f07a1cf9f5f55d5ac9bafc6116cdb9`。

原三套布局与新背景层的回归同时通过。尚未覆盖其他四套随机模板、其他未迁移公司、折叠屏及大字真机；本轮不将它们标为完成。技能前置信息与本地引用已核对；标准校验脚本缺少 PyYAML，使用 Ruby YAML 解析校验已有前置信息，未安装额外依赖。

手机最后返回[互生首页](finished-home.png)，所有提交已保存，请求诊断已关闭。
