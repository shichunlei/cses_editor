# 实体引用菜单按类型显示删除文案

日导向编辑页的行内引用菜单显示「删除会议」「删除任务」或「删除文档」。按钮文案与菜单中的详情入口共用类型映射，点击后执行正文引用的删除事务，并支持撤销。

- 源码核对覆盖类型映射、按钮回调及 SaaS 本地依赖解析路径。`git diff --check` 通过。
- `collab_inline_entity_mention_test.dart` 按新文案删除会议和任务引用，并核对相邻正文与撤销恢复。
- `entity_mention_sheet_title_test.dart` 覆盖三种类型的删除文案、空名称与窄屏大字，并核对文档引用删除及撤销。
- `dart format`、目标文件 `flutter analyze --no-pub` 和两份 Widget 测试均因 SDK 缓存写入权限受限而未能运行。回归时同时核对只读预览的可用操作。
