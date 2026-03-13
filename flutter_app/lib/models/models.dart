class Project {
  final int? id;
  final String name;
  final String description;
  final DateTime createdAt;

  Project({
    this.id,
    required this.name,
    this.description = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }

  Project copyWith({int? id, String? name, String? description}) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}

enum ObjectType { box, cylinder }

class ScannedObject {
  final int? id;
  final int projectId;
  final String name;
  final ObjectType type;
  final double width;
  final double length;
  final double height;
  final double posX;
  final double posY;
  final double posZ;
  final DateTime createdAt;

  ScannedObject({
    this.id,
    required this.projectId,
    required this.name,
    required this.type,
    required this.width,
    required this.length,
    required this.height,
    this.posX = 0,
    this.posY = 0,
    this.posZ = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get typeLabel => type == ObjectType.box ? 'Параллелепипед' : 'Цилиндр';

  String get dimensionsLabel {
    if (type == ObjectType.box) {
      return '${_fmt(width)}м × ${_fmt(length)}м × ${_fmt(height)}м';
    } else {
      return 'R=${_fmt(width / 2)}м, h=${_fmt(height)}м';
    }
  }

  String _fmt(double v) => v.toStringAsFixed(2);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'type': type.index,
      'width': width,
      'length': length,
      'height': height,
      'pos_x': posX,
      'pos_y': posY,
      'pos_z': posZ,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ScannedObject.fromMap(Map<String, dynamic> map) {
    return ScannedObject(
      id: map['id'],
      projectId: map['project_id'],
      name: map['name'],
      type: ObjectType.values[map['type']],
      width: map['width'],
      length: map['length'],
      height: map['height'],
      posX: map['pos_x'] ?? 0,
      posY: map['pos_y'] ?? 0,
      posZ: map['pos_z'] ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
}

class Measurement {
  final String label;
  final double distanceMeters;

  Measurement({required this.label, required this.distanceMeters});

  String get formatted => '${distanceMeters.toStringAsFixed(2)} м  (${(distanceMeters * 100).toStringAsFixed(0)} см)';
}
