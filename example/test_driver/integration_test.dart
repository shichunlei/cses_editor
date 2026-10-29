import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// 将截图归档到CSES_VERIFICATION_DIR指定目录，缺省为本轮结构迁移分类。
/// 截图只包含示例App自己的测试数据；复跑时可选择新的子目录保留前轮证据。
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final directory = Directory(
        Platform.environment['CSES_VERIFICATION_DIR'] ??
            '../docs/verification/package-layout-20261029',
      );
      await directory.create(recursive: true);
      await File('${directory.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
