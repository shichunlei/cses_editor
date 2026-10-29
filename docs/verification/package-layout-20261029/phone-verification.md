# cses_editor路径复查与Android真机复验

日期：2026-10-29。项目：`/System/Volumes/Data/workspace/cses_editor`。
设备：vivo V2353A，Android 14 / API 34，arm64。原协同项目没有修改。

## 路径与依赖结论

活动源码、依赖声明/锁文件、包解析、构建配置和iOS生成路径未发现旧项目目录或旧`packages/cses_editor`磁盘引用。根包和example都解析到新根目录；旧项目目录与`packages/`目录不存在。[路径审计](phone-path-audit.json)检查263份文本文件，[审计脚本](phone-layout-audit.py)。补充全局检索（包含隐藏配置，排除Git、构建产物及历史验证目录）仅命中`docs/source.md`的迁移来源说明。

历史日志与来源说明中的旧路径保留为事实记录；`packages/cses_editor/assets/mermaid/index.html`是Flutter按包名寻址的合法资源URI，保留使用。
`appflowy_editor`仍使用指定Git仓库与提交`9e7593134457eac9193a61ee4023a75de55fcc68`；没有恢复本地源码副本。
源码、解析依赖与本轮APK的[独立性检查](phone-independence.json)通过，未检出原协同包、Common SDK、Rust/FRB/Yrs或协同数据库依赖。

发现并修正截图驱动的默认归档位置：由早期拆出目录改到本轮结构迁移目录，避免新截图覆盖历史证据。扩充手机集成用例；两次执行中修正了测试截图初始化及隔离测试包的清理配置。业务源码没有变更，187份生产文件内容一致，见[内容核对](phone-source-preservation.json)。

## 本轮验证

| 范围 | 实测结果与证据 |
|---|---|
| 新增/修改测试静态检查 | 格式化完成；`flutter analyze --no-pub integration_test test_driver`无问题，[日志](phone-analysis.txt) |
| 独立性规则回归 | 14项通过，[日志](phone-guard-tests.txt) |
| Android普通示例构建安装 | 构建、安装成功，[构建](phone-normal-build.txt)、[安装](phone-normal-install.txt)；已安装APK与当前构建产物SHA256完全一致，[核对](phone-manual-results.json) |
| 两项手机集成场景 | 正文、撤销重做、预览、保存返回/重开、实际私有JSON落盘；真实键盘工具栏、待办转换、@示例人员、领航员/都来帮、感悟/自检栏目与正文、关闭栏目后撤销恢复、日期选择与持久化均通过，[完整日志](phone-2/device-integration.txt)、[执行结果](phone-2/run.json) |
| 普通示例真实输入 | Android按键输入英文；点击搜狗键盘输入`nihao`并选择“你好”候选，中文成功上屏，[截图](phone-ime-committed.png) |
| 勾选、预览、进程恢复 | 工具栏转换待办并勾选；预览后保存，强制停止本示例进程并重新启动/打开，正文与勾选状态保留，[重启截图](phone-normal-restarted.png) |
| 系统文件框JSON导出/导入 | 实际通过Android DocumentsUI保存独有文件`cses-layout-20261029-1440.json`，再选择该文件导入为独立草稿。正文、待办勾选、日期保留，原草稿仍可返回，[导出JSON](phone-exported.json)、[导入截图](phone-json-imported.png)、[原草稿](phone-original-draft.json)、[导入草稿](phone-imported-draft.json)、[断言结果](phone-manual-results.json) |

集成测试在临时项目副本中使用独立applicationId、namespace及MainActivity包名；普通示例在测试开始前尚未安装。第二次执行两项业务场景通过（日志`+3`含框架tearDownAll，不代表三项业务用例）。测试生成的独立包已清理，普通示例保留安装并停留在今日导向页面，没有清空用户App数据。

首次执行的第一场景通过，第二场景在待办转换后因截图binding需要在每个测试内重新初始化而失败；已补充每场景`convertFlutterSurfaceToImage()`并在第二次执行通过。[首次失败记录](phone-1/device-integration.txt)、[说明](phone-1/run.json)保留。首次隔离包的namespace未同步，清理曾误指向当时不存在的普通示例包，卸载返回失败；已同步namespace与Kotlin包名后重跑。该测试配置问题未改动生产原生配置。

本轮未重新执行前轮已通过的85项根包和192项示例测试；该结论仍以[结构迁移报告](report.md)为历史证据。本轮未做iOS手机测试、完整iOS构建或覆盖所有第三方输入法。已验证范围内未发现今日导向功能异常。
