import 'package:flutter/material.dart';

/// 汇丰永盛 V2 试点的无状态画布、相框和撕纸组件。
///
/// ```dart
/// HfysV2Poster.header(date: DateTime(2026, 11, 5), greeting: '上午好');
/// ```
abstract final class HfysV2Poster {
  /// 深色海报底色。
  static const canvas = Color(0xff162124);

  /// 正文纸色。
  static const paper = Color(0xfffffdf8);

  /// 正文和栏目标题颜色。
  static const ink = Color(0xff263234);

  /// 纸张到画布两侧的逻辑像素距离。
  static const paperInset = 24.0;

  /// [date] 提供记录日期，[greeting] 是会话问候。
  /// [author] 和 [avatar] 由宿主注入，头像资源仍由宿主管理。
  static Widget header({
    required DateTime date,
    required String greeting,
    String? author,
    Widget? avatar,
  }) {
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final label =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    return Padding(
      key: const ValueKey('hfys-v2-header'),
      padding: const EdgeInsets.fromLTRB(paperInset, 14, paperInset, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Transform.rotate(
              angle: .025,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    height: 300,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(3)),
                          child: Image(
                            image: AssetImage(
                              'assets/images/zqyl_default_photo.png',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                canvas.withValues(alpha: .68),
                              ],
                              stops: const [.52, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 15,
                          right: 15,
                          child: Container(
                            key: const ValueKey('hfys-v2-calendar'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .24),
                              border: Border.all(color: Colors.white54),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  date.day.toString().padLeft(2, '0'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 42,
                                    height: .95,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  weekdays[date.weekday - 1],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (author != null)
                          Positioned(
                            left: 15,
                            right: 15,
                            bottom: 15,
                            child: Row(
                              children: [
                                if (avatar != null) ...[
                                  DecoratedBox(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: SizedBox.square(
                                        dimension: 44,
                                        child: avatar,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建纸张收边与铺满画布宽度的离线品牌图。
  /// [showLogo] 仅在预览与分享时绘制品牌图。
  static Widget footer({required bool showLogo}) => Column(
    key: const ValueKey('hfys-v2-footer'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: paperInset),
        child: ClipPath(
          clipper: _HfysPaperEdge(),
          child: const SizedBox(height: 34, child: ColoredBox(color: paper)),
        ),
      ),
      if (showLogo)
        const Padding(
          padding: EdgeInsets.only(top: 20, bottom: 28),
          child: AspectRatio(
            aspectRatio: 758 / 150,
            child: Image(
              key: ValueKey('journal-company-logo'),
              image: AssetImage('assets/images/hfyongsheng_logo.webp'),
              fit: BoxFit.fitWidth,
              semanticLabel: '汇丰永盛',
            ),
          ),
        ),
    ],
  );
}

/// 只裁剪页脚纸边，正文中的交互组件和选区保持完整。
class _HfysPaperEdge extends CustomClipper<Path> {
  /// 在 [size] 内生成固定振幅的锯齿下沿。
  @override
  Path getClip(Size size) {
    final teeth = (size.width / 16).round().clamp(1, 1000);
    final step = size.width / teeth;
    final path = Path()..lineTo(0, size.height - 9);
    for (var index = 0; index < teeth; index++) {
      path
        ..lineTo((index + .5) * step, size.height)
        ..lineTo((index + 1) * step, size.height - 9);
    }
    return path
      ..lineTo(size.width, 0)
      ..close();
  }

  /// 裁剪由当前尺寸决定；替换 [oldClipper] 无额外状态变化。
  @override
  bool shouldReclip(_HfysPaperEdge oldClipper) => false;
}
