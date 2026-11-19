# 嵌入式只读正文验证

2026-11-19。`DocumentEditorView.embeddedPreview` 支持在外层画布内按正文自然高度布局，默认值 false 保持原独立视图行为。嵌入模式要求只读会话，不创建 Overlay、滚动、键盘或选区服务；沿用现有块渲染、样式扩展和预览交互权限，不改变块协议。

宿主分别拥有测量、可见及截图所需的独立会话，不能共享 EditorState、节点 Key 或 renderer。卸载后由所有者等待 close；视图不接管正文或保存资源。异步媒体就绪及截图门禁仍归宿主。

## 验证结果

- [根包测试](tests.txt)：25 项通过，覆盖嵌入短文/80 段长文完整 PNG、拒绝可写会话且可正常释放、既有图片布局和字色。
- [静态分析](analyze.txt)：本次实现及新增测试无问题。
- [example 消费者](example-tests.txt)：原编辑/预览栏目间距在 390 宽正常字号和 320 宽双倍字号下共 2 项通过。
- 格式化本次手写文件，git diff --check 通过。

SaaS 原中企云链模板消费该公开能力，短文、长文、实际解码图片、自定义栏目、页尾完整性和只读零事务通过。完整证据及局限见 [SaaS P0 与 P1 报告](../../../../cses/cses.saas/verification/guidance-company-preview-p0-p1-20261119/report.md)。SaaS 生产入口尚未切换，本地路径验证不等于公开包已发布。

## 边缘案例与后续测试

网络图片尺寸迟到、资源失败、超长画布容量、可交互只读预览和静态截图的用途隔离，由宿主在生产接入前补齐。当前 PNG 是 Widget 测试证据，不代替 Android/iOS 真机、真实资源和平台分享验收。example/pubspec.yaml 及既有 blockcraft_json_codec_test.dart 的原有改动保持未动。
