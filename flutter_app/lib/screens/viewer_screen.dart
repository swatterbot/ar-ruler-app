import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/models.dart';

class ViewerScreen extends StatefulWidget {
  final List<ScannedObject> objects;
  final String projectName;

  const ViewerScreen({super.key, required this.objects, required this.projectName});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  double _rotX = -0.4;
  double _rotZ = 0.5;
  double _scale = 1.0;
  Offset _lastFocalPoint = Offset.zero;
  double _lastScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.projectName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt, color: Colors.white54),
            tooltip: 'Сбросить вид',
            onPressed: () => setState(() {
              _rotX = -0.4;
              _rotZ = 0.5;
              _scale = 1.0;
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          // 3D Просмотрщик
          Expanded(
            flex: 3,
            child: GestureDetector(
              onScaleStart: (d) {
                _lastFocalPoint = d.focalPoint;
                _lastScale = _scale;
              },
              onScaleUpdate: (d) {
                setState(() {
                  final delta = d.focalPoint - _lastFocalPoint;
                  _rotZ += delta.dx * 0.01;
                  _rotX += delta.dy * 0.01;
                  _rotX = _rotX.clamp(-math.pi / 2, 0);
                  _scale = (_lastScale * d.scale).clamp(0.3, 4.0);
                  _lastFocalPoint = d.focalPoint;
                });
              },
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(
                    painter: _Scene3DPainter(
                      objects: widget.objects,
                      rotX: _rotX,
                      rotZ: _rotZ,
                      scale: _scale,
                    ),
                    child: Container(),
                  ),
                ),
              ),
            ),
          ),

          // Подсказка управления
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.touch_app, size: 14, color: Colors.white38),
                SizedBox(width: 4),
                Text('Перетащите для вращения • Сведите пальцы для масштаба',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Список объектов
          Container(
            height: 140,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              itemCount: widget.objects.length,
              itemBuilder: (ctx, i) {
                final obj = widget.objects[i];
                final isBox = obj.type == ObjectType.box;
                final color = _objectColor(i);
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isBox ? Icons.crop_square : Icons.circle_outlined, color: color, size: 28),
                      const SizedBox(height: 6),
                      Text(obj.name,
                          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(obj.dimensionsLabel,
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                          textAlign: TextAlign.center),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _objectColor(int index) {
    const colors = [
      Color(0xFF58A6FF),
      Color(0xFF3FB950),
      Color(0xFFF78166),
      Color(0xFFD2A8FF),
      Color(0xFFFFA657),
    ];
    return colors[index % colors.length];
  }
}

class _Scene3DPainter extends CustomPainter {
  final List<ScannedObject> objects;
  final double rotX;
  final double rotZ;
  final double scale;

  _Scene3DPainter({
    required this.objects,
    required this.rotX,
    required this.rotZ,
    required this.scale,
  });

  Offset _project(double x, double y, double z, Offset center, double unitPx) {
    final cosZ = math.cos(rotZ);
    final sinZ = math.sin(rotZ);
    final cosX = math.cos(rotX);
    final sinX = math.sin(rotX);

    final rx = x * cosZ - y * sinZ;
    final ry = x * sinZ + y * cosZ;
    final rz = z;

    final ry2 = ry * cosX - rz * sinX;
    final rz2 = ry * sinX + rz * cosX;

    return Offset(
      center.dx + rx * unitPx,
      center.dy - ry2 * unitPx,
    );
  }

  void _drawGrid(Canvas canvas, Offset center, double unitPx) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 0.5;

    for (int i = -5; i <= 5; i++) {
      final a = _project(i.toDouble(), -5, 0, center, unitPx);
      final b = _project(i.toDouble(), 5, 0, center, unitPx);
      canvas.drawLine(a, b, gridPaint);
      final c = _project(-5, i.toDouble(), 0, center, unitPx);
      final d = _project(5, i.toDouble(), 0, center, unitPx);
      canvas.drawLine(c, d, gridPaint);
    }
  }

  void _drawBox(Canvas canvas, Offset center, double unitPx,
      double cx, double cy, double w, double l, double h, Color color) {
    final hw = w / 2;
    final hl = l / 2;

    final vertices = [
      _project(cx - hw, cy - hl, 0, center, unitPx),
      _project(cx + hw, cy - hl, 0, center, unitPx),
      _project(cx + hw, cy + hl, 0, center, unitPx),
      _project(cx - hw, cy + hl, 0, center, unitPx),
      _project(cx - hw, cy - hl, h, center, unitPx),
      _project(cx + hw, cy - hl, h, center, unitPx),
      _project(cx + hw, cy + hl, h, center, unitPx),
      _project(cx - hw, cy + hl, h, center, unitPx),
    ];

    final facePaint = Paint()..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Нижняя грань
    facePaint.color = color.withOpacity(0.15);
    canvas.drawPath(_face([vertices[0], vertices[1], vertices[2], vertices[3]]), facePaint);
    canvas.drawPath(_face([vertices[0], vertices[1], vertices[2], vertices[3]]), edgePaint);

    // Боковые грани
    facePaint.color = color.withOpacity(0.25);
    for (var face in [
      [0, 1, 5, 4],
      [1, 2, 6, 5],
      [2, 3, 7, 6],
      [3, 0, 4, 7],
    ]) {
      canvas.drawPath(_face(face.map((i) => vertices[i]).toList()), facePaint);
      canvas.drawPath(_face(face.map((i) => vertices[i]).toList()), edgePaint);
    }

    // Верхняя грань
    facePaint.color = color.withOpacity(0.35);
    canvas.drawPath(_face([vertices[4], vertices[5], vertices[6], vertices[7]]), facePaint);
    canvas.drawPath(_face([vertices[4], vertices[5], vertices[6], vertices[7]]), edgePaint);
  }

  void _drawCylinder(Canvas canvas, Offset center, double unitPx,
      double cx, double cy, double radius, double h, Color color) {
    const segments = 16;
    final topPoints = <Offset>[];
    final botPoints = <Offset>[];

    for (int i = 0; i < segments; i++) {
      final angle = 2 * math.pi * i / segments;
      final dx = radius * math.cos(angle);
      final dy = radius * math.sin(angle);
      botPoints.add(_project(cx + dx, cy + dy, 0, center, unitPx));
      topPoints.add(_project(cx + dx, cy + dy, h, center, unitPx));
    }

    final facePaint = Paint()..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Боковая поверхность
    for (int i = 0; i < segments; i++) {
      final next = (i + 1) % segments;
      facePaint.color = color.withOpacity(0.2);
      canvas.drawPath(
          _face([botPoints[i], botPoints[next], topPoints[next], topPoints[i]]), facePaint);
      canvas.drawPath(
          _face([botPoints[i], botPoints[next], topPoints[next], topPoints[i]]), edgePaint);
    }

    // Верхняя крышка
    final topPath = Path()..moveTo(topPoints[0].dx, topPoints[0].dy);
    for (final p in topPoints.skip(1)) {
      topPath.lineTo(p.dx, p.dy);
    }
    topPath.close();
    facePaint.color = color.withOpacity(0.35);
    canvas.drawPath(topPath, facePaint);
    canvas.drawPath(topPath, edgePaint);
  }

  Path _face(List<Offset> pts) {
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (final p in pts.skip(1)) path.lineTo(p.dx, p.dy);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unitPx = math.min(size.width, size.height) / 6 * scale;

    _drawGrid(canvas, center, unitPx);

    // Расставляем объекты в ряд
    const colors = [
      Color(0xFF58A6FF),
      Color(0xFF3FB950),
      Color(0xFFF78166),
      Color(0xFFD2A8FF),
      Color(0xFFFFA657),
    ];

    double offsetX = 0;
    for (int i = 0; i < objects.length; i++) {
      final obj = objects[i];
      final color = colors[i % colors.length];
      final step = math.max(obj.width, obj.length) + 0.3;

      if (obj.type == ObjectType.box) {
        _drawBox(canvas, center, unitPx, offsetX, 0, obj.width, obj.length, obj.height, color);
      } else {
        _drawCylinder(canvas, center, unitPx, offsetX, 0, obj.width / 2, obj.height, color);
      }

      // Метка
      final labelPos = _project(offsetX, 0, obj.height + 0.15, center, unitPx);
      final textPainter = TextPainter(
        text: TextSpan(text: obj.name, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, labelPos - Offset(textPainter.width / 2, textPainter.height / 2));

      offsetX += step;
    }

    // Надпись если нет объектов
    if (objects.isEmpty) {
      final emptyPainter = TextPainter(
        text: const TextSpan(
          text: 'Нет объектов',
          style: TextStyle(color: Colors.white38, fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      emptyPainter.paint(canvas, Offset(size.width / 2 - emptyPainter.width / 2, size.height / 2));
    }
  }

  @override
  bool shouldRepaint(_Scene3DPainter old) =>
      old.rotX != rotX || old.rotZ != rotZ || old.scale != scale;
}
