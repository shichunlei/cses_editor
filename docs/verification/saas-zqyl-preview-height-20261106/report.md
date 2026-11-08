# SaaS 中企云链预览自然正文与画布高度

日期：2026-11-06。

本轮生产实现位于 `cses.saas`：编辑主图保持原最小高度；预览和分享以自然正文、原模板及满宽 Logo 组成至少一屏的完整画布，短文缺口仅增加主图高度，长文自然延伸。固定操作栏与安全防遮挡尾距在画布外，不进入分享图。正文 JSON 不变，沿用现有只读栏末纯空段折叠规则。

已同步[迁移方案](../../saas-daily-guidance-migration.md)与[公司模板适配 skill](../../skills/saas-daily-guidance-templates/SKILL.md)，明确后续全部 SaaS 公司模板共同遵守这一高度规则；旧离线 example 保持自己的规则，不迁入其正文填屏实现。本轮未修改编辑器 example 页面。

SaaS 自动验证已完成：流程 12 项、图片与取景目标集 18 项、最终分享专项补跑 2 项均通过，生产及测试目标分析无问题，实际宿主 Android debug APK 构建成功。最终 2 项是补跑，不累计为新增覆盖数。

日志、具体范围和现场状态统一维护在 [SaaS 验证报告](../../../../cses/cses.saas/docs/verification/zqyl-preview-height-20261106/report.md)，此处不重复日志。最终 APK 已安装；临时只读短文在真机上确认主图补高、正文自然收尾和 Logo 可滚出固定底栏。真实详情对象本轮收到的 `bodyContent` 为 null，预览入口未出现，原因尚未确定；没有回填或修改业务数据。真机最终 PNG 分享尚未验收，尺寸与取景一致性以自动化为证，不将其写成真实记录保存、重开或平台外发通过。

适配 skill 的 `quick_validate.py` 与本轮相关归档的 `git diff --check` 通过。
