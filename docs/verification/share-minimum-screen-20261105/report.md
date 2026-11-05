# 分享图至少一屏高

日期：2026-11-05。

## 行为与实现

- 分享纸张的最小逻辑高度取当前 `MediaQuery.size.height`，包含封面、用户、日期、正文和品牌页脚；不扣除分享页操作栏或安全区。
- 先按自然高度测量头部和页脚，剩余高度交给正文。多栏目时前面的栏目保持自然高度，最后一栏补足横格，页脚位于纸张底部。
- 长正文超过一屏时继续自然增长，保留全文和品牌页脚；沿用已有 PNG 像素比例与超长内容保护，不缩小文字或生成额外空段落。
- 复用现有最小高度布局对象，增加可选第三项页脚；普通编辑和预览的两项布局行为保持。
- 仅修改 example 展示布局、测试及说明，不涉及正文协议或根包公开 API。

## 验证

- 手写 Dart 文件格式化通过；静态分析通过，见 [analysis.log](analysis.log)。
- 11 项相关测试全部通过，见 [tests.log](tests.log)。覆盖新增空白/单行/多栏目/窄屏大字 PNG 尺寸与底部品牌位置，以及既有长文完整分享、分享异常与会话保护、固定封面和预览间距。
- 新测试显式设置一致的 MediaQuery 逻辑尺寸与测试画布，并设置顶部 44、底部 34 的安全区。初次运行的测试夹具遗漏 MediaQuery.size，仍使用默认 800×600 导致尺寸断言失败；修正夹具后全部通过，初次日志见 `tests-initial.log`。
- 下列图是本轮 Flutter Widget 渲染后实际导出的 PNG，已视觉检查；使用测试用户与正文，不作为手机安装截图：

| 场景 | 逻辑屏幕 | PNG 尺寸 | 图像 |
| --- | --- | --- | --- |
| 空白 | 390×844 | 780×1688 | [blank.png](blank.png) |
| 单行 | 390×844 | 780×1688 | [short.png](short.png) |
| 三栏目短文 | 390×844 | 780×1688 | [sections.png](sections.png) |
| 窄屏、2倍文字 | 320×713.5 | 640×1612 | [large-text.png](large-text.png) |

- 分享关闭后断言原正文 JSON 未改变、存储写入次数为零。
- 本轮未重新安装手机。
- `git diff --check` 通过。

执行命令（example）：

```sh
flutter test --no-pub --dart-define=SAVE_MINIMUM_SHARE_POSTERS=true test/daily_guidance/journal_share_minimum_height_test.dart test/daily_guidance/journal_preview_actions_test.dart test/daily_guidance/journal_sticky_cover_test.dart test/daily_guidance/journal_preview_spacing_test.dart --reporter expanded
dart analyze lib/daily_guidance/journal_surface.dart lib/daily_guidance/journal_share_page.dart test/daily_guidance/journal_share_minimum_height_test.dart
```
