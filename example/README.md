# 今日导向示例

这是根包 `cses_editor` 下的示例App。今日导向业务在 `lib/daily_guidance/`，不独立成包。
示例依赖根包：

```yaml
cses_editor:
  path: ..
```

从本目录运行 `flutter pub get`、`flutter run`。运行宿主回归使用 `flutter test`。
根包的测试在上一级 `test/`，需从根目录另行运行。

示例无需登录，选人使用虚构人员；真实业务能力由宿主端口注入。
详见[项目说明](../README.md)和[接入文档](../docs/integration.md)。
