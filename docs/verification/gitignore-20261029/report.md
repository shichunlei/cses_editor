# 根目录Git忽略规则与example锁文件

日期：2026-10-29。

## 修改

- 根目录新增 `.gitignore`，忽略Flutter/Dart依赖缓存、构建输出、覆盖率、Python缓存、IDE私有配置和系统临时文件。根库的 `pubspec.lock` 保持忽略。
- `example/.gitignore` 添加 `!pubspec.lock`，应用锁文件加入暂存区。
- 精确移出暂存区9个缓存和IDE文件，保留本地内容，其SHA256与操作前一致，见 [文件摘要](local-files.json)。

## 验证

- 9个文件均仍存在、内容未改变、不在索引中且被忽略。
- example锁文件已暂存，使用 `git check-ignore --no-index` 确认未被忽略；根库锁文件仍被忽略。
- 构建与临时文件探针被忽略；业务源码、生成Dart源码、Mermaid资源、接入模板源码及验证索引没有被忽略。
- 本次范围的工作区及暂存区 `git diff --check` 通过。
- 全仓工作区 `git diff --check` 通过；全仓暂存区检查发现既有Mermaid资源和历史验证日志的空白问题，保留其他修改，未清理这些文件。具体检查结果见 [checks.json](checks.json)。
- 仅调整Git规则、锁文件跟踪及验证文档，没有修改Dart代码或依赖版本，未运行Flutter分析和测试。
