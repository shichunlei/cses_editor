# cses_editor根包与内置example结构调整

日期：2026-10-29。项目目录已由 `workspace/cses_offline_editor` 重命名为 `workspace/cses_editor`；原协同项目未修改。

## 当前结构

```text
cses_editor/
├── lib/
├── assets/
├── test/
├── pubspec.yaml
├── pubspec.lock
├── tool/
├── third_party/
├── docs/
└── example/
    ├── lib/daily_guidance/
    └── pubspec.yaml        # cses_editor: {path: ..}
```

根目录本身是`cses_editor`包，`example/`为内置宿主。原`packages/`布局已移除，没有保留兼容软链接或外部工作区路径依赖。
`appflowy_editor`仍来自指定Git仓库并固定提交`9e7593134457eac9193a61ee4023a75de55fcc68`，未恢复本地副本。

迁移了库、资产、测试、pubspec/锁文件、分析配置、生成工具及第三方许可证；同名工具合并前核对无覆盖。
首轮增量构建虽通过，遗留缓存仍创建旧路径的空资产目录；已清理示例构建、Dart及本地Gradle缓存并完整重建，旧目录未再出现。见[清理记录](cache-cleanup.json)、[Flutter清理日志](example-clean.txt)。
Dart源码、生成数据、资产与测试直接移动；格式化178份手写Dart文件时0改动，未格式化生成文件。
移后记录与验证后的内容一致，见[文件清单](moved-files.json)、[内容核对](source-preservation.json)。

同步更新README、宿主接入示例、AGENTS、忽略/空白规则和独立性检查。历史证据保留原日期与执行路径，不将旧日志改写为本轮通过。
Flutter资源地址`packages/cses_editor/assets/...`保留，这是按包名寻址的合法资源URI，不是旧磁盘目录。

## 验证

| 项目 | 结果与证据 |
|---|---|
| 根包与内置示例依赖解析 | 成功，示例锁文件path为`..`；[根包](core-pub-get.txt)、[示例](example-pub-get.txt) |
| 实际包根目录 | 两个解析上下文均指向新根目录；[记录](resolved-layout.json) |
| 根包静态分析与测试 | 无问题，85项通过；[分析](core-analysis.txt)、[测试](core-tests.txt) |
| 示例静态分析与测试 | 无问题，192项通过；[分析](example-analysis.txt)、[测试](example-tests.txt) |
| 独立性检查规则 | 14项通过，包括示例必须解析到根包、拒绝旧packages布局；[日志](guard-tests.txt) |
| Android构建与资产 | 构建成功，确认编辑器Mermaid及今日导向封面已打包；[构建](android-build.txt)、[产物](artifact.json) |
| 源码、解析依赖与APK独立性 | 通过，Git依赖来源和提交保持一致；[检查](independence.json) |
| iOS生成路径 | 使用Flutter的`--config-only --no-codesign`成功重新生成；Generated.xcconfig及环境脚本中不再指向旧项目目录。仅配置生成，不算iOS完整构建或真机通过；[日志](ios-config.txt) |
| 旧路径、文档链接和空白检查 | 活动依赖无旧本地路径；历史说明和Flutter资源URI已区分；git diff --check通过；[记录](diff-check.txt) |

本轮只调整布局与引用，没有新增手机安装或真机验收，也未提交或推送Git改动。

## 后续手机复验

2026-10-29已完成旧路径复查与Android重新安装、集成和手动验收；新增结果见[路径与真机复验记录](phone-verification.md)。上方“不新增真机验收”描述保留为前一阶段的执行范围。
