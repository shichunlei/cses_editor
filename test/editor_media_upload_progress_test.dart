import 'dart:async';

import 'package:cses_editor/src/editor/editor_media_source_sheet.dart';
import 'package:cses_editor/src/model/editor_media_upload.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 验证真实媒体面板的遮罩、忙碌态和失败重试流程，上传结果由测试控制。
void main() {
  const media = {
    'image': ('photo.png', 'image/png'),
    'video': ('1000020282.mp4', 'video/mp4'),
    'audio': ('recording.mp3', 'audio/mpeg'),
    'attachment': ('report.pdf', 'application/pdf'),
  };
  final card = find.byKey(const ValueKey('editor-media-pick-file'));
  final submit = find.byKey(const ValueKey('editor-url-block-submit'));

  for (final MapEntry(key: kind, value: (name, mimeType)) in media.entries) {
    testWidgets('$kind 上传遮罩随进度填充，文件信息和按钮位置保持稳定', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final service = _ControlledUpload(name, mimeType);
      final returned = await _openSource(
        tester,
        kind,
        service,
        dark: kind == 'video',
      );

      final contents = [
        card,
        find.byIcon(LucideIcons.cloudUpload),
        find.text(name),
        find.text('0.08 MB · 点击重新选择'),
        submit,
      ];
      final layout = contents.map(tester.getRect).toList();
      expect(_cardOverlay(tester, card), isNull);

      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(find.text('上传中'), findsOneWidget);
      expect(tester.widget<InkWell>(card).onTap, isNull);

      for (final fraction in [0.0, .42, 1.0]) {
        service.reportProgress(fraction);
        await tester.pump();
        final overlay = _cardOverlay(tester, card)!;
        final gradient = overlay.gradient! as LinearGradient;
        expect(overlay.borderRadius, BorderRadius.circular(12));
        expect(gradient.begin, Alignment.centerLeft);
        expect(gradient.end, Alignment.centerRight);
        expect(gradient.stops, [fraction, fraction]);
        expect(gradient.colors.first.a, inExclusiveRange(0, 1));
        expect(gradient.colors.last, Colors.transparent);
        expect(contents.map(tester.getRect), orderedEquals(layout));
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.textContaining('%'), findsNothing);
        expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      }

      await tester.tap(submit, warnIfMissed: false);
      expect(service.attempts, 1);
      const uploaded = EditorMediaSource('https://example.com/media');
      service.result.complete(uploaded);
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(returned.isCompleted, isTrue);
      expect(await returned.future, same(uploaded));
    });
  }

  testWidgets('上传失败清除遮罩，重试可取消且迟到结果被丢弃', (tester) async {
    final service = _ControlledUpload('report.pdf', 'application/pdf');
    final returned = await _openSource(tester, 'attachment', service);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    service.reportProgress(.42);
    service.result.completeError(const FormatException('上传失败'));
    await tester.pumpAndSettle();

    expect(_cardOverlay(tester, card), isNull);
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('上传失败'), findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(service.attempts, 2);
    final gradient = _cardOverlay(tester, card)!.gradient! as LinearGradient;
    expect(gradient.stops, [0.0, 0.0]);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(service.cancelToken.isCancelled, isTrue);
    expect(returned.isCompleted, isTrue);
    expect(await returned.future, isNull);
    service.result.complete(
      const EditorMediaSource('https://example.com/late'),
    );
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// 在 [tester] 中打开 [kind] 的真实来源路由，借用 [service]。
/// [dark] 选择暗色主题。等到选中文件才返回，完成器接收退场后的路由结果。
Future<Completer<EditorMediaSource?>> _openSource(
  WidgetTester tester,
  String kind,
  _ControlledUpload service, {
  bool dark = false,
}) async {
  final returned = Completer<EditorMediaSource?>();
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              returned.complete(
                await showEditorMediaSourceSheet(
                  context,
                  blockType: kind,
                  replacing: true,
                  service: service,
                ),
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
  expect(find.byIcon(LucideIcons.cloudUpload), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('editor-media-pick-file')));
  await tester.pumpAndSettle();
  return returned;
}

/// 从 [tester] 中读取 [card] 的前景装饰，不修改渲染对象。
BoxDecoration? _cardOverlay(WidgetTester tester, Finder card) =>
    (tester.widget<InkWell>(card).child! as Container).foregroundDecoration
        as BoxDecoration?;

/// 提供虚构文件并让测试决定上传进度和结果，不访问文件系统或网络。
class _ControlledUpload implements EditorMediaUploadService {
  /// [name] 和 [mimeType] 用于构造通过面板校验的文件元数据。
  _ControlledUpload(this.name, this.mimeType);

  /// 所选文件名。
  final String name;

  /// 所选文件的媒体类型。
  final String mimeType;

  /// 实际发起上传的次数。
  int attempts = 0;

  /// 最近一次上传的完成器，由测试完成。
  late Completer<EditorMediaSource> result;

  /// 最近一次上传的借用令牌，由面板负责取消。
  late CancelToken cancelToken;

  /// 最近一次上传的借用进度回调，供测试推动进度。
  late void Function(double) reportProgress;

  /// 为 [kind] 的选择请求异步返回测试文件元数据。
  @override
  Future<EditorLocalFile> pickFile(String kind) async => EditorLocalFile(
    path: '/test/$name',
    name: name,
    size: 83886,
    mimeType: mimeType,
  );

  /// 记录 [file] 所属 [kind] 的请求，借用 [cancelToken] 和 [onProgress]。
  /// 返回由测试完成的 Future，不关闭借用资源。
  @override
  Future<EditorMediaSource> upload(
    EditorLocalFile file,
    String kind, {
    required CancelToken cancelToken,
    required void Function(double progress) onProgress,
  }) {
    attempts++;
    this.cancelToken = cancelToken;
    reportProgress = onProgress;
    result = Completer<EditorMediaSource>();
    return result.future;
  }
}
