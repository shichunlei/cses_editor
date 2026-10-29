import 'dart:io';

import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import 'daily_guidance/file_journal_store.dart';
import 'daily_guidance/local_journal_page.dart';

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

/// 宿主入口负责文件目录和路由单写入者约束。
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

  /// 获取App私有目录并打开草稿；不读取其他App数据，失败保留已有文件。
  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final directory = await getApplicationDocumentsDirectory();
      if (!mounted) return;
      final store = FileJournalStore(
        directory: Directory('${directory.path}/daily-guidance'),
        scope: 'offline-example',
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => LocalJournalPage(
            store: store,
            storageScope: 'offline-example',
            mentionDirectory: const _ExampleDirectory(),
          ),
        ),
      );
    } catch (error, stack) {
      debugPrint('打开草稿失败: $error\n$stack');
      if (mounted) setState(() => _error = '打开失败，请重试；原草稿保留。');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  /// 在[context]提供离线入口和明确标注的示例人员说明。
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('离线今日导向')),
    body: Center(
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
              '内容自动保存在本机，无需登录。\n选人功能使用虚构示例人员。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('open-daily-guidance'),
              onPressed: _opening ? null : _open,
              child: Text(_opening ? '打开中…' : '打开今日导向'),
            ),
            if (_error != null) Text(_error!),
          ],
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
