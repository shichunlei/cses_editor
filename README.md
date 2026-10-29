# CSES 离线编辑器

独立 Flutter 编辑器包 `cses_editor`，包根目录下带 `example/`。今日导向位于示例 App 的业务层，只将通用编辑能力封装成包。
本项目不依赖原协同工程、Common 账号 SDK、Rust、FRB、Yrs 或 SQLite 插件。

```text
lib/                       通用编辑会话、视图、工具栏、渲染与扩展契约
assets/                    编辑器资源
test/                      通用编辑器回归
pubspec.yaml               根包 cses_editor 的依赖声明
example/lib/daily_guidance/ 今日导向页面、栏目、草稿和业务转换
example/                   可独立安装的 Android/iOS 示例宿主
```

需要 Flutter >=3.44.0、Dart >=3.12.0；本轮使用 Flutter 3.44.9 / Dart 3.12.2。

## 运行

```sh
# 在 cses_editor/ 根目录
flutter pub get
flutter test
cd example
flutter pub get
flutter run
```

示例在 `example/pubspec.yaml` 中通过 `cses_editor: {path: ..}` 引用根包。

首页分别提供“编辑”和“预览”入口，创建路由时固定模式，页面内不提供切换。从宿主注入的 mock API 读取 `example/文档完整数据结构.json` 样例。`orientType` 的 ORIENT/RESULT 分别显示“今日导向”/“今日成果”，只将 `bodyContent` 适配进当前横格记事本，保留现有键盘和自定义菜单。
头部移除文件导入导出，改为显式“保存”；请求仅含 `bodyContent`，不生成或更新其他业务摘要。mock 数据在当前首页实例中保留，重启恢复样例；选人使用虚构人员。真实接入由宿主实现服务端口并注入客户端。
实际业务账号、人员、任务/会议/KR详情、天气与媒体上传由接入方注入，示例不伪造在线服务成功。
已加载网络图片使用无数据库的App私有文件缓存，可跨进程离线读取。

## 接入与验证

- [其他App完整接入说明](docs/integration.md)：引入、初始化、离线保存和宿主注入
- [可复制的独立宿主模板](docs/integration_app/README.md)：不依赖example的完整源码与测试
- [数据格式](docs/data-format.md)
- [来源及维护边界](docs/source.md)
- [块兼容与版本跟踪](docs/block-adaptation.md)
- [验证索引](docs/verification/README.md)
- [2026-10-29复审与修复](docs/verification/offline-review-20261029/report.md)

```sh
python3 tool/verify_independence.py
# 同时检查构建产物
python3 tool/verify_independence.py example/build/app/outputs/flutter-apk/app-debug.apk
```

保留部分 `Collab*` Dart 类型名以减少迁移造成的数据与调用差异；这些名称不代表本包包含协同引擎。
文件选择、视频、WebView等能力仍使用普通 Flutter 平台插件。
`appflowy_editor` 从 [独立 Git 仓库](https://github.com/shichunlei/appflowy-editor.git) 引入，固定提交 `9e7593134457eac9193a61ee4023a75de55fcc68`，本仓库不再保存其源码副本。

示例在宿主层通过 `createDemoGuidanceHostServices` 注入用户头像，普通 @、都来帮、领航员及旧用户引用共用头像槽。可传入用户 ID 到头像 URL 的映射；未提供图片时显示离线姓名首字头像，不向正文 JSON 写入头像展示数据。任务引用图标与样式保持原样。
