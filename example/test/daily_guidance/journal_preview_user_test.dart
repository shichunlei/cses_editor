import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/guidance_host.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 当前测试拥有的草稿存储，统计是否错误地保存用户资料。
class _Store implements JournalStore {
  /// 当前文档的固定快照。
  final JournalDraft value = JournalDraft.blank(DateTime(2026, 10, 29));

  /// 保存请求计数。
  int writes = 0;

  /// 返回初始文档，不访问后台或账号。
  @override
  Future<JournalDraft?> read() async => value;

  /// 统计对 [draft] 的保存请求，不持有外部资源。
  @override
  Future<void> write(JournalDraft draft) async {
    writes++;
  }
}

/// 验证封面下方的用户栏来自宿主，仅预览展示，不进入正文或账号全局状态。
void main() {
  testWidgets(
    'preview places host user directly below cover and keeps JSON unchanged',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const captureImage = bool.fromEnvironment('SAVE_PREVIEW_USER_SCREENSHOT');
      if (captureImage) {
        await tester.runAsync(() async {
          await ui.loadFontFromList(
            await File(
              '/System/Library/Fonts/STHeiti Medium.ttc',
            ).readAsBytes(),
            fontFamily: 'PreviewUser',
          );
          await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
                rootBundle.load(
                  'packages/lucide_icons_flutter/assets/lucide.ttf',
                ),
              ))
              .load();
        });
      }
      final store = _Store();
      const user = CollabMentionUser(
        id: 'sample-chen',
        name: '示例小陈',
        department: '示例团队',
        position: '前端开发',
      );
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: captureImage ? 'PreviewUser' : null),
            home: LocalJournalPage(
              store: store,
              mode: JournalPageMode.preview,
              currentUser: user,
              hostServices: createDemoGuidanceHostServices(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final info = find.byKey(const ValueKey('journal-preview-user'));
      expect(
        tester.getRect(info).top,
        tester.getRect(find.byKey(const ValueKey('journal-cover'))).bottom,
      );
      expect(find.text('示例小陈'), findsOneWidget);
      expect(find.text('示例团队 · 前端开发'), findsOneWidget);
      expect(find.textContaining('09:41'), findsNothing);
      final avatar = tester.widget<DemoMentionAvatar>(
        find.byType(DemoMentionAvatar),
      );
      expect(avatar.userId, user.id);
      expect(avatar.size, 36);
      final editor = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      expect(editor.editable, isFalse);
      expect(jsonEncode(editor.document.toJson()), isNot(contains(user.name)));
      expect(store.writes, 0);
      if (captureImage) {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/daily_guidance_mountain.png'),
            tester.element(info),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../docs/verification/preview-current-user-20261029/preview.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      expect(store.writes, 0);
    },
  );

  testWidgets(
    'current user is optional and hidden in editing; long labels fit narrow preview',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = _Store();
      const user = CollabMentionUser(
        id: 'u1',
        name: '很长很长的用户名称',
        department: '很长的产品研发部门',
        position: '高级前端开发工程师',
      );
      for (final mode in JournalPageMode.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 760),
                textScaler: TextScaler.linear(2),
              ),
              child: LocalJournalPage(
                key: ValueKey(mode),
                store: store,
                mode: mode,
                currentUser: user,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('journal-preview-user')),
          mode == JournalPageMode.preview ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(
        MaterialApp(
          home: LocalJournalPage(store: store, mode: JournalPageMode.preview),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('journal-preview-user')), findsNothing);
      expect(
        find.byKey(const ValueKey('journal-preview-actions')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'changing current user identity freezes the old document and hides profile',
    (tester) async {
      final store = _Store();
      for (final id in ['u1', 'u2']) {
        await tester.pumpWidget(
          MaterialApp(
            home: LocalJournalPage(
              store: store,
              mode: JournalPageMode.preview,
              currentUser: CollabMentionUser(id: id, name: id),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('宿主会话已变化，请关闭后重新打开'), findsOneWidget);
      expect(find.byKey(const ValueKey('journal-preview-user')), findsNothing);
      expect(
        find.byKey(const ValueKey('journal-preview-actions')),
        findsNothing,
      );
      expect(store.writes, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
