import 'package:cses_offline_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 复现320dp、2倍系统字体及键盘同时存在时，底层首页也会收到视口重排。
void main() {
  testWidgets(
    'home remains scrollable at device large-font keyboard dimensions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 713.5));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 713.5),
            textScaler: TextScaler.linear(2),
            viewInsets: EdgeInsets.only(bottom: 252.75),
          ),
          child: const OfflineExampleApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final preview = find.byKey(const ValueKey('preview-daily-guidance'));
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      expect(preview.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
