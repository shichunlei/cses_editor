import 'package:flutter/material.dart';

/// 中企云链海报的离线视觉组件，供编辑、预览及分享共用。
///
/// ```dart
/// ZqylPoster.header(date: '2026-11-05', now: DateTime(2026, 11, 5));
/// ```
abstract final class ZqylPoster {
  /// 品牌绿画布。
  static const canvas = Color(0xff167d3c);

  /// 白卡到画布两侧的距离。
  static const paperInset = 20.0;

  /// 构建原版相框、月日牌和问候区。[date] 是记录日期，[now] 决定时段。
  /// [author] 和 [avatar] 由宿主提供，头像组件及其资源由宿主管理。
  static Widget header({
    required String date,
    required DateTime now,
    String? author,
    Widget? avatar,
  }) {
    final recordDate = DateTime.tryParse(date) ?? now;
    final minutes = now.hour * 60 + now.minute;
    final (greeting, english, large) = switch (minutes) {
      < 180 || >= 1110 => (
        const IconData(0xe760, fontFamily: 'ZqylGreetings'),
        'GOOD NIGHT',
        false,
      ),
      < 510 => (
        const IconData(0xe75f, fontFamily: 'ZqylGreetings'),
        'GOOD MORNING',
        false,
      ),
      < 690 => (
        const IconData(0xe762, fontFamily: 'ZqylGreetings'),
        'GOOD MORNING',
        true,
      ),
      < 810 => (
        const IconData(0xe761, fontFamily: 'ZqylGreetings'),
        'GOOD NOON',
        false,
      ),
      _ => (
        const IconData(0xe75e, fontFamily: 'ZqylGreetings'),
        'GOOD AFTERNOON',
        true,
      ),
    };
    return Padding(
      key: const ValueKey('zqyl-header'),
      padding: const EdgeInsets.fromLTRB(paperInset, 10, paperInset, 0),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(100),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 374,
              child: Stack(
                children: [
                  Positioned(
                    top: 74,
                    left: 26,
                    right: 26,
                    bottom: 0,
                    child: const ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(80),
                      ),
                      child: Image(
                        image: AssetImage(
                          'assets/images/zqyl_default_photo.png',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 26,
                    right: 26,
                    bottom: 0,
                    child: Image(
                      image: AssetImage('assets/images/zqyl_weishiting.webp'),
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                  if (author != null)
                    Positioned(
                      left: 8,
                      right: 102,
                      top: 16,
                      child: Row(
                        children: [
                          if (avatar != null)
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox.square(
                                dimension: 52,
                                child: avatar,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xff333333),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    top: 35,
                    right: 38,
                    child: Text(
                      '${recordDate.month.toString().padLeft(2, '0')}\n${recordDate.day.toString().padLeft(2, '0')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: canvas,
                        fontSize: 38,
                        height: 1.1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 26, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            english,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 5),
                            child: Text(
                              'ZHONG QI YUN LIAN',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const Text(
                            'CHENG GUO DAO XIANG',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: SizedBox(
                              width: 27,
                              height: 3,
                              child: ColoredBox(color: canvas),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Icon(
                    greeting,
                    color: const Color(0xff592c0e),
                    size: large ? 127 : 87,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
          ],
        ),
      ),
    );
  }

  /// 绘制白卡下缘和满画布宽度的本地品牌图。
  /// [showLogo] 仅在预览与分享时绘制品牌图。
  static Widget footer({required bool showLogo}) => Column(
    key: const ValueKey('zqyl-footer'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: paperInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
          ),
          child: SizedBox(height: 20),
        ),
      ),
      if (showLogo)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: AspectRatio(
            aspectRatio: 758 / 150,
            child: Image(
              key: ValueKey('journal-company-logo'),
              image: AssetImage('assets/images/zhongqiyunlian_logo.webp'),
              fit: BoxFit.fitWidth,
              semanticLabel: '中企云链',
            ),
          ),
        ),
    ],
  );
}
