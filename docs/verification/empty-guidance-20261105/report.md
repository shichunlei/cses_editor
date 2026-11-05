# 当天空白今日导向入口

日期：2026-11-05。

## 行为

- 首次进入由宿主创建完整空白 JSON，不读取或打包 `文档完整数据结构.json`。原文件保留给已有兼容性测试。
- `bizType=DAILY_ORIENT`，`orientType=ORIENT`，正文元数据 `dailyType=orient`；日期取创建时设备本地年月日。
- 复用既有 daily-writing 正文协议，仅含一个空填写区，解码后提供可输入空段落。无预填正文、人员、感悟、自检和自定义栏目。
- 显式保存提交完整记录与正文派生字段，成功进入只读预览；分享沿用完整品牌 PNG 和宿主图片端口。
- 同次启动重开保留保存结果；mock 仍为内存服务，重启应用重新创建当天空文档。
- 没有修改块协议、转换器或根包公开 API。

## 验证

- 本次修改的手写 Dart 文件格式化通过。
- example 所有 lib 与本次测试/设备测试静态分析通过，见 `analysis.log`。
- 26 项回归全部通过，见 `tests.log`：
  - `empty_guidance_flow_test.dart`：跨年日期、空白记录不编辑也可保存、真实首页打开空文档、插入正文、完整提交字段、保存进入预览、生成 PNG、微信/朋友圈出口参数、重开恢复。
  - `journal_page_mode_test.dart`：编辑/预览权限与首页入口。
  - `journal_preview_actions_test.dart`：全文 PNG、三个分享目标、保存图片、防重入、失败和失效会话。
  - `body_content_api_test.dart`：完整保存、原有格式/引用、栏目、失败重试及迟到结果。
- 首轮 Android 测试曾因连接失去响应中止；重新连接后原设备回归仍在启动前遇到 ADB 掉线，见 `device-reconnect.log`。用户暂停其他调试并重新连接后，完成下述专项真机验证。
- `git diff --check` 通过。

## 重新连接后的专项真机验证

设备：Android `fa7eba24`，型号 `24053PY09C`，本地日期 `2026-11-05`；微信 `8.0.80`。

命令（在 example 执行）：

```sh
CSES_VERIFICATION_DIR=../docs/verification/empty-guidance-20261105 flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/empty_guidance_flow_device_test.dart -d fa7eba24
```

新增专项测试 `empty_guidance_flow_device_test.dart` 在真实手机通过，日志 `empty-device-flow.log` 最终为 `All tests passed.`。测试未模拟平台分享方法：

- 初始仅有一个空段落，后台 JSON 为 `ORIENT`，日期与手机当天一致，见 [初始空文档](empty-device-initial.png)。
- 实际展示输入键盘，使用编辑事务插入中文测试正文并验证撤销、重做，见 [编辑](empty-device-edited.png)。
- 点击保存，验证后台完整字段 `dailyOrient` 正确、`dailyResult=null`、当前页只读，见 [保存后预览](empty-device-saved-preview.png)。
- 点击分享，在真实渲染环境生成完整 PNG，校验 PNG 文件头，三个操作按钮均可用，见 [分享图片](empty-device-share.png)。
- 关闭分享未改变正文；返回首页重开编辑，保存文字全部恢复，见 [重开](empty-device-reopened.png)。

普通运行包已重新构建，见 `normal-build.log`；检查 APK 不含原样例 JSON，见 `apk-assets.json`。普通包安装首次被手机拒绝，用户允许后重试安装成功，并以正常入口启动。

## 普通运行包的系统保存与微信接收

用户开启手机的安装及调试安全设置并重插数据线后，自动点击恢复。保留手机上现有正文，点击保存，真实页面显示“已保存到后台”并进入只读预览，再打开分享。

- 点击“保存图片”，真实打开 Android DocumentsUI 的下载目录；点击系统“保存”，返回 App 显示“图片已保存”。
- 从手机下载目录取回生成文件，见 [系统实际保存的 PNG](native-saved.png)。文件为有效 PNG，824 × 1185 像素，609494 字节，正文、封面、日期和品牌页脚均完整。手机保留 `/sdcard/Download/今日导向_1793837978049.png`。
- 点击“微信”，观察到客户端提供“发送到朋友圈 / 发送给朋友”入口，并进入带有当前图片的 `com.tencent.mm/.plugin.sns.ui.SnsUploadUI` 待发表页面，见 [微信接收到图片](native-wechat-received.png)。没有选择收件人、发送消息或点击“发表”。验证中创建的待发表内容曾取消并选择“不保留”。
- 详细文件校验与 Activity 记录见 `native-results.json`。
- USB 在后续分支复验中再次失去响应，截图及系统就绪状态读取挂起，已中止这些读取。未单独完成聊天选人流程与“朋友圈”独立按钮的分支复验；不将它们写成通过。普通运行包已安装，未清除用户当前正文或下载的分享图。

本次新增的是可复跑的真机测试与验证证据，未进一步修改产品实现。最终静态分析与 `git diff --check` 通过。
