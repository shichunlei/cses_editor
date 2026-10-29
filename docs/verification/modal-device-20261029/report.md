# 弹窗窄屏、大字与真实键盘：Android 真机验证

日期：2026-10-29。设备：vivo V2353A，Android 14 / API 34，物理分辨率1080×2408。

## 验证方式与范围

使用独立临时测试包 `com.cses.offline.modal_ui_verification` 安装当前 example，根包仍引用本仓库；测试副本位于忽略的 `.dart_tool/modal-device-example/`。没有覆盖、卸载或清空已安装的正式 example 数据。

通过 Android 实际显示密度和系统字体设置制造窄屏/大字；使用设备真实输入法，未在真机测试中伪造 MediaQuery 或键盘高度。应用实际报告的16px文本缩放比例分别为1.0、1.6、2.0。

| 组合 | 实测逻辑尺寸 | 字体 | 实测键盘高度 | 结果 |
|---|---|---|---|---|
| 原生密度480 | 360×802.67dp | 1.0 | 284.33dp | 选人、离开确认、分享、组织列表及固定头尾通过 |
| 窄屏密度540 | 320×713.48dp | 1.6 | 252.74dp | 同上，通过 |
| 窄屏密度540 | 320×713.48dp | 2.0 | 252.74dp | 发现入口页溢出；修复后完整复测通过，并优化组织面板列表空间 |

前两组为发现问题前的完整矩阵；两项修复后在最严格的320dp/2.0倍组完整重跑。另以 Widget 测试覆盖最终1.6/2.0倍组织面板和入口页滚动，未无理由重复全部原生构建。

单选通过真实今日导向工具栏进入；离开确认通过修改当前样例再返回触发；分享通过保存后打开真实只读预览进入。组织多选使用正式 `showGuidancePeoplePicker` 加独立虚构长目录，因为当前首页没有这个多选入口。没有用静态样稿代替正式组件。

## 发现与修复

1. **320dp/2倍字体下入口页纵向溢出21dp。** 原因是 `example/lib/main.dart` 中入口内容使用固定 Column，空间不足仍试图完整显示。真机错误定位与截图见 `largest-failure-diagnosed/`；它不是弹窗本体溢出。入口改为保持居中的 SingleChildScrollView，大字或键盘压缩空间时可滚动到编辑/预览按钮。增加真实尺寸对应的 Widget 回归，原先失败、修复后通过。
2. **组织选择标题换行挤占长名单可视空间。** 320dp/2倍字体加键盘时，原“选择用户和部门”分两行。精简为“用户和部门”，不限制系统字体、不缩小字号，保留完整搜索说明及固定操作区。新增断言确保列表仍有至少100dp可用高度，并核对滚动前后搜索/确认位置不变。

今日导向纸张、封面、栏目、正文和预览操作风格保持。无块协议、公开根包API或依赖变更。

## 截图

以下为 Android 原生屏幕截图，包含系统键盘；已结合控件边界断言与截图检查验收。

- [2倍大字：单选人员与真实键盘](narrow-largest/narrow-largest-mention-keyboard-native.png)
- [2倍大字：组织选择与真实键盘](narrow-largest/narrow-largest-people-keyboard-native.png)
- [2倍大字：长名单滚动后，搜索及确认保持固定](narrow-largest/narrow-largest-people-scrolled-native.png)
- [2倍大字：离开确认全部操作可见](narrow-largest/narrow-largest-leave-dialog-native.png)
- [2倍大字：分享与复制入口](narrow-largest/narrow-largest-share-native.png)
- [2倍大字：修复后的可滚动入口页](narrow-largest/narrow-largest-home-native.png)
- [1.6倍大字：人员选择](narrow-large/narrow-large-mention-keyboard-native.png)
- [正常字体：组织选择](normal/normal-people-keyboard-native.png)

三个有效矩阵目录共16张原生截图；其他过程目录保留失败或修复前的证据，不混作最终验收图。

## 测试与证据

- 设备测试：`example/integration_test/modal_ui_device_test.dart`。断言真实键盘出现、搜索与关闭/确认完整处于键盘上方、实际命中可触达、列表可滚动且头尾位置固定、复制正文成功、路由关闭没有 Flutter 布局异常。
- 正常与1.6倍完整设备日志：`normal/device.log`、`narrow-large/device.log`；最终2倍日志：`narrow-largest/device.log` 与 `final-largest.log`。
- 修改代码及测试静态分析通过：`final-analyze.log`。
- 21项 Widget 回归通过：`final-widget-tests.log`，含入口页大字/键盘、1.6/2.0倍组织面板、主题隔离、选人取消/会话失效及预览分享。
- 测试构建与当前工作区的关键修改源文件 SHA256 完全一致：`source-identity.json`；三组汇总见 `matrix-results.json`。
- 手写 Dart 已格式化，`git diff --check` 通过。

首轮截图方式曾导致设备画面滞后一帧，相关图片在 `capture-attempt-1/`，不作为验收依据。已移除 Flutter 表面转换，改为正常渲染下按测试同步标记直接截取 Android 屏幕。后续定位过程还保留了旧构建缓存、启动连接重试及保存提示短暂挡住测试点击等记录；最终干净重建并等待保存提示自然消失后，才点击实际可见的预览按钮。没有隐藏或跳过布局错误来取得通过结果。

## 恢复与边界

测试结束后显示密度恢复480，字体恢复系统默认1.0，独立测试包移除；见 `device-restored.json`。初始 font_scale 未显式设置，系统在恢复默认后会将值规范化为1.0。现有 example 安装及数据保留。

本轮覆盖 Android 竖屏与该设备当前输入法；不将结果外推为iOS、横屏或所有输入法均通过。
