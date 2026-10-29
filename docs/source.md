# 来源与维护边界

当前项目位于 `workspace/cses_editor/`，根目录即 `cses_editor` 包，示例在其 `example/` 下并使用 `path: ..`。2026-10-29将原嵌套包的lib、资产、测试、声明、生成工具与许可证上移，并将项目目录从 `cses_offline_editor` 重命名。历史验证日志和哈希记录保留当时路径，不改写为新的执行证据。

日期：2026-10-28。来源：本机 `cses_document_collab` 当前工作区；其HEAD为 `9d4d60099bb0e59d4a09064df66807edd5bdc7bb`。
当前工作区包含尚未提交改动，因此该HEAD不代表所有提取文件的精确内容；精确依据见[源文件哈希](verification/offline-extraction-20261028/source-hashes.json)。

本轮只读取原项目，在 `workspace/cses_offline_editor/` 新建独立仓库；没有在原项目拆包、替换依赖、提交或推送。
编辑器提取的是公开离线入口的传递依赖，不复制协同控制器、同步层、原生层、Rust源码或FRB生成物。
今日导向来自原宿主业务目录，现位于示例App业务目录。

2026-10-28提取时曾保留AppFlowy本地fork。2026-10-29已改为从 [独立仓库](https://github.com/shichunlei/appflowy-editor.git) 引入并固定提交 `9e7593134457eac9193a61ee4023a75de55fcc68`，同时移除原本地目录。
源码、资产、测试、LICENSE及UPSTREAM来源说明由该Git仓库维护。本轮移除前已确认运行源码与资产完全一致，未修改Git缓存中的源码或生成本地化文件。
本仓库只有根 `example/` 作为接入示例；Git依赖自身的上游示例不是本项目运行依赖。

原项目的更新不会自动进入本仓库。后续按功能选择性同步，记录来源和兼容验证；不得直接覆盖独立包的资源注入、无原生依赖和业务分层边界。

两个生成目录文件原样保留，生成入口和表情许可证现位于根目录 `tool/` 与 `third_party/`。
生成数据不手工改写；维护时在编辑器包目录按生成脚本说明提供已核对的桌面依赖来源。
生成文件精确字节核对见[记录](verification/offline-extraction-20261028/generated-preservation.json)。
