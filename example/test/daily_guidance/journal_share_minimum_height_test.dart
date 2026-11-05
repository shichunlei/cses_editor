import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:cses_editor/cses_editor.dart';
import 'package:cses_offline_example/daily_guidance/journal_draft.dart';
import 'package:cses_offline_example/daily_guidance/journal_store.dart';
import 'package:cses_offline_example/daily_guidance/local_journal_page.dart';
import 'package:cses_offline_example/daily_guidance/ui/company_journal_poster.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 独占短正文快照的测试存储，记录分享期间是否意外写入。
class _Store implements JournalStore {
  /// [text] 是每栏正文，[sections] 控制可见栏目数；不持有编辑器资源。
  _Store({required String text, required int sections}) {
    final blank = JournalDraft.blank(DateTime(2026, 11, 5));
    final document = Document(
      root: Node(
        type: 'page',
        children: [
          for (final kind in journalSections.take(sections))
            Node(
              type: journalSectionType,
              attributes: {'section': kind},
              children: [paragraphNode(text: text)],
            ),
        ],
      ),
    );
    try {
      value = JournalDraft.fromJson({
        ...blank.toJson(),
        'document': document.toJson(),
      });
    } finally {
      document.dispose();
    }
  }

  /// 测试持有的独立草稿。
  late final JournalDraft value;

  /// 分享过程必须为零的保存次数。
  int writes = 0;

  /// 异步返回测试快照，无外部资源。
  @override
  Future<JournalDraft?> read() async => value;

  /// 记录对借用 [draft] 的意外保存。
  @override
  Future<void> write(JournalDraft draft) async => writes++;
}

/// 验证实际导出 PNG 包含头尾后至少一屏高，短正文不改写为额外空段落。
void main() {
  for (final scenario in [
    (
      name: 'blank',
      size: const Size(390, 844),
      scale: 1.0,
      text: '',
      poster: null as CompanyJournalPoster?,
      sections: 1,
    ),
    (
      name: 'short',
      size: const Size(390, 844),
      scale: 1.0,
      text: '记录今天的收获',
      poster: null as CompanyJournalPoster?,
      sections: 1,
    ),
    (
      name: 'sections',
      size: const Size(390, 844),
      scale: 1.0,
      text: '今天',
      poster: null as CompanyJournalPoster?,
      sections: 3,
    ),
    (
      name: 'large-text',
      size: const Size(320, 713.5),
      scale: 2.0,
      text: '今天',
      poster: null as CompanyJournalPoster?,
      sections: 1,
    ),
    (
      name: 'ctfs-v2-long',
      size: const Size(390, 844),
      scale: 1.0,
      text: List.filled(20, '今日导向的重点与行动。').join(),
      sections: 3,
      poster: CompanyJournalPoster.ctfsV2,
    ),
    (
      name: 'zqyl-long',
      size: const Size(390, 844),
      scale: 1.0,
      text: List.filled(20, '今日导向的重点与行动。').join(),
      sections: 3,
      poster: CompanyJournalPoster.zqyl,
    ),
  ]) {
    testWidgets(
      '${scenario.name} share PNG includes header/footer and at least one full screen',
      (tester) async {
        await tester.binding.setSurfaceSize(scenario.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const savePosters = bool.fromEnvironment('SAVE_MINIMUM_SHARE_POSTERS');
        if (savePosters) {
          await tester.runAsync(() async {
            await ui.loadFontFromList(
              await File(
                '/System/Library/Fonts/STHeiti Medium.ttc',
              ).readAsBytes(),
              fontFamily: 'ShareMinimum',
            );
          });
        }
        final store = _Store(text: scenario.text, sections: scenario.sections);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: savePosters ? 'ShareMinimum' : null),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: scenario.size,
                textScaler: TextScaler.linear(scenario.scale),
                padding: const EdgeInsets.only(top: 44, bottom: 34),
                viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
              ),
              child: child!,
            ),
            home: LocalJournalPage(
              store: store,
              poster: scenario.poster,
              mode: JournalPageMode.preview,
              currentUser: const CollabMentionUser(
                id: 'test-user',
                name: '测试用户',
                department: '技术部',
                position: '移动端开发',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (scenario.poster == CompanyJournalPoster.ctfsV2) {
          expect(find.byKey(const ValueKey('ctfs-v2-header')), findsOneWidget);
        }
        if (scenario.poster == CompanyJournalPoster.zqyl) {
          expect(find.byKey(const ValueKey('zqyl-header')), findsOneWidget);
        }
        final state = tester
            .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
            .editorState;
        final before = jsonEncode(state.document.toJson());
        await tester.tap(find.byKey(const ValueKey('journal-share')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        final image = find.byKey(const ValueKey('journal-share-image'));
        for (var i = 0; i < 80 && image.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(image, findsOneWidget);
        final png = (tester.widget<Image>(image).image as MemoryImage).bytes;
        await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(png);
          final frame = await codec.getNextFrame();
          try {
            expect(frame.image.width, (scenario.size.width * 2).ceil());
            expect(
              frame.image.height,
              greaterThanOrEqualTo((scenario.size.height * 2).ceil()),
            );
            if (scenario.name == 'blank' || scenario.name == 'short') {
              expect(frame.image.height, (scenario.size.height * 2).ceil());
            }
            if (scenario.poster != null) {
              expect(
                frame.image.height,
                greaterThan((scenario.size.height * 2).ceil()),
              );
            }
            final pixels = (await frame.image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            var footerInk = false;
            for (
              var y = frame.image.height - 140;
              y < frame.image.height - 20 && !footerInk;
              y++
            ) {
              for (var x = 40; x < frame.image.width - 40; x += 4) {
                final i = (y * frame.image.width + x) * 4;
                final red = pixels.getUint8(i);
                final green = pixels.getUint8(i + 1);
                final blue = pixels.getUint8(i + 2);
                final matchesLogo = scenario.poster == CompanyJournalPoster.zqyl
                    ? red > 235 && green > 235 && blue > 235
                    : red < 80 && green < 80 && blue < 80;
                if (matchesLogo) {
                  footerInk = true;
                  break;
                }
              }
            }
            expect(footerInk, isTrue, reason: '品牌图文应位于完整纸张底部');
            if (savePosters) {
              await File(
                '../docs/verification/share-minimum-screen-20261105/${scenario.name}.png',
              ).writeAsBytes(png);
            }
          } finally {
            frame.image.dispose();
            codec.dispose();
          }
        });
        await tester.tap(find.byKey(const ValueKey('journal-share-cancel')));
        await tester.pumpAndSettle();
        expect(jsonEncode(state.document.toJson()), before);
        expect(store.writes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
