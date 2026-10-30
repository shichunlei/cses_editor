import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/guidance_api.dart';
import 'package:cses_offline_example/daily_guidance/guidance_record_fields.dart';
import 'package:cses_offline_example/daily_guidance/journal_share_page.dart';
import 'package:cses_offline_example/daily_guidance/journal_image_actions.dart';
import 'package:cses_offline_example/daily_guidance/ui/journal_modal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'guidance_host.dart';
import 'journal_draft.dart';
import 'journal_exchange_keys.dart';
import 'journal_store.dart';
import 'journal_surface.dart';
import 'local_journal_controller.dart';
import 'mention_picker.dart';

/// 首页传入的固定页面模式；只能通过打开新页面选择，不提供页内切换。
///
/// ```dart
/// LocalJournalPage(store: store, mode: JournalPageMode.preview);
/// ```
enum JournalPageMode {
  /// 创建可编辑会话，保留原有保存与键盘菜单。
  edit,

  /// 创建只读会话，不显示编辑操作，也不提交或自动保存。
  preview,
}

/// 今日导向/成果记事本页面，拥有加载、正文、显式/自动保存及预览的生命周期。
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
/// import 'package:cses_offline_example/daily_guidance/journal_store.dart';
/// Future<void> openJournal(BuildContext context, JournalStore store) async {
///   await Navigator.of(context).push<void>(MaterialPageRoute(
///     builder: (_) => LocalJournalPage(store: store)));
/// }
/// ```
class LocalJournalPage extends StatefulWidget {
  /// [key]控制页面身份；[store]是当前账号和文档独占的存储端口，由宿主持有。
  /// 同一store只能打开一个日记页面，读取失败不会新建覆盖原记录。
  /// [mode] 固定初始编辑/预览模式，默认编辑；改变模式须重新打开路由。
  /// [mentionDirectory]由宿主提供人员查询，null使用空目录；仅查询人员，不包含部门引用。
  /// [hostServices]默认空端口；其选人回调在本页权限保护下执行，null使用内置面板。
  /// [sessionIdentity]用于身份失效检查，null为固定本地身份；变化后须重新打开页面。
  /// [storageScope] 为宿主账号及文档分区，默认 local；借用端口替换会冻结旧会话。
  /// [currentUser] 是宿主提供的当前用户资料，仅预览封面下展示；null 不显示用户栏。
  /// [imageActions]借用宿主图片分享端口，默认使用当前平台实现，不持有账号。
  /// 服务存储 ApiJournalStore 使用显式保存，其他本地存储保留原自动保存行为。
  const LocalJournalPage({
    super.key,
    required this.store,
    this.mode = JournalPageMode.edit,
    this.mentionDirectory,
    this.hostServices = const CollabHostServices(),
    this.sessionIdentity,
    this.storageScope = 'local',
    this.currentUser,
    this.imageActions = const JournalImageActions(),
  });

  /// 图片分享/保存端口，由宿主创建并持有。
  final JournalImageActions imageActions;

  /// 宿主当前用户的不可变展示快照；不从正文或全局账号读取，不写入 JSON。
  final CollabMentionUser? currentUser;

  /// 页面借用的业务端口；默认空服务，不加载网络或账号；自定义选人仍受页面权限保护。
  final CollabHostServices hostServices;

  /// 当前宿主会话身份读取器；null表示固定本地身份，变化后旧页面拒绝异步写回。
  final Object? Function()? sessionIdentity;

  /// 宿主提供的草稿分区标识，默认local；不包含认证凭据。
  final String storageScope;

  /// 原生用户提及的可选宿主查询端口；由调用方持有，null时使用空目录。
  final CollabMentionDirectory? mentionDirectory;

  /// 页面借用的单写入者存储，路由关闭时不释放宿主资源。
  final JournalStore store;

  /// 宿主在路由创建时选择的固定模式；当前页面不能切换。
  final JournalPageMode mode;

  /// 创建管理异步加载、固定模式和退场资源的状态。
  @override
  createState() => _LocalJournalPageState();
}

/// 拥有固定模式的日记控制器；预览不分配第二份可变会话，也不提交数据。
class _LocalJournalPageState extends State<LocalJournalPage>
    with WidgetsBindingObserver {
  LocalJournalController? _journal;
  String? _loadError;
  bool _loading = false;
  bool _leaving = false;
  bool _canPop = false;
  bool _chooseDate = false;

  /// 本次预览的演示点赞状态，不写入正文 JSON 或冒用后台计数。
  bool _previewLiked = false;

  /// 分享预览打开期间阻止重复打开；截图与平台操作异步结果只作用于原会话。
  bool _sharing = false;

  /// 显式保存期间串行化编辑和退场，异步返回后复核文档、页面及会话。
  bool _submitting = false;

  /// 在初始化时捕获的模式，不跟随后续组件参数改变。
  late final JournalPageMode _mode;

  /// 当前会话的永久只读权限。
  bool get _readOnly => _mode == JournalPageMode.preview;

  /// 当前页面是否通过固定身份的服务适配器加载和保存。
  bool get _remote => widget.store is ApiJournalStore;

  /// 头部标题只取 orientType 映射；本地存储延续今日导向标题。
  String get _title =>
      _remote ? (widget.store as ApiJournalStore).title : '今日导向';

  /// 本页原生提及专用目录；不与其他文档或账号共享缓存，不拥有HTTP连接。
  late final CollabMentionDirectory _mentionDirectory;

  /// 借给正文和预览的实例服务；页面销毁后不接受选人写回，头像资源由Flutter管理。
  late final CollabHostServices _services;

  /// 缓存可选栏目的存在状态，只在结构变化时重建快捷项，普通输入不重建整个正文视图。
  String _sectionActionsSignature = '';

  /// 人员选择期间阻止重复选择、预览和页面退场。
  bool _picking = false;

  /// 当前原生选择会话的失效回调；页面销毁时停表并禁用面板，信号在完整退场后释放。
  VoidCallback? _revokeMentionSelection;

  /// 初始化时捕获的宿主身份，不写入草稿或持有认证资源。
  late final Object? _sessionIdentity;

  /// 会话或借用端口变化后不可恢复旧页面，避免身份切回后接受旧异步结果。
  bool _sessionRevoked = false;

  /// 页面拥有的身份采样定时器，仅配置宿主身份读取器时创建，销毁时取消。
  Timer? _sessionWatch;

  /// 宿主身份变化后，旧页面不接收异步操作结果。
  bool get _sameAccount =>
      !_sessionRevoked && widget.sessionIdentity?.call() == _sessionIdentity;

  /// 校验当前宿主身份；首次失败冻结旧正文并撤销所有在途选人结果。
  bool _checkSession() {
    if (!mounted) return false;
    if (_sameAccount) return true;
    _revokeSession();
    return false;
  }

  /// 永久冻结当前页面；存储仍归原会话，退场时仅保存其已有正文。
  void _revokeSession() {
    if (_sessionRevoked || !mounted) return;
    _sessionWatch?.cancel();
    _revokeMentionSelection?.call();
    final state = _journal?.editor.editorState;
    if (state != null && !state.isDisposed) {
      state.editable = false;
      state.service.keyboardService?.closeKeyboard();
    }
    setState(() => _sessionRevoked = true);
  }

  /// [oldWidget]的存储、分区或借用端口变化后拒绝复用旧状态；身份回调可更新但值须稳定。
  @override
  void didUpdateWidget(covariant LocalJournalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser?.id != widget.currentUser?.id ||
        oldWidget.mode != widget.mode ||
        !identical(oldWidget.store, widget.store) ||
        oldWidget.storageScope != widget.storageScope ||
        !identical(oldWidget.hostServices, widget.hostServices) ||
        !identical(oldWidget.imageActions, widget.imageActions) ||
        !identical(oldWidget.mentionDirectory, widget.mentionDirectory)) {
      _revokeSession();
    } else {
      _checkSession();
    }
  }

  /// 注册生命周期监听并开始读取；加载期间不创建空文档替代未知草稿。
  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _sessionIdentity = widget.sessionIdentity?.call();
    _mentionDirectory =
        widget.mentionDirectory ?? const EmptyMentionDirectory();
    _services = widget.hostServices.withMentionUserPicker(_pickMentionUser);
    if (widget.sessionIdentity != null) {
      _sessionWatch = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => _checkSession(),
      );
    }
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  /// 异步读取本页store；页面已移除时关闭迟到会话，不向另一个页面回写。
  /// 不支持的引用类型在编辑会话创建前拒绝，展示专用说明并保留重试入口。
  Future<void> _load() async {
    if (_loading || !_checkSession()) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final journal = await LocalJournalController.open(
        store: widget.store,
        services: _services,
        autoSave: !_remote && !_readOnly,
        readOnly: _readOnly,
      );
      if (!mounted || !_checkSession()) {
        await journal.close();
        return;
      }
      _sectionActionsSignature = _sectionSignature(journal);
      journal.addListener(_refreshSectionActions);
      setState(() => _journal = journal);
    } on UnsupportedGuidanceMentionType catch (error) {
      if (mounted && _checkSession()) {
        setState(() => _loadError = error.message);
      }
    } catch (_) {
      if (mounted) setState(() => _loadError = '日记读取失败，请重试。原记录不会被覆盖。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 在[state]进入非前台状态时保存；flush自行转存储异常为可重试状态。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_readOnly &&
        !_remote &&
        _sameAccount &&
        state != AppLifecycleState.resumed &&
        _journal != null) {
      unawaited(_journal!.flush());
    }
  }

  /// 先注销观察者，视图卸载后关闭本页独占的正文会话。
  @override
  void dispose() {
    _sessionWatch?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _journal?.removeListener(_refreshSectionActions);
    _revokeMentionSelection?.call();
    _revokeMentionSelection = null;
    unawaited(
      _release().catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'daily guidance',
            context: ErrorDescription('关闭今日导向页面资源'),
          ),
        );
      }),
    );
    super.dispose();
  }

  /// 完整卸载视图后释放本页正文，编辑会话按所属模式等待保存。
  Future<void> _release() async => _journal?.close();

  /// 读取[journal]可见的可选栏目身份，不读取正文内容或序列化文档。
  String _sectionSignature(LocalJournalController journal) =>
      '${journal.hasSection('reflection')}:${journal.hasSection('self-check')}';

  /// 响应新增、关闭及撤销重做造成的栏目变化，普通文字和保存状态变化只刷新原有局部视图。
  void _refreshSectionActions() {
    final journal = _journal;
    if (!mounted || journal == null) return;
    final next = _sectionSignature(journal);
    if (next == _sectionActionsSignature) return;
    setState(() => _sectionActionsSignature = next);
  }

  /// 正常退出前冻结输入并等待最新修订落盘；失败留在当前页供重试，不丢失内存正文。
  Future<void> _leave() async {
    if (_leaving || _picking || _submitting) return;
    setState(() => _leaving = true);
    final journal = _journal;
    if (!_readOnly &&
        _remote &&
        journal != null &&
        journal.dirty &&
        _sameAccount) {
      final save = await showJournalDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          scrollable: true,
          icon: const Icon(LucideIcons.save),
          title: const Text('有尚未保存的修改'),
          content: const Text('是否保存后离开？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('继续编辑'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('放弃修改'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存后离开'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (save == null || !_checkSession()) {
        setState(() => _leaving = false);
        return;
      }
      if (!save) {
        setState(() => _canPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }
    journal?.editor.editorState.service.keyboardService?.closeKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    if (journal != null) journal.editor.editorState.editable = false;
    final saved =
        _readOnly || journal == null || !_sameAccount || await journal.flush();
    if (!mounted) return;
    if (!saved) {
      journal.editor.editorState.editable = !_readOnly && _checkSession();
      setState(() => _leaving = false);
      return;
    }
    setState(() => _canPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  /// 结束输入后提交当前正文，异步返回仅更新原页面、文档和宿主会话。
  /// 请求失败由控制器保留正文及重试状态；不创建文件或替代路由。
  Future<void> _saveContent() async {
    final journal = _journal;
    if (journal == null ||
        _readOnly ||
        _submitting ||
        _picking ||
        _leaving ||
        !_checkSession()) {
      return;
    }
    setState(() => _submitting = true);
    final state = journal.editor.editorState;
    final paused = state.localTransactionsPaused;

    /// 检查此次提交是否仍属于原文档和会话。
    bool current() =>
        mounted &&
        _checkSession() &&
        identical(_journal, journal) &&
        !journal.closed;
    try {
      state.service.keyboardService?.closeKeyboard();
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await WidgetsBinding.instance.endOfFrame;
      if (!current()) return;
      state.localTransactionsPaused = true;
      final saved = await journal.flush();
      if (mounted && current() && saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_remote ? '已保存到后台' : '已保存到本机')));
      }
    } catch (_) {
      if (mounted && current()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，内容已保留，请重试')));
      }
    } finally {
      if (!state.isDisposed) state.localTransactionsPaused = paused;
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 为当前只读文档打开完整截图和品牌分享页；路由独占快照，不保存或滚动原文档。
  /// 异步完成及平台操作前校验原页面、账号及文档；关闭后恢复分享入口。
  Future<void> _sharePreview() async {
    final journal = _journal;
    if (!_readOnly ||
        journal == null ||
        _sharing ||
        _leaving ||
        !_checkSession()) {
      return;
    }
    setState(() => _sharing = true);

    /// 判断截图和分享是否仍属于同一页面、文档及宿主会话。
    bool current() =>
        mounted &&
        _checkSession() &&
        identical(_journal, journal) &&
        !journal.closed &&
        !_leaving;
    final snapshot = journal.editor.editorState.document.toJson();
    final route = MaterialPageRoute<void>(
      builder: (_) => JournalSharePage(
        document: snapshot,
        commandContext: journal.editor.commandContext,
        isCurrent: current,
        width: MediaQuery.sizeOf(context).width.clamp(0, 680).toDouble(),
        actions: widget.imageActions,
        header:
            journal
                    .editor
                    .editorState
                    .document
                    .root
                    .attributes[journalPlainDesktopAttribute] ==
                true
            ? const SizedBox.shrink()
            : _JournalHeader(
                title: _title,
                currentUser: widget.currentUser,
                services: _services,
                date: journal.date,
                chooseDate: false,
                onChoose: null,
                onDate: (_) {},
              ),
      ),
    );
    try {
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// 添加或关闭[kind]栏目；[close]默认false，失败显示提示且保留正文。
  Future<void> _section(String kind, {bool close = false}) async {
    final journal = _journal;
    if (journal == null ||
        _submitting ||
        _picking ||
        _readOnly ||
        _leaving ||
        !_sameAccount) {
      return;
    }
    try {
      if (close) {
        await journal.closeSection(kind);
      } else {
        await journal.addSection(kind);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('栏目操作失败，内容已保留')));
      }
    }
  }

  /// 使用借用的[context]为原生提及单选用户；[keyword]为初始搜索词。
  /// [canEdit]由编辑器持有，本页额外复核账号、正文、预览和退场状态。
  /// 等待选择界面完全退出后返回；取消或页面会话失效返回null，不写正文。
  /// 宿主身份读取器在面板期间每200毫秒采样，并在返回前同步复核。
  /// 一旦观测到账号或权限失效便永久禁用该选择会话；账号变化同时冻结旧正文。
  /// 本方法拥有权限信号和定时器，页面销毁时先停表，面板完整退场后解除监听并释放信号。
  Future<CollabMentionUser?> _pickMentionUser(
    BuildContext context, {
    required String keyword,
    required ValueListenable<bool> canEdit,
  }) async {
    final journal = _journal;
    if (!_sameAccount && journal != null && !journal.closed) {
      journal.editor.editorState.editable = false;
    }
    if (!mounted ||
        journal == null ||
        journal.closed ||
        _submitting ||
        _picking ||
        _leaving ||
        _readOnly ||
        !_sameAccount ||
        !canEdit.value) {
      return null;
    }
    setState(() => _picking = true);
    final allowed = ValueNotifier<bool>(true);
    Timer? permissionTimer;
    var revoked = false;
    var accountRevoked = false;

    /// 永久撤销当前选择权限并停止采样；页面销毁可调用，不提前释放面板借用的信号。
    void revoke() {
      if (revoked) return;
      revoked = true;
      permissionTimer?.cancel();
      allowed.value = false;
    }

    /// 同步复核本页身份及借用权限；失效后恢复原身份也不重新启用旧选择结果。
    void checkPermission() {
      if (!_sameAccount) accountRevoked = true;
      if (!mounted ||
          accountRevoked ||
          !identical(_journal, journal) ||
          journal.closed ||
          _leaving ||
          _readOnly ||
          !canEdit.value) {
        revoke();
      }
      if (accountRevoked && !journal.closed) {
        journal.editor.editorState.editable = false;
      }
    }

    _revokeMentionSelection = revoke;
    canEdit.addListener(checkPermission);
    checkPermission();
    if (!revoked) {
      permissionTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => checkPermission(),
      );
    }
    try {
      final customPicker = widget.hostServices.pickMentionUser;
      final user = customPicker == null
          ? await showDemoMentionPicker(
              context,
              canEdit: allowed,
              directory: _mentionDirectory,
              keyword: keyword,
            )
          : await customPicker(context, keyword: keyword, canEdit: allowed);
      checkPermission();
      return revoked ? null : user;
    } finally {
      permissionTimer?.cancel();
      canEdit.removeListener(checkPermission);
      checkPermission();
      if (identical(_revokeMentionSelection, revoke)) {
        _revokeMentionSelection = null;
      }
      allowed.dispose();
      if (mounted) setState(() => _picking = false);
    }
  }

  /// 复用原生@人员选择，为[kind]创建领航员或都来帮行，保留来源正文。
  /// 临时暂停本地事务而不撤销编辑权限；完整退场后复核会话、目标修订并恢复输入。
  Future<void> _pickPeople({required String kind}) async {
    final journal = _journal;
    if (journal == null ||
        _submitting ||
        _picking ||
        _readOnly ||
        _leaving ||
        !_sameAccount) {
      return;
    }
    final state = journal.editor.editorState;
    if (!state.canAcceptLocalTransactions) return;
    final target = journal.captureInsertionTarget();
    if (target == null) return;
    final wasPaused = state.localTransactionsPaused;

    /// 仅允许仍属本页且可写的同一日记会话接收结果或恢复输入。
    bool current() =>
        mounted &&
        _checkSession() &&
        identical(_journal, journal) &&
        !journal.closed &&
        !state.isDisposed &&
        state.editable &&
        !_leaving &&
        !_readOnly;

    state.service.keyboardService?.closeKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    state.localTransactionsPaused = true;
    try {
      final user = await pickEditorMentionUser(context, state);
      if (!current()) return;
      state.localTransactionsPaused = wasPaused;
      if (user != null) {
        await journal.insertUserEntry(target, user, kind: kind);
      } else if (state.getNodeAtPath(target.selection.start.path)?.id ==
          target.nodeId) {
        state.selection = target.selection;
      }
    } catch (_) {
      if (mounted && current()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('人员插入失败，原文已保留，请重试')));
      }
    } finally {
      if (!state.isDisposed) state.localTransactionsPaused = wasPaused;
      await WidgetsBinding.instance.endOfFrame;
      if (current()) {
        final selection = state.selection;
        if (selection != null && state.canInputAt(selection)) {
          await state.updateSelectionWithReason(
            selection,
            reason: SelectionUpdateReason.uiEvent,
          );
        }
      }
    }
  }

  /// 为[journal]构建键盘上方的四个宿主动作，已存在的可选栏目不重复提供添加入口。
  /// 各动作的Future包含选人、写入及输入恢复，外壳据此串行化其他工具栏操作。
  List<EditorKeyboardAction> _keyboardActions(LocalJournalController journal) {
    final enabled = !_submitting && !_picking && !_leaving && _sameAccount;
    return [
      if (!journal.hasSection('reflection'))
        EditorKeyboardAction(
          id: 'guidance-add-reflection',
          label: '感悟',
          icon: LucideIcons.lightbulb,
          enabled: enabled,
          onPressed: () => _section('reflection'),
        ),
      EditorKeyboardAction(
        id: 'guidance-action-pilot',
        label: '领航员',
        icon: LucideIcons.compass,
        enabled: enabled,
        onPressed: () => _pickPeople(kind: 'pilot'),
      ),
      EditorKeyboardAction(
        id: 'guidance-action-help',
        label: '都来帮',
        icon: LucideIcons.users,
        enabled: enabled,
        onPressed: () => _pickPeople(kind: 'help'),
      ),
      if (!journal.hasSection('self-check'))
        EditorKeyboardAction(
          id: 'guidance-add-self-check',
          label: '自检',
          icon: LucideIcons.listChecks,
          enabled: enabled,
          onPressed: () => _section('self-check'),
        ),
    ];
  }

  /// 在[context]构建独立路由，保存状态与页面纸张分离，预览让纸张延伸到系统状态栏下，返回入口悬浮在封面上。
  @override
  Widget build(BuildContext context) {
    final journal = _journal;
    return Localizations.override(
      context: context,
      delegates: const [AppFlowyEditorLocalizations.delegate],
      child: PopScope(
        canPop: _canPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_leave());
        },
        child: Scaffold(
          backgroundColor: const Color(0xfffaf8f0),
          extendBodyBehindAppBar: _readOnly,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _readOnly && journal != null && !_sessionRevoked
              ? _JournalPreviewActions(
                  liked: _previewLiked,
                  onShare: _leaving || _sharing
                      ? null
                      : () => unawaited(_sharePreview()),
                  onLike: _leaving
                      ? null
                      : () {
                          if (_checkSession()) {
                            setState(() => _previewLiked = !_previewLiked);
                          }
                        },
                )
              : null,
          appBar: AppBar(
            titleSpacing: 0,
            leadingWidth: _readOnly ? 56 : 48,
            titleTextStyle: Theme.of(context).textTheme.titleMedium,
            backgroundColor: _readOnly
                ? Colors.transparent
                : const Color(0xfffaf8f0),
            elevation: _readOnly ? 0 : null,
            scrolledUnderElevation: _readOnly ? 0 : null,
            forceMaterialTransparency: _readOnly,
            systemOverlayStyle: _readOnly
                ? SystemUiOverlayStyle.dark.copyWith(
                    statusBarColor: Colors.transparent,
                    systemStatusBarContrastEnforced: false,
                  )
                : null,
            leading: Padding(
              padding: _readOnly ? const EdgeInsets.all(4) : EdgeInsets.zero,
              child: IconButton(
                key: const ValueKey('journal-back'),
                tooltip: _remote || _readOnly ? '返回' : '返回并保存',
                style: _readOnly
                    ? IconButton.styleFrom(
                        backgroundColor: const Color(0x66000000),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                      )
                    : null,
                onPressed: _leaving ? null : () => unawaited(_leave()),
                icon: const Icon(LucideIcons.chevronLeft),
              ),
            ),
            title: _readOnly ? null : Text(_title),
            actions: [
              if (journal != null && !_readOnly) ...[
                TextButton(
                  key: const ValueKey('journal-save'),
                  onPressed:
                      _submitting || _leaving || _picking || !_sameAccount
                      ? null
                      : () => unawaited(_saveContent()),
                  child: Text(_submitting ? '保存中…' : '保存'),
                ),
                IconButton(
                  tooltip: '撤销',
                  onPressed: _readOnly || _leaving || _submitting
                      ? null
                      : journal.editor.editorState.undoManager.undo,
                  icon: const Icon(LucideIcons.undo2),
                ),
                IconButton(
                  tooltip: '重做',
                  onPressed: _readOnly || _leaving || _submitting
                      ? null
                      : journal.editor.editorState.undoManager.redo,
                  icon: const Icon(LucideIcons.redo2),
                ),
              ],
            ],
          ),
          body: _sessionRevoked
              ? const Center(child: Text('宿主会话已变化，请关闭后重新打开'))
              : journal == null
              ? Center(
                  child: _loadError == null
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_loadError!),
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => unawaited(_load()),
                                child: const Text('重试读取'),
                              ),
                            ],
                          ),
                        ),
                )
              : SafeArea(
                  top: !_readOnly,
                  child: Column(
                    children: [
                      ListenableBuilder(
                        listenable: journal,
                        builder: (context, _) => journal.error == null
                            ? const SizedBox.shrink()
                            : Semantics(
                                liveRegion: true,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        journal.error!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      key: const ValueKey('journal-retry-save'),
                                      onPressed:
                                          journal.saving ||
                                              _submitting ||
                                              !_sameAccount
                                          ? null
                                          : () => unawaited(_saveContent()),
                                      child: const Text('重试保存'),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: JournalSurface(
                              key: ObjectKey(journal.editor),
                              editorState: journal.editor.editorState,
                              preview: _readOnly || _leaving,
                              onCloseSection:
                                  _readOnly || _leaving || _submitting
                                  ? null
                                  : (kind) =>
                                        unawaited(_section(kind, close: true)),
                              keyboardActions:
                                  _readOnly ||
                                      journal
                                              .editor
                                              .editorState
                                              .document
                                              .root
                                              .attributes[journalPlainDesktopAttribute] ==
                                          true
                                  ? const []
                                  : _keyboardActions(journal),
                              header:
                                  journal
                                          .editor
                                          .editorState
                                          .document
                                          .root
                                          .attributes[journalPlainDesktopAttribute] ==
                                      true
                                  ? const SizedBox.shrink()
                                  : ListenableBuilder(
                                      listenable: journal,
                                      builder: (context, _) => _JournalHeader(
                                        title: _title,
                                        currentUser: _readOnly
                                            ? widget.currentUser
                                            : null,
                                        services: _services,
                                        date: journal.date,
                                        chooseDate: _chooseDate,
                                        onChoose:
                                            _readOnly || _leaving || _submitting
                                            ? null
                                            : () => setState(
                                                () =>
                                                    _chooseDate = !_chooseDate,
                                              ),
                                        onDate: (date) {
                                          journal.setDate(journalDate(date));
                                          setState(() => _chooseDate = false);
                                        },
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// 预览路由独有的悬浮操作组，不持有正文、网络客户端或可编辑状态。
class _JournalPreviewActions extends StatelessWidget {
  /// [liked] 为本次预览的演示状态；[onShare]/[onLike] 由页面持有，null 禁用对应动作。
  const _JournalPreviewActions({
    required this.liked,
    this.onShare,
    this.onLike,
  });

  /// 当前预览是否已点赞，不代表后台持久化状态。
  final bool liked;

  /// 页面拥有的分享动作，null 表示正在分享或退出。
  final VoidCallback? onShare;

  /// 页面拥有的本地点赞/取消动作，null 表示正在退出。
  final VoidCallback? onLike;

  /// 在 [context] 中构建带阴影的圆角按钮，不占据正文布局或接管滚动手势。
  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('journal-preview-actions'),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          key: const ValueKey('journal-share'),
          onPressed: onShare,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff6254ed),
            foregroundColor: Colors.white,
            minimumSize: const Size(132, 48),
            elevation: 4,
            shadowColor: const Color(0x406254ed),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(LucideIcons.forward, size: 18),
          label: const Text('分享'),
        ),
        Semantics(
          toggled: liked,
          label: liked ? '取消点赞' : '点赞',
          child: FilledButton.icon(
            key: const ValueKey('journal-like'),
            onPressed: onLike,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xfffffdf5),
              foregroundColor: const Color(0xff32302a),
              minimumSize: const Size(132, 48),
              elevation: 3,
              shadowColor: const Color(0x26000000),
              shape: const StadiumBorder(),
            ),
            icon: Icon(
              LucideIcons.thumbsUp,
              size: 18,
              color: liked ? const Color(0xff6254ed) : const Color(0xffe7a597),
            ),
            label: Text(liked ? '1' : '0'),
          ),
        ),
      ],
    ),
  );
}

/// 编辑和预览共用的雪山封面，素材随宿主打包，不进入草稿或发起网络请求。
class _JournalCover extends StatelessWidget {
  /// 构建固定封面，不持有编辑会话或外部图片资源。
  const _JournalCover({this.title = '今日导向'});

  /// 与接口 orientType 一致的封面文字，不改变模板正文。
  final String title;

  /// 使用[context]的可用宽度和字号安排图片与标题，底部渐变保证文字对比度。
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledTitle = MediaQuery.textScalerOf(context).scale(22);
        final extraHeight = (scaledTitle - 22).clamp(0.0, 44.0) * 1.4;
        final height = (constraints.maxWidth / 2.1).clamp(184.0, 260.0);
        return SizedBox(
          key: const ValueKey('journal-cover'),
          height: height + extraHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/daily_guidance_mountain.png',
                key: const ValueKey('journal-cover-image'),
                fit: BoxFit.cover,
                alignment: const Alignment(0, -.3),
                excludeFromSemantics: true,
                errorBuilder: (_, error, stackTrace) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xffc6a9ad), Color(0xff26394c)],
                    ),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x000b1726), Color(0xb30b1726)],
                    stops: [.3, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '聚焦每日核心，做深做细各项成果',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xfff0edef),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 预览封面下的当前用户资料行，借用宿主头像组件且不读取账号或修改正文。
class _JournalPreviewUserInfo extends StatelessWidget {
  /// [user] 为宿主当前用户；[services] 提供可选头像构建器。
  /// 所有资料只读，图片及组件资源由 Flutter 生命周期管理。
  const _JournalPreviewUserInfo({required this.user, required this.services});

  /// 当前用户资料快照，仅展示明确提供的字段。
  final CollabMentionUser user;

  /// 页面借用的宿主服务，不取得其资源所有权。
  final CollabHostServices services;

  /// 在 [context] 中按封面宽度排布头像、姓名和部门职位，长文案省略。
  @override
  Widget build(BuildContext context) {
    final subtitle = [user.department, user.position]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' · ');
    final avatar =
        services.mentionAvatarBuilder?.call(
          context,
          userId: user.id,
          name: user.name,
          size: 36,
          avatarUrl: user.avatarUrl,
        ) ??
        DemoMentionAvatar(
          userId: user.id,
          name: user.name,
          size: 36,
          avatarUrl: user.avatarUrl,
        );
    return DecoratedBox(
      key: const ValueKey('journal-preview-user'),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffe9e4d8), width: .5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            ExcludeSemantics(
              child: SizedBox.square(dimension: 36, child: avatar),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.name,
                    key: const ValueKey('journal-preview-user-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff32302a),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xff938d80),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 编辑与预览共用纸张标题和日期；预览可在封面下展示宿主当前用户。
class _JournalHeader extends StatelessWidget {
  /// [date]为YYYY-MM-DD，[title]与 orientType 对应；[chooseDate]控制日历，
  /// [onChoose]为空时只读，[onDate]提交所选日期。
  /// [currentUser] 是预览专属的可选用户资料，默认隐藏。
  /// [services] 借用宿主头像端口，默认空服务，不创建账号或客户端。
  const _JournalHeader({
    required this.date,
    this.title = '今日导向',
    this.currentUser,
    this.services = const CollabHostServices(),
    required this.chooseDate,
    required this.onChoose,
    required this.onDate,
  });

  /// 已保存的记录日期。
  final String date;

  /// 与页面头部一致的业务标题。
  final String title;

  /// 仅预览传入的当前用户资料；null 保留原封面布局。
  final CollabMentionUser? currentUser;

  /// 借用的头像展示服务，不获取资源所有权。
  final CollabHostServices services;

  /// 编辑态是否展开日历。
  final bool chooseDate;

  /// 点击日期的回调，null表示只读。
  final VoidCallback? onChoose;

  /// 提交选中日期，不改变原建档时间。
  final ValueChanged<DateTime> onDate;

  /// 使用[context]渲染已保存日期；日期块沿用正文20像素水平留白，右上月份为大写英文。
  @override
  Widget build(BuildContext context) {
    final value = DateTime.parse(date);
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _JournalCover(title: title),
        if (currentUser case final user?)
          _JournalPreviewUserInfo(user: user, services: services),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: onChoose != null,
              label: '记录日期 $date',
              child: InkWell(
                key: const ValueKey('journal-date'),
                onTap: onChoose,
                child: SizedBox(
                  width: 210,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${value.year}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff777d83),
                            ),
                          ),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                months[value.month - 1],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff777d83),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xff9ca0a0), height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            flex: 3,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                value.day.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  fontSize: 56,
                                  height: 1.1,
                                  color: Color(0xff3e4650),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${value.month}月',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                Text(
                                  weekdays[value.weekday - 1],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff777d83),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xff9ca0a0), height: 14),
                      const Text(
                        'D A I L Y   R E C O R D',
                        style: TextStyle(fontSize: 9, color: Color(0xff979c9c)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (chooseDate)
          CalendarDatePicker(
            key: const ValueKey('journal-calendar'),
            initialDate: value,
            firstDate: DateTime(1900),
            lastDate: DateTime(2100, 12, 31),
            onDateChanged: onDate,
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
