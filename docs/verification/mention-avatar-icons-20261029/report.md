# 用户引用头像注入，任务图标保持原样

日期：2026-10-29（Asia/Shanghai）。

## 最终范围

- 按用户补充要求，任务引用图标与样式保持原样。曾尝试的图标调整已撤回，核心 `collab_inline_entity_mention.dart` 与 HEAD 完全一致，本轮核心库无代码差异。
- example 首页实例创建并稳定注入 `CollabHostServices.mentionAvatarBuilder`，普通 @、都来帮、领航员的原生用户引用复用已有核心头像槽，编辑与预览一致。
- `createDemoGuidanceHostServices` 接受宿主明确提供的用户 ID → URL 映射，创建时复制，不根据 ID 拼接地址、不读取全局账号。样例无头像地址时显示稳定颜色的姓名首字头像；图片失败也使用同一回退。
- 旧 guidance_mention 用户引用也读取当前宿主头像构建器，部门/任务等类型不误显示用户头像；无注入时保留原展示。
- 头像仅为展示 Widget，不进入 bodyContent、不修改引用身份、类型、名称或业务属性。头像 Widget/图片由 Flutter 生命周期管理，无新增客户端、订阅或周期定时器。

## 验证

- [example 全量测试](example-tests.txt)：**210 项通过**。新增覆盖普通用户/都来帮/领航员在编辑和预览中的头像、任务仍为原 squareCheck 图标且无头像、原 bodyContent 不因展示改变、编辑保存不写入头像属性、URL 映射隔离和首字回退、旧引用兼容；首页两入口的头像注入也有验证。
- [example 静态分析](example-analysis.txt)：No issues found。
- [格式化](format.txt)、[git diff --check](diff-check.txt)：通过。
- [任务图标无差异检查](task-icon-unchanged.txt)：通过，文件与 HEAD 一致。
- [编辑截图](edit.png)、[预览截图](preview.png)：测试夹具在原样例上增加普通 @ 和领航员用户，确认三种引用均有头像；任务图标保持原蓝色勾选框。

截图为 Flutter 组件测试，本轮未重新安装或运行手机。两份用户 JSON 文件及其他已有工作区修改保留。没有块协议或保存接口变更。
