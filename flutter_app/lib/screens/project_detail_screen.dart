import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/models.dart';
import 'ar_screen.dart';
import 'viewer_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  List<ScannedObject> _objects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadObjects();
  }

  Future<void> _loadObjects() async {
    final objs = await DBHelper.instance.getObjects(widget.project.id!);
    if (mounted) {
      setState(() {
        _objects = objs;
        _loading = false;
      });
    }
  }

  Future<void> _openAR() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ARScreen(projectId: widget.project.id!),
      ),
    );
    _loadObjects();
  }

  Future<void> _openViewer() async {
    if (_objects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала отсканируйте хотя бы один объект')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewerScreen(objects: _objects, projectName: widget.project.name),
      ),
    );
  }

  Future<void> _deleteObject(ScannedObject obj) async {
    await DBHelper.instance.deleteObject(obj.id!);
    _loadObjects();
  }

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.project.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            if (widget.project.description.isNotEmpty)
              Text(widget.project.description, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Кнопки действий
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openAR,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text('AR Сканирование', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openViewer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F6FEB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.view_in_ar, color: Colors.white),
                    label: const Text('3D Область', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),

          // Заголовок списка
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Объекты', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF58A6FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_objects.length}', style: const TextStyle(color: Color(0xFF58A6FF), fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Список объектов
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)))
                : _objects.isEmpty
                    ? _buildEmptyObjects()
                    : _buildObjectList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyObjects() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 64, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 12),
          const Text('Объекты не добавлены', style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Нажмите "AR Сканирование"', style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildObjectList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _objects.length,
      itemBuilder: (ctx, i) {
        final obj = _objects[i];
        final isBox = obj.type == ObjectType.box;
        return Card(
          color: const Color(0xFF161B22),
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isBox ? const Color(0xFF3FB950) : const Color(0xFFF78166)).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isBox ? Icons.crop_square : Icons.circle_outlined,
                color: isBox ? const Color(0xFF3FB950) : const Color(0xFFF78166),
              ),
            ),
            title: Text(obj.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(obj.typeLabel, style: TextStyle(color: isBox ? const Color(0xFF3FB950) : const Color(0xFFF78166), fontSize: 11)),
                Text(obj.dimensionsLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteObject(obj),
            ),
          ),
        );
      },
    );
  }
}
