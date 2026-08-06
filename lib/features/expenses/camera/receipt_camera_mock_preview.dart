import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Animated fake camera feed: a drifting “receipt” on a dim scene.
///
/// Used when [ReceiptCameraController] is in mock mode (debug menu).
class ReceiptCameraMockPreview extends StatefulWidget {
  const ReceiptCameraMockPreview({
    super.key,
    required this.torchOn,
    required this.zoom,
    this.paused = false,
  });

  final bool torchOn;
  final double zoom;
  final bool paused;

  /// Renders one mock frame to PNG bytes (works on web + desktop).
  static Future<XFile?> captureStill({
    required bool torchOn,
    required double zoom,
    double? phase,
  }) async {
    final p = phase ?? (DateTime.now().millisecondsSinceEpoch % 8000) / 8000.0;
    const w = 1080.0;
    const h = 1440.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));
    _MockReceiptPainter(
      phase: p,
      torchOn: torchOn,
      zoom: zoom,
    ).paint(canvas, const Size(w, h));
    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return null;
    final name = 'receipt_mock_${DateTime.now().millisecondsSinceEpoch}.png';
    return XFile.fromData(
      bytes.buffer.asUint8List(),
      mimeType: 'image/png',
      name: name,
    );
  }

  @override
  State<ReceiptCameraMockPreview> createState() =>
      _ReceiptCameraMockPreviewState();
}

class _ReceiptCameraMockPreviewState extends State<ReceiptCameraMockPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;

  /// Exposed so the controller can capture the current phase.
  double get phase => _tick.value;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    if (widget.paused) _tick.stop();
  }

  @override
  void didUpdateWidget(covariant ReceiptCameraMockPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused && _tick.isAnimating) {
      _tick.stop();
    } else if (!widget.paused && !_tick.isAnimating) {
      _tick.repeat();
    }
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tick,
      builder: (context, _) {
        return CustomPaint(
          painter: _MockReceiptPainter(
            phase: _tick.value,
            torchOn: widget.torchOn,
            zoom: widget.zoom,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _MockReceiptPainter extends CustomPainter {
  _MockReceiptPainter({
    required this.phase,
    required this.torchOn,
    required this.zoom,
  });

  final double phase;
  final bool torchOn;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(
            const Color(0xFF1A1F24),
            const Color(0xFF3A3220),
            torchOn ? 0.55 : 0.0,
          )!,
          Color.lerp(
            const Color(0xFF0E1216),
            const Color(0xFF2A2418),
            torchOn ? 0.45 : 0.0,
          )!,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // Subtle drifting “floor” grain so the feed feels live.
    final grain = Paint()..color = Colors.white.withValues(alpha: 0.03);
    final t = phase * math.pi * 2;
    for (var i = 0; i < 40; i++) {
      final x = (size.width * ((i * 0.17 + phase) % 1.0));
      final y = (size.height * ((i * 0.09 + phase * 0.6) % 1.0));
      canvas.drawCircle(Offset(x, y), 1.2, grain);
    }

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom.clamp(1.0, 3.0));
    // Drift + slight sway.
    final dx = math.sin(t) * size.width * 0.04;
    final dy = math.cos(t * 0.7) * size.height * 0.05;
    canvas.translate(dx, dy);
    canvas.rotate(math.sin(t * 0.5) * 0.04);

    final receiptW = size.width * 0.55;
    final receiptH = receiptW * (5 / 3);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: receiptW,
      height: receiptH,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFFF4F1EA));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    void drawLine(
      String text,
      double y, {
      double sizePx = 14,
      bool bold = false,
    }) {
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF1C1B1A),
          fontSize: sizePx,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontFamily: 'monospace',
        ),
      );
      textPainter.layout(maxWidth: receiptW * 0.85);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, y - receiptH / 2),
      );
    }

    drawLine('MOCK MARKET', 28, sizePx: 18, bold: true);
    drawLine('Receipt preview', 52, sizePx: 12);
    drawLine('────────────────', 70, sizePx: 12);
    final lines = [
      'Milk                 4.50',
      'Bread                2.25',
      'Eggs                 3.10',
      'Coffee               8.90',
      '────────────────',
      'TOTAL              18.75',
    ];
    var y = 100.0;
    // Scroll line content slowly so OCR framing stays interesting.
    final scroll = (phase * lines.length).floor() % lines.length;
    for (var i = 0; i < lines.length; i++) {
      drawLine(lines[(i + scroll) % lines.length], y, sizePx: 13);
      y += 22;
    }

    canvas.restore();

    // Corner badge.
    final badge = TextPainter(
      text: const TextSpan(
        text: 'MOCK CAM',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 12, badge.width + 16, badge.height + 10),
      const Radius.circular(6),
    );
    canvas.drawRRect(badgeRect, Paint()..color = const Color(0xE0D84315));
    badge.paint(canvas, const Offset(20, 17));

    if (torchOn) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0x33FFC107),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MockReceiptPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.torchOn != torchOn ||
      oldDelegate.zoom != zoom;
}
