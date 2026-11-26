# 宿主封面公共入口验证

- 公共入口仅导出资源选择、编辑输入会话、底部路由及外壳；不导出业务封面控制器，不新增依赖。
- SaaS 消费者通过公开入口实现草稿封面图片和位置编辑；宿主拥有业务保存与异步权限守卫。
- 根包 `editor_media_upload_progress_test.dart`、`editor_service_isolation_test.dart`、`editor_shortcut_toolbar_test.dart`：35 项通过。
- SaaS 相关回归 282 项通过，覆盖去重计数、换图取消/确认、位置调整、保存重开、图像上传与预览截图；新增封面图片选择映射测试另行通过。
- 静态分析与 diff 检查通过。未进行 Android 真机或真实 OSS/保存接口联调；Widget 图片使用隔离缓存、接口使用替身。
- 两个仓库已有 pubspec 修改保持未动，不属于此功能改动。
