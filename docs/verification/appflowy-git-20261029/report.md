# AppFlowy Editor 改用Git依赖

日期：2026-10-29。范围仅为独立项目 `cses_offline_editor`，原 `cses_document_collab` 项目未修改。

`packages/cses_editor/pubspec.yaml`与`example/pubspec.yaml`统一从 [指定仓库](https://github.com/shichunlei/appflowy-editor.git) 引入 `appflowy_editor`，固定提交 `9e7593134457eac9193a61ee4023a75de55fcc68`（核对时main的HEAD）。两个锁文件的ref与resolved-ref一致。

移除前逐文件核对404份库源码、72份资源和215份测试，与Git提交完全一致；pubspec、LICENSE及UPSTREAM说明也一致，未遗漏本地兼容补丁。见[对照记录](source-comparison.json)。

本地 `packages/appflowy_editor` 及其锁文件已移除；未在项目中保留替代路径或本地override，也未修改Git缓存中的源码。
更新接入文档、来源说明、AGENTS、忽略规则及空白检查规则。历史验证记录保留原结论和当时路径，不重写为新验证。

独立性检查改为验证批准的Git URL、固定提交、实际Git缓存来源及运行源码洁净状态；继续扫描Git依赖的运行库源码和pubspec，拒绝恢复本地副本、外部工作区路径、提交不一致或协同原生依赖。

| 验证 | 结果与依据 |
|---|---|
| 两个项目重新解析依赖 | 均成功，只改变appflowy_editor来源；[编辑器](core-pub-get.txt)、[宿主](example-pub-get.txt) |
| 编辑器静态检查与回归 | 无问题，85项通过；[分析](core-analysis.txt)、[测试](core-tests.txt) |
| 今日导向宿主静态检查与回归 | 无问题，192项通过；[分析](example-analysis.txt)、[测试](example-tests.txt) |
| 依赖规则回归 | 13项通过，含Git来源、缓存源码、脏缓存与本地副本拒绝；[日志](guard-tests.txt) |
| Android构建 | 普通App入口构建成功，Git包资源正常打包；[日志](android-build.txt) |
| 源码/解析图/APK独立性 | 通过，603份Dart及9份配置均检查；[结果](independence.json) |
| 旧路径和空白检查 | 活动声明/锁文件/接入说明无旧本地依赖；检查工具中旧路径只作为禁止恢复的规则及测试夹具，历史证据不计残留依赖；[diff检查](diff-check.txt) |

本轮不新增手机安装、真机或iOS验收；没有提交、推送或修改远端仓库。
