import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试拥有的长文档存储，验证预览互动不写入编辑器或后台。
class _Store implements JournalStore {
  /// 创建带原生提及的长正文，不持有外部资源。
  _Store() {
    final blank = JournalDraft.blank(DateTime(2026, 10, 29));
    final document = Document(
      root: Node(
        type: 'page',
        children: [
          Node(
            type: journalSectionType,
            attributes: {'section': 'record'},
            children: [
              for (var i = 0; i < 30; i++)
                paragraphNode(text: '今日记录 $i：认真做好每一件小事'),
              paragraphNode(
                delta: Delta()
                  ..insert('末行 ')
                  ..addAll(
                    EditorUserMention.createDelta(
                      const CollabMentionUser(id: 'u1', name: '小林'),
                    ),
                  ),
              ),
            ],
          ),
        ],
      ),
    );
    value = JournalDraft.fromJson({
      ...blank.toJson(),
      'document': document.toJson(),
    });
    document.dispose();
  }

  /// 测试独占的初始草稿。
  late final JournalDraft value;

  /// 实际保存次数，预览始终应为零。
  int writes = 0;

  /// 返回只读预览的初始快照。
  @override
  Future<JournalDraft?> read() async => value;

  /// 记录对 [draft] 的错误提交。
  @override
  Future<void> write(JournalDraft draft) async => writes++;
}

/// 验证悬浮操作、窄屏适配以及只读文档隔离；可选截图不依赖浏览器或设备。
void main() {
  testWidgets(
    'preview actions float, toggle locally and copy readable text without saving',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = _Store();
      final capture = GlobalKey();
      const screenshot = bool.fromEnvironment('SAVE_PREVIEW_ACTION_SCREENSHOT');
      if (screenshot) {
        await tester.runAsync(() async {
          await ui.loadFontFromList(
            await File(
              '/System/Library/Fonts/STHeiti Medium.ttc',
            ).readAsBytes(),
            fontFamily: 'PreviewActions',
          );
          await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
                rootBundle.load(
                  'packages/lucide_icons_flutter/assets/lucide.ttf',
                ),
              ))
              .load();
        });
      }
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: screenshot ? 'PreviewActions' : null),
            home: LocalJournalPage(store: store, mode: JournalPageMode.preview),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editor = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      final before = jsonEncode(editor.document.toJson());
      final share = find.byKey(const ValueKey('journal-share'));
      final like = find.byKey(const ValueKey('journal-like'));
      final position = tester.getTopLeft(share);
      await tester.drag(find.byType(AppFlowyEditor), const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(share), position);
      expect(
        tester
            .widget<DocumentEditorView>(find.byType(DocumentEditorView))
            .padding
            .bottom,
        0,
      );
      expect(
        tester
            .widget<SizedBox>(
              find.byKey(const ValueKey('journal-preview-bottom-space')),
            )
            .height,
        greaterThanOrEqualTo(96),
      );
      await tester.tap(like);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: like, matching: find.text('1')),
        findsOneWidget,
      );
      await tester.tap(like);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: like, matching: find.text('0')),
        findsOneWidget,
      );
      await tester.tap(share);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journal-share-copy')));
      await tester.pumpAndSettle();
      expect(clipboard, startsWith('今日导向\n2026-10-29\n'));
      expect(clipboard, contains('末行 @小林'));
      expect(clipboard, isNot(contains('\uFFFC')));
      expect(jsonEncode(editor.document.toJson()), before);
      expect(editor.editable, isFalse);
      expect(store.writes, 0);
      if (screenshot) {
        // 等待复制提示退出，记录纯正文和悬浮按钮。
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../docs/verification/preview-floating-actions-20261029/preview.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(store.writes, 0);
    },
  );

  testWidgets(
    'actions fit small preview with enlarged text and stay absent in editing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = _Store();
      for (final mode in [JournalPageMode.preview, JournalPageMode.edit]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.8),
                padding: EdgeInsets.only(bottom: 24),
                viewPadding: EdgeInsets.only(bottom: 24),
              ),
              child: LocalJournalPage(
                key: ValueKey(mode),
                store: store,
                mode: mode,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (mode == JournalPageMode.preview) {
          for (final key in ['journal-share', 'journal-like']) {
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(320));
            expect(rect.bottom, lessThanOrEqualTo(640 - 24));
          }
        } else {
          expect(
            find.byKey(const ValueKey('journal-preview-actions')),
            findsNothing,
          );
          expect(
            tester
                .widget<DocumentEditorView>(find.byType(DocumentEditorView))
                .padding
                .bottom,
            40,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );
}
