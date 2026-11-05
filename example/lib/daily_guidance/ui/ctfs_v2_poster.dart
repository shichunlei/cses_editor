import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 成塔服饰 V2 的圆顶头图和相框交界头像，供编辑和长图共用。
///
/// ```dart
/// CtfsV2Poster.header(date: DateTime(2026, 11, 5), greeting: '上午好', english: 'GOOD MORNING');
/// ```
abstract final class CtfsV2Poster {
  /// 暖橙画布。
  static const canvas = Color(0xfff3ba84);

  /// 原版暖白正文卡。
  static const paper = Color(0xfffffcf8);

  /// 主文字色。
  static const ink = Color(0xff2e241e);

  /// 栏目强调色。
  static const accent = Color(0xffa95a32);

  /// 正文卡的水平外边距。
  static const paperInset = 28.0;

  /// [date] 提供日期牌和星期，[greeting] 与 [english] 是会话问候。
  /// [author] 和 [avatar] 由宿主提供，头像的资源仍由宿主管理。
  static Widget header({
    required DateTime date,
    required String greeting,
    required String english,
    String? author,
    Widget? avatar,
  }) => Padding(
    key: const ValueKey('ctfs-v2-header'),
    padding: const EdgeInsets.fromLTRB(paperInset, 16, paperInset, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                greeting,
                style: const TextStyle(
                  color: ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'][date.weekday -
                  1],
              style: TextStyle(
                color: ink.withValues(alpha: .68),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 288,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: -12,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(180),
                    bottom: Radius.circular(16),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const Image(
                        image: AssetImage(
                          'assets/images/zqyl_default_photo.png',
                        ),
                        fit: BoxFit.cover,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: .12),
                              Colors.transparent,
                              Colors.black.withValues(alpha: .22),
                            ],
                            stops: const [0, .55, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 38,
                left: 0,
                right: 0,
                child: Center(
                  child: DecoratedBox(
                    key: const ValueKey('ctfs-v2-calendar'),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            date.day.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              height: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                date.month.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                date.year.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -10,
                left: 0,
                right: 0,
                height: 54,
                child: Semantics(
                  label: english,
                  child: CustomPaint(painter: _GreetingArc(english)),
                ),
              ),
            ],
          ),
        ),
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            ColoredBox(
              color: paper,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 48, 22, 3),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    author?.trim().isNotEmpty == true ? author! : '今日分享者',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            if (avatar != null)
              Positioned(
                top: -32,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: SizedBox.square(dimension: 54, child: avatar),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

/// 将英文问候沿相框圆弧逐字绘制。
class _GreetingArc extends CustomPainter {
  /// [text] 为当前会话的英文问候。
  const _GreetingArc(this.text);

  /// 原版大写问候。
  final String text;

  /// 以 [size] 的宽度确定半径，在 [canvas] 上沿相框顶部绘制文字。
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final radius = size.width / 2;
    final fontSize = math.min(20.0, size.width / 14);
    final painter = TextPainter(textDirection: TextDirection.ltr);
    final glyphs = text.split('');
    final step = math.min(8 * math.pi / 180, 1.9 / glyphs.length);
    try {
      for (var index = 0; index < glyphs.length; index++) {
        final angle = (index - (glyphs.length - 1) / 2) * step;
        painter.text = TextSpan(
          text: glyphs[index],
          style: TextStyle(
            color: CtfsV2Poster.ink,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        );
        painter.layout();
        canvas.save();
        canvas.translate(
          radius + radius * math.sin(angle),
          10 + radius * (1 - math.cos(angle)),
        );
        canvas.rotate(angle);
        painter.paint(canvas, Offset(-painter.width / 2, 0));
        canvas.restore();
      }
    } finally {
      painter.dispose();
    }
  }

  /// 当 [oldDelegate] 的问候文字变化时重绘。
  @override
  bool shouldRepaint(_GreetingArc oldDelegate) => text != oldDelegate.text;
}
