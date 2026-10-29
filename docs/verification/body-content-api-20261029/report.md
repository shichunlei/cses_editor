# bodyContent 服务适配与原记事本/菜单验证

日期：2026-10-29（Asia/Shanghai）。

## 已确认范围

- API 返回记录中的 orientType：ORIENT 对应“今日导向”，RESULT 对应“今日成果”。id 仅用于固定记录身份核验。
- 编辑器只解析/更新 bodyContent，不解析、生成或更新 dailyResult、thinking、selfCheck、helpItems、navigatorItems、customData 等其他接口字段。
- 保留原封面、日期、米色横格、文字/列表/待办菜单与感悟、自检、都来帮、领航员等自定义动作。
- 头部移除 JSON 文件导入导出，替换为显式保存。

## 实现

1. `BodyContentCodec` 在宿主业务层将模板填写区转换为原生日记栏目，不启用普通桌面文档渲染/工具栏模式。daily-cover/daily-body 的可编辑内容进入今日记录，reflection/self-check 进入原栏目，custom 保留原字段 key、标签和内容。
2. 原模板骨架、区域/块身份、锁定标题、日期卡片及 props/meta 保留在当前会话的独立来源数据中。未编辑节点原样还原；编辑节点只更新对应内容，新段落使用独立身份；本地来源属性不进入提交 JSON。
3. dailyTag help/pilot 转成原都来帮/领航员行，保存时还原原生前缀；原生人员/任务等引用保留身份和类型，不将任务当作人员。核心库和通用 Codec 的块注册清单未更改。
4. `GuidanceApi` 是宿主注入服务端口；`ApiJournalStore` 固定记录身份，读取 orientType/bodyContent，保存仅提交 `{"bodyContent": ...}`。
5. 示例宿主从原 `moke.json` 创建内存 mock 服务，保持原首页单入口；重开获取已保存内容，应用重启恢复样例。mock 保存仅替换正文，其他字段逐项保持。
6. API 模式不在输入、切后台或销毁时自动提交。保存失败保留正文并可重试；退出有修改时可继续编辑、保存后离开或放弃。迟到请求结果复核页面/会话/文档。
7. 关闭栏目不删除内容，使用可选 `bodyContent.meta.mobileGuidanceView.hiddenSections` 保存 reflection/self-check 的隐藏状态，可重新添加和恢复。自定义栏目沿用纸张布局，本轮未增加新的菜单入口。

## 验证证据

- [适配专项测试](adapter-tests.txt)：11 项通过，涵盖原样往返、编辑保存及重开、其他字段保持、原生引用、条目、日期、自定义字段、关闭恢复、回车身份唯一/撤销、非法数据拒绝、请求重试及迟到结果处理，以及真实原生工具栏/选人菜单/H1 转换和保存。
- [example 全量回归](example-tests.txt)：最终 **202 项全部通过**，包括既有本地日记、剪贴板、IME、菜单、格式、栏目和公共 JSON 转换消费者。
- [example 静态分析](example-analysis.txt)：No issues found。
- [格式化](format-final.txt)、[差异检查](diff-check.txt)：通过。
- [编辑页截图](api-paper.png)：原雪山封面、日期和横格，RESULT 标题显示“今日成果”。
- [自定义键盘菜单](api-keyboard.png)、[T 块类型菜单](api-block-menu.png)：使用原工具栏组件和菜单布局。组件测试的文字选择浮层字体不代表设备系统字体。
- [用户文件及边界记录](preservation.json)：两份用户 JSON 文件未修改；原有回滚验证目录保留。
- 设备集成测试源码已改为服务保存流程，本轮未重新安装或运行手机测试；截图为 Flutter 组件测试，不宣称真实系统键盘截图。

## BlockCraft 核对及边界

[配置 registry 实时 latest](blockcraft-latest.txt) 为 0.11.31；桌面声明/锁定 0.11.33、实际安装 0.11.17，未升级依赖。已阅读安装 .17 与缓存 .31 的随包技能入口、迁移和行内对象资料，并核对 embeds 声明及 EmbedConverter 实现；.33 声明版全部发行行为待实际环境核对。见[块兼容说明](../../block-adaptation.md)。

当前适配覆盖 moke.json 中实际出现的段落、列表、业务标签、原生引用、固定栏目与自定义文字字段。模板 incl 的媒体目录不代表本轮新增了媒体编辑能力；未知可编辑块、非法标签或无法安全编辑的锁定正文整次拒绝，不静默丢失数据。真实 API 的地址、方法、鉴权和客户端生命周期由宿主实现 GuidanceApi 提供，本示例没有启动 HTTP 服务器。
