import 'dart:async';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'host_services.dart';
import 'offline_document.dart';

/// 启动仅依赖公开编辑器包的宿主；不初始化协同、数据库、账号SDK或示例业务。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HostApp());
}

/// 可复制的普通Flutter宿主，配置编辑器与Material/Widgets/Cupertino本地化。
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:cses_editor_host_sample/main.dart';
/// void main() => runApp(const HostApp());
/// ```
class HostApp extends StatefulWidget {
  /// [key]控制组件身份与状态复用。
  const HostApp({super.key});

  /// 创建仅持有宿主导航Key的状态，编辑会话仍属于页面。
  @override
  State<HostApp> createState() => _HostAppState();
}

/// 导航Key随宿主应用生命周期稳定，提供给实例服务使用。
class _HostAppState extends State<HostApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// 在[context]中创建宿主路由、本地化和主题，不创建进程级编辑器。
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    title: '独立宿主接入',
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: const [
      AppFlowyEditorLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    home: _Home(navigatorKey: _navigatorKey),
  );
}

/// 宿主单写入者入口，等待编辑路由完全退场后释放会话。
class _Home extends StatefulWidget {
  /// 借用宿主[navigatorKey]，不预先申请存储或编辑器资源。
  const _Home({required this.navigatorKey});

  /// 借用宿主应用的稳定导航入口，不在此释放或更换。
  final GlobalKey<NavigatorState> navigatorKey;

  /// 创建持有打开状态的入口。
  @override
  State<_Home> createState() => _HomeState();
}

/// 用稳定业务身份隔离文档；真实账号切换必须先退出旧页面并等待保存释放。
class _HomeState extends State<_Home> {
  bool _opening = false;
  String? _error;

  /// 打开本机演示账号的doc-1，重复点击不创建第二个写入者；失败保留文件并展示错误。
  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    OfflineDocumentSession? session;
    var active = true;
    // 固定身份只用于无登录模板；实际App捕获(companyId,userId,sessionGeneration)。
    try {
      final directory = await getApplicationSupportDirectory();
      if (!mounted) return;
      final store = OfflineDocumentStore(
        Directory('${directory.path}/editor-drafts'),
        'local-demo-user',
        'doc-1',
      );
      // 传入当前宿主Navigator，服务回调只在本次会话仍有效时派发。
      final navigator = Navigator.of(context);
      final services = createHostServices(
        widget.navigatorKey,
        () => active && mounted,
      );
      session = await OfflineDocumentSession.open(store, services, (
        error,
        stack,
      ) {
        debugPrint('自动保存失败: $error\n$stack');
      });
      if (!mounted) return;
      final route = MaterialPageRoute<void>(
        builder: (_) => _EditorPage(session: session!),
      );
      await navigator.push(route);
      await route.completed;
    } catch (error, stack) {
      debugPrint('打开或保存失败: $error\n$stack');
      if (mounted) setState(() => _error = '打开或保存失败：$error。原文件保留。');
    } finally {
      active = false;
      try {
        await session?.close();
      } catch (error) {
        if (mounted) setState(() => _error = '最终保存失败：$error');
      }
      if (mounted) setState(() => _opening = false);
    }
  }

  /// 在[context]展示唯一文档入口与失败信息。
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('其他App独立接入')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: _opening ? null : _open,
            child: const Text('打开离线文档'),
          ),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
  );
}

/// 借用宿主会话的页面，不拥有或释放编辑器；退出前保存失败则保持页面打开。
class _EditorPage extends StatefulWidget {
  /// [session]由入口创建和释放，页面保存完成后关闭路由。
  const _EditorPage({required this.session});

  /// 必填借用会话，外层入口在路由完全退场后释放。
  final OfflineDocumentSession session;

  /// 创建页面监听和生命周期观察者。
  @override
  State<_EditorPage> createState() => _EditorPageState();
}

/// 保存状态仅影响宿主工具栏，正文事务仍由借用的编辑器处理。
class _EditorPageState extends State<_EditorPage> with WidgetsBindingObserver {
  bool _busy = false;

  /// 仅在最终保存完成后解除系统返回拦截，防止未保存页面退场。
  bool _allowPop = false;
  String? _status;

  /// 注册页面拥有的生命周期监听，不抢占宿主服务的资源。
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.editor.addListener(_edited);
  }

  /// 新编辑发生后清除旧的手动保存提示，避免把后续修改显示为已保存。
  void _edited() {
    if (mounted && _status != null) setState(() => _status = null);
  }

  /// [state]离开前台时尝试保存；操作系统强杀不会保证执行本回调。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_save());
    }
  }

  /// 保存当前文档；[leave]为true时冻结新输入，成功才关闭，失败恢复编辑并允许重试。
  Future<void> _save({bool leave = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final state = widget.session.editor.editorState;
    if (leave) {
      state.editable = false;
      state.service.keyboardService?.closeKeyboard();
      FocusManager.instance.primaryFocus?.unfocus();
    }
    try {
      await widget.session.flush();
      if (!mounted) return;
      if (leave) {
        setState(() => _allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() => _status = '已保存到本机');
      }
    } catch (error) {
      if (mounted) setState(() => _status = '保存失败，请重试：$error');
      if (!state.isDisposed) state.editable = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 注销本页面的观察者，编辑器由外层等待路由完成后释放。
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.session.editor.removeListener(_edited);
    super.dispose();
  }

  /// 在[context]中借用编辑状态；系统返回也先保存，@输入委托公开提及命令。
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_save(leave: true));
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _busy ? null : () => unawaited(_save(leave: true)),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('离线文档'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => unawaited(_save()),
            child: const Text('保存'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_status != null) Text(_status!),
          ValueListenableBuilder<String?>(
            valueListenable: widget.session.saveError,
            builder: (context, error, child) => error == null
                ? const SizedBox.shrink()
                : Text('自动保存失败，请点击保存重试：$error'),
          ),
          Expanded(
            child: DocumentEditorView(
              editorState: widget.session.editor.editorState,
              editable: !_busy,
              onUserMention: (state) =>
                  handleEditorUserMentionTrigger(context, state),
            ),
          ),
        ],
      ),
    ),
  );
}
