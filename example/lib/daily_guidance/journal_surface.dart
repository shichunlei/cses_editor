import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/ui/company_journal_poster.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import 'guidance_entries.dart';
import 'journal_draft.dart';
import 'journal_editing.dart';
import 'journal_exchange_keys.dart';
import 'journal_list_markers.dart';
import 'journal_ruled_content.dart';

/// 日记纸张展示配置；通过共用DocumentEditorView提供编辑和预览，借用会话，不释放正文。
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:cses_offline_example/daily_guidance/journal_surface.dart';
/// import 'package:cses_offline_example/daily_guidance/local_journal_controller.dart';
/// Widget journalBody(LocalJournalController journal) => JournalSurface(
///   editorState: journal.editor.editorState, preview: false, header: Text(journal.date));
/// ```
class JournalSurface extends StatelessWidget {
  /// [key]控制身份，[editorState]由日记会话拥有，[preview]关闭输入、选区和工具栏。
  /// [header]为与正文一起滚动的纸张标题和日期，编辑与预览使用相同布局。
  /// [onCloseSection]接收可选栏目种类，由宿主持有且可空。
  /// [captureKey]非空时启用完整纸张截图布局；[footer]覆盖默认文档尾部留白，用于分享品牌页脚。
  /// [keyboardActions]为宿主自定义快捷项，默认空；工具栏等待每个动作完成，模态输入恢复由宿主负责。
  /// [recordTitle]为首栏目展示标题，由宿主按 orientType 传入，不写正文。
  /// [poster] 选择画布和正文卡样式，省略时沿用日记纸。
  const JournalSurface({
    super.key,
    required this.editorState,
    required this.preview,
    required this.header,
    this.recordTitle = '今日记录',
    this.onCloseSection,
    this.keyboardActions = const [],
    this.captureKey,
    this.footer,
    this.poster,
  });

  /// 当前公司海报样式。
  final CompanyJournalPoster? poster;

  /// 分享专用完整纸张边界；创建者持有键，不影响普通预览滚动。
  final GlobalKey? captureKey;

  /// 可选的纸张尾部组件，null 使用各模式的文档末尾留白，仅出现一次。
  final Widget? footer;

  /// 借用的唯一正文会话，调用方必须在视图移除后释放。
  final EditorState editorState;

  /// true 为只读预览并折叠末尾普通空段落；两种模式共用栏目间距，不修改正文。
  final bool preview;

  /// 可选栏目关闭回调；null时不显示关闭按钮，回调由业务页面持有。
  final ValueChanged<String>? onCloseSection;

  /// 宿主提供的自定义工具栏动作；预览不显示，回调及其业务资源由宿主持有。
  final List<EditorKeyboardAction> keyboardActions;

  /// 随纸张滚动的日期头部，不进入正文历史。
  final Widget header;

  /// 宿主提供的首栏目标题，编辑、预览与分享图共用。
  final String recordTitle;

  /// 在[context]注入纸张样式、栏目结构及业务动作；输入、菜单、选区和剪贴板均由共用视图维护。
  /// 编辑/预览使用同一排版配置，正文与滚动资源由共享组件按公开契约管理。
  @override
  Widget build(BuildContext context) {
    final plain =
        editorState.document.root.attributes[journalPlainDesktopAttribute] ==
        true;
    final companyReadOnly =
        preview &&
        (poster == CompanyJournalPoster.hfysV2 ||
            poster == CompanyJournalPoster.ctfsV2);
    final baseStyle = blockCraftSnapshotRootStyle(
      editorState.document.root,
      plain
          ? const TextStyle(fontSize: 16, color: Colors.black)
          : TextStyle(
              fontSize: 16,
              height: companyReadOnly ? 1.5 : 2,
              color: poster != null ? poster!.ink : const Color(0xff3e4650),
            ),
    ).copyWith(fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily);
    final canvas = poster != null
        ? poster!.canvas
        : plain
        ? Colors.white
        : const Color(0xfffaf8f0);
    return ColoredBox(
      color: canvas,
      child: DocumentEditorView(
        editorState: editorState,
        preview: preview,
        header: header,
        editorKey: const ValueKey('journal-editor'),
        // 纸张由栏目提供水平留白，让单栏目头部与横格能共同填满视口。
        padding: plain
            ? const EdgeInsets.symmetric(horizontal: 20)
            : EdgeInsets.zero,
        footer:
            footer ??
            SizedBox(
              key: ValueKey(
                preview
                    ? 'journal-preview-bottom-space'
                    : 'journal-edit-bottom-space',
              ),
              height: preview
                  ? 96 * MediaQuery.textScalerOf(context).scale(16) / 16
                  : 40,
            ),
        onUserMention: (state) =>
            handleEditorUserMentionTrigger(context, state),
        configuration: EditorViewConfiguration(
          keyboardActions: keyboardActions,
          characterShortcuts: [journalParagraphEnter],
          style: (context, style) => style.copyWith(
            textSpanDecorator: decorateGuidanceMention,
            textScaleFactor: MediaQuery.textScalerOf(context).scale(16) / 16,
            cursorColor: const Color(0xff8b6e63),
            selectionColor: const Color(0x337e6257),
            textStyleConfiguration: TextStyleConfiguration(
              text: baseStyle,
              lineHeight: baseStyle.height ?? (plain ? 1.5 : 2),
              applyHeightToFirstAscent: true,
              applyHeightToLastDescent: true,
            ),
          ),
          blockBuilders: (builders) {
            if (plain) {
              return blockCraftSnapshotBuilders({
                ...builders,
                journalSectionType: _JournalSectionBuilder(
                  recordTitle: recordTitle,
                ),
                if (captureKey != null)
                  PageBlockKeys.type: _JournalCapturePageBuilder(
                    captureKey: captureKey!,
                    header: header,
                    footer: footer,
                    canvas: poster != null ? canvas : const Color(0xfffaf8f0),
                  ),
              });
            }
            final config = BlockComponentConfiguration(
              padding: (_) => EdgeInsets.zero,
              placeholderText: (_) => ' ',
              textStyle: (node, {textSpan}) =>
                  textSpan?.children != null ? const TextStyle() : baseStyle,
            );
            final paperBuilders = <String, BlockComponentBuilder>{
              PageBlockKeys.type: captureKey == null
                  ? _JournalPageBuilder()
                  : _JournalCapturePageBuilder(
                      captureKey: captureKey!,
                      header: header,
                      footer: footer,
                      canvas: canvas,
                    ),
              journalSectionType: _JournalSectionBuilder(
                recordTitle: recordTitle,
                preview: preview,
                compactLastSection: captureKey != null,
                poster: poster,
                onClose: preview ? null : onCloseSection,
              ),
              ParagraphBlockKeys.type: ParagraphBlockComponentBuilder(
                configuration: config,
              ),
              HeadingBlockKeys.type: HeadingBlockComponentBuilder(
                configuration: config,
              ),
              BulletedListBlockKeys.type: BulletedListBlockComponentBuilder(
                configuration: config,
                iconBuilder: buildJournalBulletMarker,
              ),
              NumberedListBlockKeys.type: NumberedListBlockComponentBuilder(
                configuration: config,
                iconBuilder: buildJournalNumberMarker,
              ),
              TodoListBlockKeys.type: TodoListBlockComponentBuilder(
                configuration: config,
                iconBuilder: buildJournalTodoMarker,
              ),
            };
            final result = {
              ...builders,
              ...paperBuilders.map(
                (type, builder) => MapEntry(
                  type,
                  type == PageBlockKeys.type || type == journalSectionType
                      ? builder
                      : GuidanceTextBlockBuilder(
                          configureEditorTextBlock(
                            builder,
                            type,
                            listIndentWidth: 28,
                          ),
                        ),
                ),
              ),
            };
            return journalEditorConfiguration(
                  editorState.document,
                ).documentFeatures
                ? blockCraftSnapshotBuilders(result)
                : result;
          },
        ),
      ),
    );
  }
}

/// 为动态栏目注册纯结构渲染器，标题不进入可编辑正文。
class _JournalSectionBuilder extends BlockComponentBuilder {
  /// [preview] 折叠只读栏目末尾空段落；[compactLastSection] 让分享图末栏目紧接品牌页脚。
  /// [onClose] 由页面处理栏目关闭，null 不展示按钮；不拥有外部资源。
  /// [poster] 提供公司正文卡和栏目标题配色。
  /// [recordTitle]为宿主提供的首栏目标题，不修改正文。
  _JournalSectionBuilder({
    required this.recordTitle,
    this.preview = false,
    this.poster,
    this.compactLastSection = false,
    this.onClose,
  });

  /// 分享截图时去掉最后一个栏目的自动底部留白，交由品牌页脚提供间距。
  final bool compactLastSection;

  /// 本构建器所属视图的固定预览模式，不从可变编辑权限推断。
  final bool preview;

  /// 用于绘制正文卡的公司海报。
  final CompanyJournalPoster? poster;

  /// 借用的业务关闭动作。
  final ValueChanged<String>? onClose;

  /// 首栏目展示标题，由宿主按文档类型确定。
  final String recordTitle;

  /// 使用[context]中的借用栏目构建结构组件。
  @override
  BlockComponentWidget build(BlockComponentContext context) => _JournalSection(
    key: context.node.key,
    node: context.node,
    configuration: configuration,
    recordTitle: recordTitle,
    preview: preview,
    poster: poster,
    compactLastSection: compactLastSection,
    onClose: onClose,
  );
}

/// 单个栏目外壳，使用一个编辑器渲染其全部子段落。
class _JournalSection extends BlockComponentStatelessWidget {
  /// [key]保持栏目身份，[node]为受保护的栏目，[configuration]为渲染配置。
  /// [preview] 仅改变只读留白，不修改节点；[compactLastSection] 收紧分享图末栏目。
  /// [onClose] 可空，由宿主负责保存关闭草稿及撤销；组件不释放借用资源。
  /// [poster] 提供公司正文卡和栏目标题配色。
  /// [recordTitle]为首栏目展示标题，其余栏目沿用各自标题。
  const _JournalSection({
    super.key,
    required super.node,
    required super.configuration,
    required this.recordTitle,
    this.preview = false,
    this.poster,
    this.compactLastSection = false,
    this.onClose,
  });

  /// true 时由品牌页脚单独控制最后一个栏目的底部间距。
  final bool compactLastSection;

  /// true 时仅在展示中折叠末尾纯空段落；编辑保留所有可输入节点。
  final bool preview;

  /// 用于绘制正文卡的公司海报。
  final CompanyJournalPoster? poster;

  /// 可选业务关闭回调，不释放。
  final ValueChanged<String>? onClose;

  /// 首栏目标题仅影响展示，不进入正文或历史。
  final String recordTitle;

  /// 在 [context] 构建栏目和横格；两种模式使用相同间距，末栏目接受根视口剩余书写区的最小高度。
  @override
  Widget build(BuildContext context) {
    final editor = context.read<EditorState>();
    if (editor.document.root.attributes[journalPlainDesktopAttribute] == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in node.children)
            editor.renderer.build(context, child),
        ],
      );
    }
    final originalCompanyStyle =
        poster == CompanyJournalPoster.hfysV2 ||
        poster == CompanyJournalPoster.ctfsV2;
    final primary = node.attributes['section'] == 'record';
    final accent = poster == CompanyJournalPoster.ctfsV2
        ? const Color(0xffa95a32)
        : poster?.ink;
    final titleDelta = node.attributes['guidance_heading_delta'];
    final title = primary
        ? recordTitle
        : titleDelta is List
        ? Delta.fromJson(titleDelta).toPlainText()
        : node.attributes['guidance_section_label'] as String? ??
              switch (node.attributes['section']) {
                'reflection' => '感悟',
                _ => '自检',
              };
    final lineHeight = MediaQuery.textScalerOf(context).scale(16) * 2;
    // 只从视图列表移除末尾普通空段落，正文、撤销历史和保存 JSON 均保留。
    final children = preview ? List<Node>.of(node.children) : node.children;
    if (preview) {
      while (children.length > 1 && _previewBlankParagraph(children.last)) {
        children.removeLast();
      }
    }
    final fillPage =
        !compactLastSection &&
        identical(node, node.parent?.children.lastOrNull);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final child in children)
          if (preview && originalCompanyStyle)
            IgnorePointer(child: editor.renderer.build(context, child))
          else
            JournalRuledContent(
              key: ValueKey('journal-lines-${child.id}'),
              lineHeight: lineHeight,
              child: IgnorePointer(
                ignoring: !editor.editable,
                child: editor.renderer.build(context, child),
              ),
            ),
      ],
    );
    final titleText = Text(
      title,
      style: TextStyle(
        fontSize: originalCompanyStyle
            ? (primary ? 20 : 15)
            : (poster != null ? 17 : 13),
        fontWeight: poster != null ? FontWeight.w700 : null,
        color: poster != null ? accent : const Color(0xff9a9387),
      ),
    );
    final content = Padding(
      key: ValueKey('journal-section-${node.attributes['section']}'),
      padding: EdgeInsets.only(
        left: poster == CompanyJournalPoster.zqyl
            ? 26
            : (originalCompanyStyle ? 22 : 20),
        right: poster == CompanyJournalPoster.zqyl
            ? 26
            : (originalCompanyStyle ? 22 : 20),
        bottom:
            fillPage ||
                (compactLastSection &&
                    identical(node, node.parent?.children.lastOrNull))
            ? 0
            : lineHeight,
      ),
      child: _JournalMinimumColumn(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: primary && poster == CompanyJournalPoster.hfysV2 ? 24 : 12,
              bottom: primary && originalCompanyStyle ? 10 : 8,
            ),
            child: Row(
              children: [
                if (originalCompanyStyle) ...[
                  SizedBox(
                    width: primary ? 4 : 3,
                    height: primary ? 20 : 16,
                    child: ColoredBox(color: accent!),
                  ),
                  const SizedBox(width: 8),
                ],
                if (originalCompanyStyle && !primary)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => Row(
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth * .7,
                            ),
                            child: titleText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Divider(
                              height: 1,
                              thickness: .5,
                              color: accent!.withValues(alpha: .35),
                            ),
                          ),
                          if (onClose != null) const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    fit: originalCompanyStyle ? FlexFit.loose : FlexFit.tight,
                    child: titleText,
                  ),
                if (originalCompanyStyle && primary) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 4,
                    height: 20,
                    child: ColoredBox(color: accent!),
                  ),
                ],
                if (node.attributes['section'] != 'record' && onClose != null)
                  InkWell(
                    key: ValueKey(
                      'journal-close-${node.attributes['section']}',
                    ),
                    onTap: () => onClose!(node.attributes['section'] as String),
                    child: const Text(
                      '关闭',
                      style: TextStyle(fontSize: 11, color: Color(0xff9a9387)),
                    ),
                  ),
              ],
            ),
          ),
          if (preview && originalCompanyStyle)
            body
          else
            JournalRuledContent(
              onBlankTap: editor.editable
                  ? () => editor.selection = Selection.collapsed(
                      Position(
                        path:
                            journalContentNodes(node.children)
                                .where((child) => child.delta != null)
                                .lastOrNull
                                ?.path ??
                            node.children.last.path,
                        offset:
                            journalContentNodes(node.children)
                                .where((child) => child.delta != null)
                                .lastOrNull
                                ?.delta
                                ?.length ??
                            0,
                      ),
                    )
                  : null,

              textLines: false,
              lineHeight: lineHeight,
              child: body,
            ),
        ],
      ),
    );
    return poster != null
        ? Padding(
            padding: EdgeInsets.symmetric(horizontal: poster!.paperInset),
            child: ColoredBox(color: poster!.paper, child: content),
          )
        : content;
  }
}

/// 判断借用的 [node] 是否为可在预览栏目末尾折叠的普通空段落。
/// 保留带任务/人员业务标记、子块或非空文本的块；不修改原节点或属性。
bool _previewBlankParagraph(Node node) =>
    node.type == ParagraphBlockKeys.type &&
    node.children.isEmpty &&
    node.attributes[guidanceEntryAttribute] == null &&
    node.delta != null &&
    node.delta!.toPlainText().trim().isEmpty;

/// 分享专用纸张根构建器；在有限编辑器视口内一次排版正文，边界只包住完整内容。
class _JournalCapturePageBuilder extends BlockComponentBuilder {
  /// [captureKey]由分享路由持有；[header]/[footer]为宿主展示组件，不进入文档。
  /// [canvas] 是截图底色。
  _JournalCapturePageBuilder({
    required this.captureKey,
    required this.header,
    required this.canvas,
    this.footer,
  }) : super(configuration: const BlockComponentConfiguration());

  /// 借用的截图定位键。
  final GlobalKey captureKey;

  /// 与原预览一致的封面、用户和日期。
  final Widget header;

  /// 全幅截图背景色。
  final Color canvas;

  /// 截图尾部品牌组件。
  final Widget? footer;

  /// 从 [context] 的根节点构建完整纸张，不持有编辑器资源。
  @override
  BlockComponentWidget build(BlockComponentContext context) =>
      _JournalCapturePage(
        key: context.node.key,
        node: context.node,
        captureKey: captureKey,
        header: header,
        footer: footer,
        canvas: canvas,
      );
}

/// 一次排版完整内容，头部、正文和页脚合计至少一屏高；截图边界位于滚动视口内部。
class _JournalCapturePage extends BlockComponentStatelessWidget {
  /// [key]/[node]保留根身份；[configuration]控制组件样式；[captureKey]定位全文，[header]/[footer]借用宿主展示。
  /// [canvas] 是截图底色。
  const _JournalCapturePage({
    super.key,
    required super.node,
    super.configuration = const BlockComponentConfiguration(),
    required this.captureKey,
    required this.header,
    required this.canvas,
    this.footer,
  });

  /// 分享路由拥有的截图键。
  final GlobalKey captureKey;

  /// 原预览头部。
  final Widget header;

  /// 全幅截图背景色。
  final Color canvas;

  /// 品牌页脚。
  final Widget? footer;

  /// 在 [context] 中渲染借用的只读节点，不修改排版数据。
  @override
  Widget build(BuildContext context) {
    final editor = context.read<EditorState>();
    final sections = [
      for (final child in node.children)
        Padding(
          padding: editor.editorStyle.padding,
          child: IgnorePointer(
            child: ExcludeFocus(child: editor.renderer.build(context, child)),
          ),
        ),
    ];
    return SingleChildScrollView(
      child: RepaintBoundary(
        key: captureKey,
        child: ColoredBox(
          color: canvas,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height,
            ),
            child: _JournalMinimumColumn(
              children: [
                header,
                sections.isEmpty
                    ? const SizedBox.shrink()
                    : _JournalMinimumColumn(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: sections
                                .take(sections.length - 1)
                                .toList(),
                          ),
                          sections.last,
                        ],
                      ),
                footer ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 保留共用根滚动与选区能力，将最后一个栏目的横格补满剩余视口。
class _JournalPageBuilder extends BlockComponentBuilder {
  /// 无自有资源；头尾和节点均借用编辑器上下文。
  _JournalPageBuilder();

  /// 在 [context] 的根节点中保留栏目和头部滚动索引。
  @override
  BlockComponentWidget build(BlockComponentContext context) => _JournalPage(
    key: context.node.key,
    node: context.node,
    header: context.header,
    footer: context.footer,
    wrapper: context.wrapper,
  );
}

/// 按当前栏目自然高度填充末栏目；不改变正文节点、历史或滚动控制器所有权。
class _JournalPage extends PageBlockComponent {
  /// [key]/[node] 保留根身份；[header]/[footer]/[wrapper] 借用共享编辑器配置。
  const _JournalPage({
    super.key,
    required super.node,
    super.header,
    super.footer,
    super.wrapper,
  });

  /// 在 [context] 的有限视口内测量前置栏目，剩余高度仅交给末栏目。
  @override
  Widget build(BuildContext context) => _JournalViewportPage(
    node: node,
    header: header,
    footer: footer,
    wrapper: wrapper,
  );
}

/// 保留根滚动列表的每个栏目索引；测量只影响展示，不写入正文或选区。
class _JournalViewportPage extends StatefulWidget {
  /// [node] 借用当前根节点，[header]/[footer]/[wrapper] 借用编辑器配置，无自有外部资源。
  const _JournalViewportPage({
    required this.node,
    required this.header,
    required this.footer,
    required this.wrapper,
  });

  /// 当前文档根身份，用于丢弃旧布局回调。
  final Node node;

  /// 首栏目之前的日期头部。
  final Widget? header;

  /// 唯一的文档底部留白。
  final Widget? footer;

  /// 借用的块装饰，不改变所有权。
  final BlockComponentWrapper? wrapper;

  /// 创建仅持有布局测量值的状态。
  @override
  State<_JournalViewportPage> createState() => _JournalViewportPageState();
}

/// 缓存当前文档头部及前置栏目的自然高度；不创建控制器、订阅或文档资源。
class _JournalViewportPageState extends State<_JournalViewportPage> {
  /// 以节点对象隔离删除、重插和文档切换后的测量。
  final Map<Node, double> _heights = {};

  /// 切换 [oldWidget] 的文档根时清除旧测量，不接管借用文档生命周期。
  @override
  void didUpdateWidget(_JournalViewportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.node, widget.node)) _heights.clear();
  }

  /// 帧后接收 [root] 中 [node] 的自然 [height]，根节点作为日期头部的测量键。
  /// 仅更新仍挂载的当前文档布局。
  void _recordHeight(Node root, Node node, double height) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(widget.node, root) ||
          (!identical(node, root) && !root.children.contains(node)) ||
          _heights[node] == height) {
        return;
      }
      setState(() {
        _heights.removeWhere(
          (key, _) => !identical(key, root) && !root.children.contains(key),
        );
        _heights[node] = height;
      });
    });
  }

  /// 在 [context] 根据视口和前置栏目自然高度构建末栏最小高度；键盘缩放后自动重算。
  @override
  Widget build(BuildContext context) {
    final root = widget.node;
    if (root.children.isEmpty) {
      return PageBlockComponent(
        node: root,
        header: widget.header,
        footer: widget.footer,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final preceding = root.children.take(root.children.length - 1);
        final header = widget.header;
        final headerHeight = header == null ? 0.0 : _heights[root];
        final remaining =
            headerHeight != null &&
                preceding.every(_heights.containsKey) &&
                constraints.hasBoundedHeight
            ? (constraints.maxHeight -
                      headerHeight -
                      preceding.fold<double>(
                        0,
                        (sum, node) => sum + _heights[node]!,
                      ))
                  .clamp(0.0, double.infinity)
            : 0.0;
        return PageBlockComponent(
          node: root,
          // 真实头部保留在编辑器头部槽内，由编辑器隔离正文选区手势。
          header: header == null
              ? null
              : _JournalMeasureHeight(
                  onHeight: (height) => _recordHeight(root, root, height),
                  child: header,
                ),
          footer: widget.footer,
          wrapper: (context, {required node, required child}) {
            final last = identical(node, root.children.last);
            final content = widget.wrapper == null
                ? child
                : widget.wrapper!(context, node: node, child: child);
            if (last) {
              return ConstrainedBox(
                constraints: BoxConstraints(minHeight: remaining),
                child: content,
              );
            }
            return _JournalMeasureHeight(
              onHeight: (height) => _recordHeight(root, node, height),
              child: content,
            );
          },
        );
      },
    );
  }
}

/// 报告前置栏目的自然布局高度，不增加输入或绘制层。
class _JournalMeasureHeight extends SingleChildRenderObjectWidget {
  /// [child] 为借用栏目，[onHeight] 将布局高度交给拥有者进行帧后更新。
  const _JournalMeasureHeight({required super.child, required this.onHeight});

  /// 不持有外部资源的布局回调。
  final ValueChanged<double> onHeight;

  /// 在 [context] 创建同步测量对象。
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderJournalMeasureHeight(onHeight);

  /// 在 [context] 更新 [renderObject] 的借用回调。
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderJournalMeasureHeight renderObject,
  ) {
    renderObject.onHeight = onHeight;
    renderObject.markNeedsLayout();
  }
}

/// 沿用正文布局，仅发布测量结果；所有异步校验由状态拥有者负责。
class _RenderJournalMeasureHeight extends RenderProxyBox {
  /// [onHeight] 接收当前自然高度，不转移资源所有权。
  _RenderJournalMeasureHeight(this.onHeight);

  /// 由当前组件更新的测量回调。
  ValueChanged<double> onHeight;

  /// 自然排版后报告高度；不修改文档或请求焦点。
  @override
  void performLayout() {
    super.performLayout();
    onHeight(size.height);
  }
}

/// 头部与可选页脚按自然高度排版，剩余最小高度交给第二项正文；不做固有高度测量。
class _JournalMinimumColumn extends MultiChildRenderObjectWidget {
  /// [children] 为借用的头部、正文及可选第三项页脚，不持有编辑器资源。
  const _JournalMinimumColumn({required super.children});

  /// 为 [context] 创建同步布局对象。
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderJournalMinimumColumn();
}

/// 纵向排版的偏移与兄弟链，不持有资源。
class _JournalColumnParentData extends ContainerBoxParentData<RenderBox> {}

/// 先测量头尾，再把剩余最小高度传给正文，支持日期、大字和键盘尺寸变化。
class _RenderJournalMinimumColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _JournalColumnParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _JournalColumnParentData> {
  /// 为借用的 [child] 安装纵向布局偏移数据。
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _JournalColumnParentData) {
      child.parentData = _JournalColumnParentData();
    }
  }

  /// 头尾使用自然高度，正文至少覆盖约束剩余高度；长内容自然增长。
  @override
  void performLayout() {
    final head = firstChild!;
    final body = childAfter(head)!;
    final footer = childAfter(body);
    final loose = BoxConstraints.tightFor(width: constraints.maxWidth);
    head.layout(loose, parentUsesSize: true);
    footer?.layout(loose, parentUsesSize: true);
    final footerHeight = footer?.size.height ?? 0;
    final remaining = (constraints.minHeight - head.size.height - footerHeight)
        .clamp(0.0, double.infinity);
    body.layout(loose.copyWith(minHeight: remaining), parentUsesSize: true);
    (body.parentData! as _JournalColumnParentData).offset = Offset(
      0,
      head.size.height,
    );
    if (footer != null) {
      (footer.parentData! as _JournalColumnParentData).offset = Offset(
        0,
        head.size.height + body.size.height,
      );
    }
    size = constraints.constrain(
      Size(
        constraints.maxWidth,
        head.size.height + body.size.height + footerHeight,
      ),
    );
  }

  /// 在 [context] 的 [offset] 绘制借用子项，不增加遮挡层。
  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  /// 将 [position] 的输入事件交给实际命中的 [result] 子项。
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
