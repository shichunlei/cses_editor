# 独立宿主接入模板

这是文档配套的Flutter宿主源码模板，仅依赖根包公开API；不引用 `example`，也不包含今日导向业务或协同原生构建文件。接入实际App时复制所需源码，核心依赖始终是 `cses_editor`。

| 文件 | 内容 |
|---|---|
| [pubspec.yaml](pubspec.yaml) | 本模板的直接依赖；位于docs内所以根包路径为`../..` |
| [lib/main.dart](lib/main.dart) | 完整应用初始化、本地化、单文档入口、系统返回保存及卸载释放 |
| [lib/offline_document.dart](lib/offline_document.dart) | 宿主文件封装、恢复、500ms自动保存、串行写入、错误重试 |
| [lib/host_services.dart](lib/host_services.dart) | 人员选择/头像/详情、任务本地数据及可选上传适配器 |
| [test/offline_document_test.dart](test/offline_document_test.dart) | 文件恢复、并发修订、错误保留及页面生命周期回归 |

模板不携带Android/iOS脚手架，避免让宿主复制本仓库示例App。要单独运行，可在工作区中新建普通Flutter应用，然后复制本目录的 `lib/`、`test/`、`analysis_options.yaml`和 `pubspec.yaml`。假定项目与cses_editor平级：

```sh
# 在workspace/中执行，目标目录须为新目录。
flutter create --platforms=android,ios --project-name cses_editor_host_sample cses_editor_host_sample
cp -R cses_editor/docs/integration_app/lib/. cses_editor_host_sample/lib/
# 清除flutter create自动生成的默认计数器测试，再复制本模板test目录。
cp cses_editor/docs/integration_app/pubspec.yaml cses_editor_host_sample/pubspec.yaml
cp cses_editor/docs/integration_app/analysis_options.yaml cses_editor_host_sample/analysis_options.yaml
cp -R cses_editor/docs/integration_app/test/. cses_editor_host_sample/test/
```

将新App的pubspec中 `cses_editor.path`由 `../..`改为 `../cses_editor`；保留 `appflowy_editor`的Git地址与固定提交。删除新建脚手架自带的 `test/widget_test.dart`（如存在），因为它引用计数器应用。保留本模板测试并运行：

```sh
cd cses_editor_host_sample
flutter pub get
flutter analyze
flutter test
flutter run
```

也可直接在本文模板目录执行 `flutter pub get`、`flutter analyze`和 `flutter test`；平台构建和运行请使用上面的新App。

演示人员和任务为静态本地数据，不请求账号或业务服务器；上传默认未配置。文件使用宿主私有支持目录，按固定演示账号与文档ID生成独立文件。接入真实业务时替换身份分区、数据查询与路由，遵守[完整接入说明](../integration.md)中的资源和保存契约。
