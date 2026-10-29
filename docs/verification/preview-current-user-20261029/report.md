# 预览封面下方当前用户信息（2026-10-29）

在原雪山封面图正下方添加平面用户信息行：36px 圆形头像，左侧姓名及灰色部门/职位，右侧可选时间文案。无卡片边框或圆角，保持记事本布局，与日期和正文一同滚动。

- 页面新增可选 `currentUser` 和 `previewTimeLabel`，由宿主注入，不查询全局账号、解析模板用户字段或写入正文。
- 头像使用当前页面注入的头像构建器，传递用户 ID、姓名、明确提供的 avatarUrl 和尺寸；未注入构建器使用 example 既有头像组件。
- 仅预览显示用户栏，未提供用户时保留原布局；姓名及部门职位长文案允许省略，时间可隐藏。
- example 首页注入虚构用户“示例小陈 / 示例团队 · 前端开发”；右侧显示预览打开时刻，标为“预览 HH:mm”，不推断发布时间。
- 当前用户 ID 切换撤销旧会话，隐藏旧正文、资料及悬浮动作，须重新进入。
- 编辑器、键盘自定义菜单、任务图标及 bodyContent 协议未改动。

## 验证

- `flutter test --no-pub --dart-define=SAVE_PREVIEW_USER_SCREENSHOT=true test/daily_guidance/journal_preview_user_test.dart test/daily_guidance/journal_page_mode_test.dart test/daily_guidance/journal_preview_actions_test.dart test/daily_guidance/mention_avatar_test.dart --reporter expanded`：13 项通过，见 [target-tests.txt](target-tests.txt)。
- 覆盖头像/姓名/部门职位/时间、用户栏紧接封面、正文 JSON 不混入用户资料、零保存、320px + 2 倍字号、编辑页与无资料隐藏、切换用户撤销旧页面；同时验证实际首页消费者、固定只读模式、原头像和任务图标、悬浮操作。
- `flutter analyze --no-pub`：No issues found，见 [example-analysis.txt](example-analysis.txt)。
- [preview.png](preview.png)：390×844 渲染截图，已检查用户栏位置、文字排版、日期和悬浮按钮。截图字体和阴影不代表真机最终渲染。
- 手写 Dart 已格式化，`git diff --check` 通过；未重新安装手机应用。
- 仅 example 宿主展示参数变化，核心包 API 与块协议未变化；保留用户的 moke.json、原始模板及其他工作区改动。
