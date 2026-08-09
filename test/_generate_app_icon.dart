// Not a real test — a one-off (rerunnable) generator for the app icon PNGs
// under assets/icon/, built from the same brand gradient + mark used by
// AppLogo (see shared/widgets/app_widgets.dart) so the launcher icon matches
// the in-app splash logo exactly.
//
// Run with: flutter test test/_generate_app_icon.dart
// Then:     dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// LearnHub Academy brand palette (from learnhub_academy_logo.png).
const _navy = Color(0xFF163A5C);
const _gold = Color(0xFFDBA525);
const _teal = Color(0xFF2AA398);

void main() {
  testWidgets('generate app icon assets', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Full icon: navy fill + centered mark. Used as the base/iOS icon — left
    // un-rounded since iOS/Android apply their own corner masking.
    await _capture(
      tester,
      'assets/icon/icon.png',
      const _IconCanvas(navyBg: true, mark: true, rounded: true),
    );

    // Adaptive icon foreground: transparent bg, mark centered within the
    // ~66% safe zone so it isn't clipped by the OS's adaptive mask.
    await _capture(
      tester,
      'assets/icon/foreground.png',
      const _IconCanvas(navyBg: false, mark: true, scale: 0.86),
    );

    // Adaptive icon background: navy only, full bleed (OS masks it).
    await _capture(
      tester,
      'assets/icon/background.png',
      const _IconCanvas(navyBg: true, mark: false),
    );

    // Extra web-sized exports (for the learning_platform site's favicon +
    // PWA manifest) — same 1024 logical canvas, smaller output resolution.
    await _capture(
      tester,
      'assets/icon/web-512.png',
      const _IconCanvas(navyBg: true, mark: true, rounded: true),
      pixelRatio: 0.5,
    );
    await _capture(
      tester,
      'assets/icon/web-192.png',
      const _IconCanvas(navyBg: true, mark: true, rounded: true),
      pixelRatio: 192 / 1024,
    );
    await _capture(
      tester,
      'assets/icon/web-64.png',
      const _IconCanvas(navyBg: true, mark: true, rounded: true),
      pixelRatio: 64 / 1024,
    );
  });
}

Future<void> _capture(
  WidgetTester tester,
  String path,
  Widget child, {
  double pixelRatio = 1.0,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: SizedBox(width: 1024, height: 1024, child: child),
      ),
    ),
  );
  await tester.pump();

  // Image encoding + file I/O are real async work — must run outside
  // testWidgets' fake-async zone or they hang forever.
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

class _IconCanvas extends StatelessWidget {
  const _IconCanvas({
    required this.navyBg,
    required this.mark,
    this.scale = 1.0,
    this.rounded = false,
  });

  final bool navyBg;
  final bool mark;
  final double scale;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: navyBg ? _navy : null,
        borderRadius: rounded ? BorderRadius.circular(1024 * 0.22) : null,
      ),
      child: mark
          ? Center(
              child: Transform.scale(
                scale: scale,
                child: const CustomPaint(
                  size: Size(1024, 1024),
                  painter: _LearnHubMarkPainter(),
                ),
              ),
            )
          : null,
    );
  }
}

/// Recreation of the LearnHub Academy mark (learnhub_academy_logo.png):
/// a white mortarboard with a gold tassel over a small teal/gold growth-dot
/// connector. Drawn with Canvas paths (no font dependency) so it renders
/// reliably in a headless widget-test environment.
class _LearnHubMarkPainter extends CustomPainter {
  const _LearnHubMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final gold = Paint()
      ..color = _gold
      ..style = PaintingStyle.fill;
    final teal = Paint()
      ..color = _teal
      ..style = PaintingStyle.fill;

    // Mortarboard: flattened diamond top.
    final capTop = Path()
      ..moveTo(w * 0.50, h * 0.16)
      ..lineTo(w * 0.88, h * 0.335)
      ..lineTo(w * 0.50, h * 0.51)
      ..lineTo(w * 0.12, h * 0.335)
      ..close();
    canvas.drawPath(capTop, white);

    // Base band (head area) below the diamond.
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.29, h * 0.40, w * 0.325, h * 0.165),
      Radius.circular(w * 0.025),
    );
    canvas.drawRRect(base, white);

    // Tassel: gold cord + bead.
    final cord = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.032
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.735, h * 0.34),
      Offset(w * 0.735, h * 0.565),
      cord,
    );
    canvas.drawCircle(Offset(w * 0.735, h * 0.605), w * 0.038, gold);

    // Growth-dot connector below the cap.
    const leftDot = Offset(0.315, 0.80);
    const rightDot = Offset(0.685, 0.80);
    const centerDot = Offset(0.50, 0.77);
    final connector = Paint()
      ..color = _teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(leftDot.dx * w, leftDot.dy * h),
      Offset(centerDot.dx * w, centerDot.dy * h),
      connector,
    );
    canvas.drawLine(
      Offset(centerDot.dx * w, centerDot.dy * h),
      Offset(rightDot.dx * w, rightDot.dy * h),
      connector,
    );
    canvas.drawCircle(Offset(leftDot.dx * w, leftDot.dy * h), w * 0.026, teal);
    canvas.drawCircle(
        Offset(rightDot.dx * w, rightDot.dy * h), w * 0.026, teal);
    canvas.drawCircle(
        Offset(centerDot.dx * w, centerDot.dy * h), w * 0.040, gold);
  }

  @override
  bool shouldRepaint(covariant _LearnHubMarkPainter oldDelegate) => false;
}
