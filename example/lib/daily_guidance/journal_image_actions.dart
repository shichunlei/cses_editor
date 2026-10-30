import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

/// 分享图片的目标；保存走系统文件选择器，微信动作交由当前宿主平台。
enum JournalImageTarget {
  /// 微信会话。
  wechat,

  /// 微信朋友圈。
  timeline,

  /// 将 PNG 保存到用户选择的位置。
  save,
}

/// 页面借用的图片操作端口，不读取账号，不持有客户端或订阅。
///
/// ```dart
/// const actions = JournalImageActions();
/// // await actions.perform(pngBytes, JournalImageTarget.save);
/// ```
class JournalImageActions {
  /// 创建无资源平台适配器；测试或宿主可继承并覆盖 [perform]。
  const JournalImageActions();

  /// 将 [png] 交给 [target]；异步等待系统接收，取消保存返回 false。
  /// 微信返回仅表示已交给客户端，不代表用户已发送；异常交由页面展示。
  Future<bool> perform(Uint8List png, JournalImageTarget target) async {
    if (target == JournalImageTarget.save) {
      final path = await FilePicker.saveFile(
        dialogTitle: '保存分享图片',
        fileName: '今日导向_${DateTime.now().millisecondsSinceEpoch}.png',
        bytes: png,
        mimeType: 'image/png',
      );
      return path != null;
    }
    return await const MethodChannel(
          'cses.offline/journal_image_share',
        ).invokeMethod<bool>('shareImage', {
          'png': png,
          'target': target.name,
        }) ??
        false;
  }
}
