# 公司模板剩余范围与一比一迁移评估

2026-11-08。仅评估与文档整理，没有修改 SaaS 模板、注册表、编辑器或接口，没有运行手机或发出写入请求，没有暂存或提交。

[完整方案与 51 页矩阵](../../../../cses/cses.saas/saas-company-template-coverage.md) 给出范围、风险、待决项和迁移顺序；[结构化清单](inventory.json) 保存 41 公司映射、7 个兜底实际 builder、51 页 canvasMode 和逐页判断。[清单检查](checks.json) 的 10 项核对通过。纯文档变更不运行 Flutter 测试。

代码来源以 SaaS 7e5efa1a7 的 CompanyTemplateRegistry、CompanyBrandCatalog、CompanyTemplateVariantPolicy、CompanyTemplateShell、51 个 company 页面及新 CompanyJournalPoster/Resolver 为准。实际 builder 优先于过期文档和有误的 pageType。风险评级依据源码布局，不等同于完成 51 套视觉对比。

关键结果：3 套独立视觉已接入，48 页尚未独立适配；其中汇丰/成塔旧版两页按已确认例外保留原流程。先迁呈诺医学，再迁实际随机池七套、16 个普通长图页、12 个裁剪装饰页和6个整画布复杂页；固定一屏和固定圆形/六边形主视觉的6页单列规则冲突，其中两页属于前述既有例外。

待决基线包含：随机池代码7套但文档4套、三项 pageType 与 builder 不一致、北区口腔品牌目录与原页面 Logo 来源不同、爱能旧版/V2 新正文的分发规则，以及固定几何主图与短文只增加实图高度的冲突。当前没有修改规则或以别的版式冒充原版。

验收要求：同宽、同字级、同时间作者、同图片取景和同正文槽高度建立原版/新版基线；编辑区外逐项对比素材、布局、裁剪、日期和装饰，短文图片补高作为已确认产品差异单独验收。特殊模板的未决规则不能通过拉伸异形、整图缩字或新增正文空白绕过。
