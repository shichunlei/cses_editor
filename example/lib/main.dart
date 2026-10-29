import 'dart:convert';

import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/guidance_api.dart';
import 'package:cses_offline_example/daily_guidance/guidance_host.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 启动不需要账号或协同服务的独立今日导向示例。
void main() => runApp(const OfflineExampleApp());

/// 独立宿主示例，业务页面由App拥有。
///
/// ```dart
/// runApp(const OfflineExampleApp());
/// ```
class OfflineExampleApp extends StatelessWidget {
  /// [key]控制应用身份和状态复用。
  const OfflineExampleApp({super.key});

  /// 在[context]配置中文和应用主题，不初始化协同或账号资源。
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '离线今日导向',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff8b6e63)),
      scaffoldBackgroundColor: const Color(0xfffaf8f0),
      useMaterial3: true,
    ),
    home: const _OfflineHome(),
  );
}

/// 宿主入口持有 mock 服务与固定记录身份，提供固定编辑和预览的两个入口。
class _OfflineHome extends StatefulWidget {
  /// 创建固定的业务入口。
  const _OfflineHome();

  /// 创建入口路由状态，不预先分配编辑器。
  @override
  State<_OfflineHome> createState() => _OfflineHomeState();
}

/// 路由打开期间拒绝重复创建同一草稿会话。
class _OfflineHomeState extends State<_OfflineHome> {
  bool _opening = false;
  String? _error;

  /// 当前首页实例拥有的 mock 服务，不使用全局账号或存储兜底。
  MockGuidanceApi? _api;

  /// 本首页实例注入的头像服务，编辑和预览共用；无账号或网络客户端所有权。
  late final CollabHostServices _hostServices =
      createDemoGuidanceHostServices();

  /// 首页明确注入的虚构当前用户，与正文引用及后台模板字段无关。
  final CollabMentionUser _currentUser = const CollabMentionUser(
    id: 'sample-chen',
    name: '示例小陈',
    department: '示例团队',
    position: '前端开发',
  );

  /// 读取样例后固定的接口记录身份。
  String? _recordId;

  /// 由宿主读取 文档完整数据结构.json 初始化服务并打开当前记录，重开沿用已保存正文。
  /// [mode] 为此次路由固定的编辑/预览模式；加载失败可重试，迟到结果不更新已销毁的首页。
  Future<void> _open(JournalPageMode mode) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      if (_api == null) {
        final data =
            jsonDecode(await rootBundle.loadString('文档完整数据结构.json'))
                as Map<String, dynamic>;
        if (!mounted) return;
        final id = data['id'];
        if (id is! String || id.isEmpty) {
          throw const FormatException('示例记录身份无效');
        }
        _api = MockGuidanceApi(record: data);
        _recordId = id;
      }
      final store = ApiJournalStore(api: _api!, recordId: _recordId!);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => LocalJournalPage(
            store: store,
            mode: mode,
            storageScope: _recordId!,
            mentionDirectory: const _ExampleDirectory(),
            hostServices: _hostServices,
            currentUser: _currentUser,
          ),
        ),
      );
    } catch (error, stack) {
      debugPrint('打开草稿失败: $error\n$stack');
      if (mounted) setState(() => _error = '打开失败，请重试。');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  /// 在[context]提供离线入口和示例人员说明；大字/键盘压缩视口时滚动，不改变导航或资源所有权。
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('离线今日导向')),
    body: Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.notebookPen, size: 48),
              const SizedBox(height: 24),
              const Text('记录今天，随时继续', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 12),
              const Text(
                '选择编辑或预览，编辑后点击保存提交修改。\n应用重启恢复样例，选人使用虚构示例人员。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('open-daily-guidance'),
                onPressed: _opening ? null : () => _open(JournalPageMode.edit),
                child: const Text('编辑'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const ValueKey('preview-daily-guidance'),
                onPressed: _opening
                    ? null
                    : () => _open(JournalPageMode.preview),
                child: const Text('预览'),
              ),
              if (_error != null) Text(_error!),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 示例App的虚构目录；实际接入由宿主替换，不存入核心编辑器。
class _ExampleDirectory implements CollabMentionDirectory {
  /// 创建无资源的示例目录。
  const _ExampleDirectory();

  static const _people = [
    CollabMentionUser(id: 'sample-lin', name: '示例小林', department: '示例团队'),
    CollabMentionUser(id: 'sample-chen', name: '示例小陈', department: '示例团队'),
  ];

  /// 按[keyword]过滤虚构姓名，不读取账号或访问网络。
  @override
  Future<List<CollabMentionUser>> search(String keyword) async =>
      _people.where((user) => user.name.contains(keyword)).toList();

  /// 根据[userId]查找示例人员，不存在返回null。
  @override
  Future<CollabMentionUser?> load(String userId) async =>
      _people.where((user) => user.id == userId).firstOrNull;
}
