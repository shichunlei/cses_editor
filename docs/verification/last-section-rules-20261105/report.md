# 最后一个栏目横格补满剩余视口

日期：2026-11-05

## 实现

- 编辑和预览中，最后一个可见栏目（首栏目、感悟、自检、自定义栏目）承接剩余正文视口高度，按既有行距绘制装饰横格。
- 前置栏目按自然高度排版，保留栏目间距。上方内容已占满屏幕时，空末栏保持一行正文的自然高度，不再增加整屏留白。
- 前置栏目自然高度在布局后报告；帧后更新校验组件 mounted、根节点及栏目身份，文档切换清除旧测量。键盘、工具栏、缩放、输入及栏目增删触发重新布局。
- 保留共享根滚动列表的栏目与头部索引，继续使用原编辑器选区、输入和滚动服务；不新增空段落、不写正文、不改变撤销历史。
- 末栏底部不再叠加栏目留白，文档 footer 仍只出现一次。分享图沿用原有完整纸张与品牌页脚布局。
- 同步更新 UI skill 的栏目补线规则。无公开 API、块协议或依赖配置变更。

## 验证

在 `example/` 运行：

```sh
flutter analyze --no-pub lib/daily_guidance/journal_surface.dart test/daily_guidance/journal_last_section_fill_test.dart test/daily_guidance/journal_sticky_cover_test.dart
flutter test --no-pub test/daily_guidance/journal_last_section_fill_test.dart test/daily_guidance/journal_sticky_cover_test.dart test/daily_guidance/journal_rules_test.dart test/daily_guidance/journal_page_layout_regression_test.dart test/daily_guidance/journal_preview_spacing_test.dart test/daily_guidance/journal_share_minimum_height_test.dart test/daily_guidance/journal_keyboard_caret_visibility_test.dart test/daily_guidance/journal_keyboard_toolbar_test.dart --reporter expanded
```

结果：分析无问题；8 个文件、34 项测试全部通过，完整结果见 [tests.log](tests.log)。手写 Dart 文件已格式化，`git diff --check` 通过。

覆盖：

- 320 宽、1 倍和 2 倍文字；连续添加感悟、自检、自定义栏目，最后一栏底部抵达正文视口底部，前置栏目保持一行自然高度。
- 上方增加一行文字，末栏补线区相应缩短；键盘和底部工具栏改变可用视口时重新分配，至少保留自然正文行。
- 上方正文超过整屏后，滚动至末栏验证只保留一行；撤销并拖回顶部恢复补满；删除末栏后，补线转移到新的末栏。
- 预览模式、上下安全区与 2 倍文字下末栏补线，正文 JSON 和选区不变。
- 390/320 宽固定封面、关闭及撤销至单栏目、真实点击选区与 IME 输入、栏目间距、横线空白命中、分享 PNG 最小高度、键盘焦点行和工具栏既有行为。

## 范围与待核对

- 本轮为 Flutter widget/render 测试与分享 PNG 测试，未在真机上手工验收，不把浏览器或历史截图作为本轮证据。
- 探索长文往返时，直接 `itemScrollController.jumpTo` 跳到末项再跳回 0，曾触发依赖 `positioned_list.dart` 内 `_leadingKey.currentContext.findRenderObject()` 读取 inactive element 的异常；未改动依赖，未将该跳转路径计为通过。最终长文用例覆盖实际拖动往返；后续已在 fork 定位并修复，见 [带页脚列表跳回首项异常](../indexed-footer-jump-20261105/report.md)。

## 日期头部选区回归修复

真实日期头部恢复到编辑器的头部位置，由编辑器隔离正文选区手势。补线计算单独扣除日期头部的实际高度。日期随正文滚动，滚出视口后可以由滚动列表回收。

在三栏编辑页选中文字，按下日期后验证选区清除，松手后验证日期选择器可用。页面、末栏补线、固定封面、输入定位、预览间距和键盘焦点行共 18 项测试通过。修改的布局及页面回归测试通过静态分析，`git diff --check` 通过。
