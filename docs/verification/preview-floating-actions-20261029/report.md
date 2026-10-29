# 预览页底部悬浮分享与点赞（2026-10-29）

预览页加载成功后，底部居中显示紫色分享按钮、米白色点赞计数按钮，圆角带阴影，使用 Lucide 图标。按钮不随正文滚动；Scaffold 保留设备底部安全距离。仅预览显示，编辑页及加载失败/会话失效页面不显示。

预览正文增加可滚动底部留白，随字号放大，便于将最后一行滚动至按钮上方。原记事本结构、任务样式、头像、键盘菜单及 bodyContent API 协议不变。

分享打开底部面板，选择“复制正文”后将当前标题、记录日期、可见正文复制到剪贴板；原生 @ 引用转为可读名称。面板取消不复制，异步返回复核原页面、文档和宿主身份。没有生成分享链接或发送消息。

点赞为本次预览内的演示状态，初始 0，点击 1，再次点击取消；重新打开预览恢复 0。未接后端分享或点赞服务，不使用示意图中的 13 冒充实际数量，不写 bodyContent 或其他接口字段。

## 验证

- `flutter test --no-pub --dart-define=SAVE_PREVIEW_ACTION_SCREENSHOT=true test/daily_guidance/journal_preview_actions_test.dart test/daily_guidance/journal_page_mode_test.dart test/daily_guidance/mention_avatar_test.dart test/daily_guidance/journal_keyboard_toolbar_test.dart --reporter expanded`：24 项通过，见 [target-tests.txt](target-tests.txt)。
- 新增覆盖长文滚动后按钮位置固定、点赞与取消、正文复制及提及可读化、只读正文不变且零保存、320 宽度及 1.8 倍字号和底部安全区、编辑页没有悬浮按钮且原底部留白不变。
- `flutter analyze --no-pub`：No issues found，见 [example-analysis.txt](example-analysis.txt)。
- 修改的手写 Dart 已格式化，`git diff --check` 通过。
- [preview.png](preview.png)：390×844 长文滚动到底后的预览截图，确认末行及底部按钮完整可见。截图使用测试字体，不代表设备字体及实际阴影。
- 未构建或重新安装手机应用。本次没有修改核心包公开 API 或块协议，也未覆盖用户 moke.json 和原始模板文件。
