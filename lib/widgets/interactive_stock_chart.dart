import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class InteractiveStockChart extends StatelessWidget {
  final List<double> points;
  final bool isPositive;
  final double? baselinePrice;

  const InteractiveStockChart({
    super.key,
    required this.points,
    required this.isPositive,
    this.baselinePrice,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Chart data not available',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      width: double.infinity,
      child: CustomPaint(
        painter: _StockChartPainter(
          points: points,
          isPositive: isPositive,
        ),
      ),
    );
  }
}

class _StockChartPainter extends CustomPainter {
  final List<double> points;
  final bool isPositive;

  _StockChartPainter({
    required this.points,
    required this.isPositive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    double minVal = points.reduce((curr, next) => curr < next ? curr : next);
    double maxVal = points.reduce((curr, next) => curr > next ? curr : next);

    // Padding so it doesn't touch extreme edges
    double diff = maxVal - minVal;
    if (diff == 0) diff = 1.0;
    minVal -= diff * 0.08;
    maxVal += diff * 0.08;
    diff = maxVal - minVal;

    final width = size.width;
    final height = size.height;
    final dx = width / (points.length - 1);

    final linePath = Path();
    final fillPath = Path();

    // Primary chart color based on screenshot: vibrant red (#EF4444) or green (#10B981)
    final lineColor = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    double getY(double val) {
      final normalized = (val - minVal) / diff;
      return height - (normalized * height);
    }

    linePath.moveTo(0, getY(points.first));
    fillPath.moveTo(0, height);
    fillPath.lineTo(0, getY(points.first));

    for (int i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = getY(points[i]);

      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        // Smooth cubic Bezier curve for premium finish
        final prevX = (i - 1) * dx;
        final prevY = getY(points[i - 1]);
        final controlX1 = prevX + (x - prevX) / 2;
        final controlY1 = prevY;
        final controlX2 = prevX + (x - prevX) / 2;
        final controlY2 = y;
        linePath.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
        fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
    }

    fillPath.lineTo(width, height);
    fillPath.close();

    // Subtle gradient fill under the line as seen in screenshot
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, height),
        [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.0),
        ],
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Line stroke
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Highlight last price dot
    final lastX = width;
    final lastY = getY(points.last);
    final dotGlow = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), 6.0, dotGlow);

    final dotCore = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), 3.0, dotCore);
  }

  @override
  bool shouldRepaint(covariant _StockChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.isPositive != isPositive;
  }
}
