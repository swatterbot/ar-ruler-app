import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Matrix4;
import '../database/db_helper.dart';
import '../models/models.dart';

class ARScreen extends StatefulWidget {
  final int projectId;
  const ARScreen({super.key, required this.projectId});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  final List<Vector3> _points = [];
  final List<ARAnchor> _anchors = [];

  ObjectType _selectedType = ObjectType.box;
  bool _isScanning = false;
  double? _lastDistance;
  double _height = 1.0;

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  void onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arAnchorManager = anchorManager;

    arSessionManager!.onInitialize(
      showFeaturePoints: true,
      showPlanes: true,
      customPlaneTexturePath: null,
      showWorldOrigin: false,
      handleTaps: true,
    );

    arObjectManager!.onInitialize();
    arSessionManager!.onPlaneOrPointTap = _onTap;
  }

  Future<void> _onTap(List<ARHitTestResult> results) async {
    if (!_isScanning) return;

    final hit = results.firstWhere(
      (r) => r.type == ARHitTestResultType.plane,
      orElse: () => results.first,
    );

    final pos = _extractPosition(hit.worldTransform);

    // Добавляем якорь для стабилизации точки
    final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
    final didAdd = await arAnchorManager!.addAnchor(anchor);
    if (didAdd != true) return;

    setState(() {
      _points.add(pos);
      _anchors.add(anchor);
    });

    // Расстояние между последними двумя точками
    if (_points.length >= 2) {
      final dist = (_points.last - _points[_points.length - 2]).length;
      setState(() => _lastDistance = dist);
    }

    // Предлагаем сохранить когда набрали нужное кол-во точек
    int needed = _selectedType == ObjectType.box ? 4 : 2;
    if (_points.length == needed) {
      await _askSaveObject();
    }
  }

  Vector3 _extractPosition(Matrix4 m) => Vector3(m[12], m[13], m[14]);

  double _calcDistance(Vector3 a, Vector3 b) => (b - a).length;

  Future<void> _askSaveObject() async {
    final nameController = TextEditingController(
      text: _selectedType == ObjectType.box ? 'Стол' : 'Ведро',
    );
    final heightController = TextEditingController(text: _height.toStringAsFixed(1));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          'Сохранить ${_selectedType == ObjectType.box ? "параллелепипед" : "цилиндр"}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _buildDimensionsText(),
              style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Название объекта',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF30363D))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF58A6FF))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: heightController,
              style: const TextStyle(color: Colors.white),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Высота объекта (м)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF30363D))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF58A6FF))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF238636)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final h = double.tryParse(heightController.text) ?? _height;
      setState(() => _height = h);
      await _saveObject(nameController.text.trim(), h);
    }

    _resetPoints();
  }

  String _buildDimensionsText() {
    if (_points.length < 2) return '';
    if (_selectedType == ObjectType.box && _points.length >= 4) {
      final w = _calcDistance(_points[0], _points[1]);
      final l = _calcDistance(_points[1], _points[2]);
      return 'Ширина: ${_fmt(w)} м\nДлина: ${_fmt(l)} м';
    } else if (_selectedType == ObjectType.cylinder && _points.length >= 2) {
      final r = _calcDistance(_points[0], _points[1]) / 2;
      return 'Радиус: ${_fmt(r)} м\nДиаметр: ${_fmt(r * 2)} м';
    }
    return '';
  }

  Future<void> _saveObject(String name, double height) async {
    double w = 0, l = 0;
    if (_selectedType == ObjectType.box && _points.length >= 4) {
      w = _calcDistance(_points[0], _points[1]);
      l = _calcDistance(_points[1], _points[2]);
    } else if (_selectedType == ObjectType.cylinder && _points.length >= 2) {
      w = _calcDistance(_points[0], _points[1]);
      l = w;
    }

    final centerX = _points.map((p) => p.x).reduce((a, b) => a + b) / _points.length;
    final centerY = _points.map((p) => p.y).reduce((a, b) => a + b) / _points.length;
    final centerZ = _points.map((p) => p.z).reduce((a, b) => a + b) / _points.length;

    await DBHelper.instance.insertObject(ScannedObject(
      projectId: widget.projectId,
      name: name.isNotEmpty ? name : 'Объект',
      type: _selectedType,
      width: w,
      length: l,
      height: height,
      posX: centerX,
      posY: centerY,
      posZ: centerZ,
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${name.isNotEmpty ? name : "Объект"}" сохранён'),
          backgroundColor: const Color(0xFF238636),
        ),
      );
    }
  }

  void _resetPoints() {
    setState(() {
      _points.clear();
      _lastDistance = null;
    });
    for (final anchor in _anchors) {
      arAnchorManager?.removeAnchor(anchor);
    }
    _anchors.clear();
  }

  String _fmt(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // Верхняя панель
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _glassButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _glassButton(
                    icon: _isScanning ? Icons.stop : Icons.play_arrow,
                    label: _isScanning ? 'Стоп' : 'Начать',
                    color: _isScanning ? Colors.red : const Color(0xFF238636),
                    onTap: () => setState(() {
                      _isScanning = !_isScanning;
                      if (!_isScanning) _resetPoints();
                    }),
                  ),
                ],
              ),
            ),
          ),

          // Прицел по центру
          if (_isScanning)
            const Center(
              child: Icon(Icons.add, color: Colors.white, size: 36, shadows: [
                Shadow(color: Colors.black, blurRadius: 4),
              ]),
            ),

          // Нижняя панель
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(190),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Тип объекта
                  Row(
                    children: [
                      _typeButton(ObjectType.box, Icons.crop_square, 'Бокс'),
                      const SizedBox(width: 10),
                      _typeButton(ObjectType.cylinder, Icons.circle_outlined, 'Цилиндр'),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Инструкция и индикатор точек
                  _buildStatus(),
                  const SizedBox(height: 12),

                  // Расстояние
                  if (_lastDistance != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF58A6FF).withAlpha(38),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF58A6FF).withAlpha(76)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.straighten, color: Color(0xFF58A6FF), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${_fmt(_lastDistance!)} м  (${(_lastDistance! * 100).toStringAsFixed(0)} см)',
                            style: const TextStyle(
                              color: Color(0xFF58A6FF),
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Кнопка сброса
                  if (_points.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _resetPoints,
                      icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
                      label: const Text('Сбросить точки', style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    final needed = _selectedType == ObjectType.box ? 4 : 2;
    final placed = _points.length;
    String msg;

    if (!_isScanning) {
      msg = 'Нажмите "Начать" для сканирования';
    } else if (placed == 0) {
      msg = _selectedType == ObjectType.box
          ? 'Наведите на пол/стол и тапните по углу 1'
          : 'Тапните по одному краю диаметра';
    } else if (placed < needed) {
      msg = _selectedType == ObjectType.box
          ? 'Тапните по углу ${placed + 1} из $needed'
          : 'Тапните по второму краю диаметра';
    } else {
      msg = '✅ Все точки поставлены!';
    }

    return Column(
      children: [
        Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(needed, (i) => Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < placed ? const Color(0xFF58A6FF) : Colors.white24,
              border: Border.all(color: i < placed ? const Color(0xFF58A6FF) : Colors.white24),
            ),
            child: i < placed ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
          )),
        ),
      ],
    );
  }

  Widget _typeButton(ObjectType type, IconData icon, String label) {
    final selected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedType = type;
          _resetPoints();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF58A6FF).withAlpha(51) : Colors.white.withAlpha(18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? const Color(0xFF58A6FF) : Colors.white24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? const Color(0xFF58A6FF) : Colors.white54, size: 18),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                color: selected ? const Color(0xFF58A6FF) : Colors.white54,
                fontWeight: FontWeight.w600,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassButton({required IconData icon, String? label, Color? color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withAlpha(38),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (color ?? Colors.white).withAlpha(76)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white, size: 20),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
