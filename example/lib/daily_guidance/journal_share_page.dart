import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_image_actions.dart';
import 'package:cses_offline_example/daily_guidance/journal_surface.dart';
import 'package:cses_offline_example/daily_guidance/ui/journal_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 完整只读纸张截图与品牌图片分享页，独占快照编辑器与滚动控制器。
///
/// ```dart
/// // Navigator.push(context, MaterialPageRoute(builder: (_) => JournalSharePage(
/// //   document: document.toJson(), header: Text('今日导向'),
/// //   commandContext: commandContext, isCurrent: () => mounted)));
/// ```
class JournalSharePage extends StatefulWidget {
  /// [document]是当前正文的独立 JSON 快照；[header]为同版封面、用户及日期。
  /// [commandContext]借用宿主展示端口；[isCurrent]每次异步和操作前校验原会话。
  /// [actions]借用系统分享端口；[width]保持原纸张宽度；[key]标识此分享路由。
  const JournalSharePage({
    super.key,
    required this.document,
    required this.header,
    required this.commandContext,
    required this.isCurrent,
    required this.width,
    this.actions = const JournalImageActions(),
  });

  /// 独立的文档数据，路由不会写回或保存。
  final Map<String, dynamic> document;

  /// 原页面同版的只读头部，不含返回、分享或点赞。
  final Widget header;

  /// 仅借用其中的实例服务，资源仍归宿主。
  final EditorCommandContext commandContext;

  /// 原页面、文档和账号身份仍有效时为 true。
  final bool Function() isCurrent;

  /// 原纸张逻辑宽度，保持正文换行一致。
  final double width;

  /// 借用的分享/保存操作，不由本页释放。
  final JournalImageActions actions;

  /// 创建拥有截图资源的状态。
  @override
  State<JournalSharePage> createState() => _JournalSharePageState();
}

/// 按需渲染完整纸张，生成 PNG 后卸载快照视图，不影响原页面滚动。
class _JournalSharePageState extends State<JournalSharePage> {
  /// 本页独占的只读快照，子视图卸载后关闭。
  late final DocumentEditorController _editor;

  /// 仅包住纸张和品牌页脚，不包含页面操作按钮。
  final GlobalKey _captureKey = GlobalKey();

  /// 本页拥有的 PNG；路由关闭后由 Dart 回收，不写入草稿。
  Uint8List? _png;

  /// 失败信息，允许重新截图。
  String? _error;

  /// 防止同一图片同时多次交给系统。
  bool _busy = false;

  /// 操作栏内的结果提示，不覆盖取消按钮或正文。
  String? _message;

  /// 创建快照并安排首次截图，不接管原编辑器资源。
  @override
  void initState() {
    super.initState();
    _editor = DocumentEditorController(
      document: Document.fromJson(widget.document),
      commandContext: widget.commandContext,
    );
    _editor.editorState.editable = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_capture()));
  }

  /// 原会话失效时停止生成并展示退出提示，避免留下永久加载状态。
  bool _current() {
    if (!mounted) return false;
    if (widget.isCurrent()) return true;
    setState(() => _error = '会话已变化，请关闭后重新打开');
    return false;
  }

  /// 截取完整纸张；异步后核对页面及原会话，图片资源无论成功失败均释放。
  Future<void> _capture() async {
    try {
      await precacheImage(
        const AssetImage('assets/images/中企云链_logo.png'),
        context,
      );
      if (!mounted || !_current()) return;
      await precacheImage(
        const AssetImage('assets/images/daily_guidance_mountain.png'),
        context,
      );
      if (!_current()) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!_current()) return;
      // 全文已一次排版；等待文内图片及头像完成加载，再进行最终绘制。
      final providers = <ImageProvider>{};
      void collect(Element element) {
        final child = element.widget;
        if (child is Image) providers.add(child.image);
        if (child is CircleAvatar) {
          if (child.foregroundImage != null) {
            providers.add(child.foregroundImage!);
          }
          if (child.backgroundImage != null) {
            providers.add(child.backgroundImage!);
          }
        }
        element.visitChildren(collect);
      }

      (_captureKey.currentContext! as Element).visitChildren(collect);
      if (!mounted || !_current()) return;
      await Future.wait(
        providers.map(
          (provider) => precacheImage(provider, context, onError: (_, _) {}),
        ),
      ).timeout(const Duration(seconds: 15));
      if (!_current()) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!_current()) return;
      final boundary =
          _captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      // 限制像素总量和最长边，超长正文明确失败，绝不静默截断尾部。
      final size = boundary.size;
      final ratio = math.min(
        2.0,
        math.min(
          16000 / size.height,
          math.sqrt(24000000 / (size.width * size.height)),
        ),
      );
      if (ratio < .5) throw StateError('正文过长，请缩短内容后生成分享图片');
      final image = await boundary.toImage(pixelRatio: ratio);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (_current()) {
          setState(() => _png = data!.buffer.asUint8List());
        }
      } finally {
        image.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _error = '图片生成失败，请重试或缩短内容');
    }
  }

  /// 将同一 [target] 所需的 PNG 交给宿主，防重入并拒绝失效会话的迟到结果。
  Future<void> _perform(JournalImageTarget target) async {
    final png = _png;
    if (_busy || png == null) return;
    if (!widget.isCurrent()) {
      setState(() => _message = '会话已变化，请重新打开预览');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final completed = await widget.actions.perform(png, target);
      if (!mounted || !widget.isCurrent() || !completed) return;
      setState(
        () => _message = target == JournalImageTarget.save
            ? '图片已保存'
            : '已打开分享，请在目标应用中完成发送',
      );
    } on PlatformException catch (error) {
      if (mounted && widget.isCurrent()) {
        setState(() => _message = error.message ?? '操作失败，请重试');
      }
    } catch (_) {
      if (mounted && widget.isCurrent()) {
        setState(() => _message = '操作失败，请重试或保存图片后分享');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 子视图先卸载，再释放独占快照。
  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_editor.close());
    });
    super.dispose();
  }

  /// 在 [context] 中展示可滚动长图与固定操作栏；加载阶段不影响原页面。
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff17191c),
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: _png != null
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Image.memory(
                      _png!,
                      key: const ValueKey('journal-share-image'),
                      fit: BoxFit.fitWidth,
                    ),
                  )
                : Stack(
                    children: [
                      Center(
                        child: SizedBox(
                          width: widget.width,
                          child: JournalSurface(
                            editorState: _editor.editorState,
                            preview: true,
                            header: widget.header,
                            captureKey: _captureKey,
                            footer: const ColoredBox(
                              color: Color(0xfffaf8f0),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                                child: Image(
                                  image: AssetImage(
                                    'assets/images/中企云链_logo.png',
                                  ),
                                  key: ValueKey('journal-share-brand'),
                                  // 将图片白底融合为纸张米色，原素材不变。
                                  color: Color(0xfffaf8f0),
                                  colorBlendMode: BlendMode.multiply,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: ColoredBox(
                          color: const Color(0xff17191c),
                          child: Center(
                            child: _error == null
                                ? const CircularProgressIndicator()
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() => _error = null);
                                          unawaited(_capture());
                                        },
                                        child: const Text('重试'),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          journalModalTheme(
            context,
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _action(
                            JournalImageTarget.wechat,
                            '微信',
                            LucideIcons.messageCircle,
                            const Color(0xff22ad38),
                          ),
                          _action(
                            JournalImageTarget.timeline,
                            '朋友圈',
                            LucideIcons.aperture,
                            const Color(0xffdc9945),
                          ),
                          _action(
                            JournalImageTarget.save,
                            '保存图片',
                            LucideIcons.download,
                            const Color(0xff494b50),
                          ),
                        ],
                      ),
                    ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_message!, textAlign: TextAlign.center),
                        ),
                      ),
                    if (Theme.of(context).platform == TargetPlatform.iOS)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          '请在系统分享面板中选择微信或朋友圈',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    const Divider(height: 1),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        key: const ValueKey('journal-share-cancel'),
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// 为 [target] 构建等宽操作，[label]/[icon]/[color]提供可读名称和视觉标识。
  Widget _action(
    JournalImageTarget target,
    String label,
    IconData icon,
    Color color,
  ) => Expanded(
    child: TextButton(
      key: ValueKey('journal-share-${target.name}'),
      onPressed: _png == null || _busy
          ? null
          : () => unawaited(_perform(target)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: _png == null || _busy ? Colors.grey : color,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
