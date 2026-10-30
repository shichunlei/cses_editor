import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_image_actions.dart';
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

/// 测试拥有的图片出口，仅记录 PNG 和目标，不打开外部应用。
class _ImageActions extends JournalImageActions {
  /// 记录的全部目标，验证三个按钮传递同一截图。
  final List<JournalImageTarget> targets = [];

  /// 最近一次生成的 PNG，测试结束后由 Dart 回收。
  Uint8List? png;

  /// 模拟外部应用尚未返回，测试防重入与迟到结果。
  Completer<bool>? pending;

  /// 模拟操作异常，验证页面可恢复。
  bool fail = false;

  /// 模拟用户取消保存。
  bool canceled = false;

  /// 接收 [bytes] 和 [target]，模拟异步系统接收成功。
  @override
  Future<bool> perform(Uint8List bytes, JournalImageTarget target) async {
    png = bytes;
    targets.add(target);
    if (fail) throw PlatformException(code: 'test', message: '保存失败，请重试');
    if (pending != null) return pending!.future;
    return !canceled;
  }
}

/// 验证悬浮操作、窄屏适配以及只读文档隔离；可选截图不依赖浏览器或设备。
void main() {
  testWidgets(
    'preview shares the full branded PNG to each target without saving the document',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = _Store();
      final actions = _ImageActions();
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
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: screenshot ? 'PreviewActions' : null),
            home: LocalJournalPage(
              store: store,
              mode: JournalPageMode.preview,
              imageActions: actions,
            ),
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      for (
        var i = 0;
        i < 40 &&
            find
                .byKey(const ValueKey('journal-share-image'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('journal-share-image')), findsOneWidget);
      expect(find.byKey(const ValueKey('journal-back')), findsNothing);
      for (final target in JournalImageTarget.values) {
        await tester.tap(find.byKey(ValueKey('journal-share-${target.name}')));
        await tester.pumpAndSettle();
      }
      expect(actions.targets, JournalImageTarget.values);
      expect(actions.png!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(actions.png!);
        final frame = await codec.getNextFrame();
        // 30 行正文和页脚必须完整进入图片，不能只截到当前手机视口。
        expect(frame.image.height, greaterThan(844 * 2));
        final pixels = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );

        /// 读取已生成 PNG 在 [x]/[y] 位置的 RGBA；不修改图片，资源由本测试释放。
        List<int> rgba(int x, int y) {
          final offset = (y * frame.image.width + x) * 4;
          return [for (var i = 0; i < 4; i++) pixels!.getUint8(offset + i)];
        }

        // 同时验证外层页脚与图片自身留白，避免只改容器后仍然出现白块。
        expect(rgba(8, frame.image.height - 8), [250, 248, 240, 255]);
        expect(rgba(frame.image.width ~/ 2, frame.image.height - 48), [
          250,
          248,
          240,
          255,
        ]);
        frame.image.dispose();
        codec.dispose();
        if (screenshot) {
          await File(
            '../docs/verification/journal-image-share-20261030/poster.png',
          ).writeAsBytes(actions.png!);
        }
        if (const bool.fromEnvironment('SAVE_BEIGE_BRAND_SCREENSHOT')) {
          await File(
            const String.fromEnvironment(
              'BRAND_POSTER_PATH',
              defaultValue:
                  '../docs/verification/share-brand-beige-20261030/poster.png',
            ),
          ).writeAsBytes(actions.png!);
        }
      });
      actions.fail = true;
      await tester.tap(find.byKey(const ValueKey('journal-share-save')));
      await tester.pumpAndSettle();
      expect(find.text('保存失败，请重试'), findsOneWidget);
      actions.fail = false;
      actions.canceled = true;
      await tester.tap(find.byKey(const ValueKey('journal-share-save')));
      await tester.pumpAndSettle();
      expect(find.text('图片已保存'), findsNothing);
      if (screenshot) {
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          try {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '../docs/verification/journal-image-share-20261030/share-panel.png',
            ).writeAsBytes(png!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
      await tester.tap(find.byKey(const ValueKey('journal-share-cancel')));
      await tester.pumpAndSettle();
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
            '../docs/verification/journal-image-share-20261030/preview.png',
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
    'share rejects reentry and ignores completion after host session changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var identity = Object();
      final store = _Store();
      final actions = _ImageActions()..pending = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: LocalJournalPage(
            store: store,
            mode: JournalPageMode.preview,
            imageActions: actions,
            sessionIdentity: () => identity,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('journal-share')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      for (
        var i = 0;
        i < 40 &&
            find
                .byKey(const ValueKey('journal-share-image'))
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final wechat = find.byKey(const ValueKey('journal-share-wechat'));
      await tester.tap(wechat);
      await tester.pump();
      expect(tester.widget<TextButton>(wechat).onPressed, isNull);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('journal-share-timeline')),
            )
            .onPressed,
        isNull,
      );
      expect(actions.targets.length, 1);
      identity = Object();
      actions.pending!.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('已打开分享，请在目标应用中完成发送'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('journal-share-timeline')));
      await tester.pumpAndSettle();
      expect(actions.targets.length, 1);
      expect(find.text('会话已变化，请重新打开预览'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('journal-share-cancel')));
      await tester.pumpAndSettle();
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
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
                padding: EdgeInsets.only(top: 32, bottom: 24),
                viewPadding: EdgeInsets.only(top: 32, bottom: 24),
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
          final appBar = tester.widget<AppBar>(find.byType(AppBar));
          expect(appBar.title, isNull);
          expect(appBar.forceMaterialTransparency, isTrue);
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('journal-cover'))).dy,
            0,
          );
          final back = tester.getRect(
            find.byKey(const ValueKey('journal-back')),
          );
          expect(back.top, greaterThanOrEqualTo(32));
          expect(back.width, greaterThanOrEqualTo(48));
          expect(back.height, greaterThanOrEqualTo(48));
          expect(
            back.bottom,
            lessThan(
              tester
                  .getBottomLeft(find.byKey(const ValueKey('journal-cover')))
                  .dy,
            ),
          );
          for (final key in ['journal-share', 'journal-like']) {
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(320));
            expect(rect.bottom, lessThanOrEqualTo(640 - 24));
          }
        } else {
          expect(tester.widget<AppBar>(find.byType(AppBar)).title, isA<Text>());
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('journal-cover'))).dy,
            greaterThanOrEqualTo(32 + kToolbarHeight),
          );
          expect(
            find.byKey(const ValueKey('journal-preview-actions')),
            findsNothing,
          );
          expect(
            tester
                .widget<DocumentEditorView>(find.byType(DocumentEditorView))
                .padding
                .bottom,
            0,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );
}
