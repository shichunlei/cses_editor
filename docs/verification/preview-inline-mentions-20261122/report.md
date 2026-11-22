# 可见预览行内引用详情

2026-11-22。DocumentEditorView 新增默认关闭的 previewMentionInteractions，只在显式允许的可见只读预览中直接派发会议、任务及人员引用。会议/任务优先专用回调，再回退 onMentionTap；人员仅通过 onMentionTap，未配置不创建默认资料页。编辑态原引用面板及 previewTaskMentionInteractions 的任务专用面板保持兼容。

## 约束

- 复用既有 CollabMentionTap 与原防重复锁；复制并冻结原引用属性，按当前节点和 UTF-16 位置复核，不改变原子、JSON、缓存或块协议。
- 普通与嵌入预览均传播开关，嵌套容器和人员标签局部作用域保留外层策略；disabled、开关关闭及 EditorResourceScope.staticMedia 禁止跳转。
- 只读交互不启动编辑模态会话、块锁租约、选区/键盘恢复；回调 Future 等宿主返回，失败只报告一次并优先使用宿主 showFeedback，失效页面不提示。具体业务权限、详情页面、客户端和人员资源归宿主。
- 当前改动仅为展示交互能力，不改变 BlockCraft 协议；集成 API 和最小示例见 docs/integration.md 的“可见预览的行内引用详情”。

## 验证

- [33 项通过](tests.txt)：17 个新预览场景，及原行内任务菜单/删除/撤销、人员配色、嵌入预览和资源门禁。
- [5 项编辑态会议回归通过](meeting-editing-tests.txt)，与上述集合无重叠。
- [静态检查无问题](analyze.txt)，[格式通过](format.txt)，git diff --check 通过。
- SaaS 消费者真实预览复现中三类引用修复前均未派发；接入后 1,227 项宿主/模板/任务/导航回归通过，468 张海报一致，Android 宿主 Debug APK 构建成功。消费者证据位于 cses.saas/verification/guidance-preview-inline-mentions-20261122/。

测试通过实际 RichText/WidgetSpan 点击，不直接调用回调；覆盖两种预览布局、嵌套提示块、无回调、静态切换、无效 ID、跨引用重复点击、失败恢复、在途退出、零修改与零输入。旧任务开关继续显示只读面板，新开关直接派发，不放开文档引用或编辑命令。

本轮未安装到设备、不宣称真实会议或任务接口详情验收。建议平台继续检查长标题跨行、表格/多列引用、实体删除/无权限、嵌套导航返回及切换会话。实现、测试和文档作为同一功能提交；原 example/pubspec.yaml 的依赖暂存内容不纳入功能提交。消费者提交须锁定提供该 API 的编辑器提交，远端交付时先推送编辑器，再推送消费者。
