enum ContactStatus {
  accepted,
  pending,
}

extension ContactStatusX on ContactStatus {
  String get label {
    switch (this) {
      case ContactStatus.accepted:
        return 'Amigo';
      case ContactStatus.pending:
        return 'Pendiente';
    }
  }
}

class ContactModel {
  final String id;
  final String name;
  final String tag; // @usuario123
  final String avatarKey;
  final ContactStatus status;

  // Special contact behavior
  final bool isCoach;
  final bool requiresPremium;

  const ContactModel({
    required this.id,
    required this.name,
    required this.tag,
    required this.avatarKey,
    required this.status,
    required this.isCoach,
    required this.requiresPremium,
  });

  ContactModel copyWith({
    String? name,
    String? tag,
    String? avatarKey,
    ContactStatus? status,
    bool? isCoach,
    bool? requiresPremium,
  }) {
    return ContactModel(
      id: id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      avatarKey: avatarKey ?? this.avatarKey,
      status: status ?? this.status,
      isCoach: isCoach ?? this.isCoach,
      requiresPremium: requiresPremium ?? this.requiresPremium,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'tag': tag,
        'avatarKey': avatarKey,
        'status': status.name,
        'isCoach': isCoach,
        'requiresPremium': requiresPremium,
      };

  static ContactModel? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final tag = json['tag'];

    if (id is! String || id.trim().isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    if (tag is! String || tag.trim().isEmpty) return null;

    ContactStatus status = ContactStatus.accepted;
    final statusRaw = json['status'];
    for (final v in ContactStatus.values) {
      if (v.name == statusRaw) {
        status = v;
        break;
      }
    }

    final avatarKey = json['avatarKey'];

    return ContactModel(
      id: id.trim(),
      name: name.trim(),
      tag: tag.trim(),
      avatarKey: avatarKey is String && avatarKey.trim().isNotEmpty ? avatarKey.trim() : name.trim(),
      status: status,
      isCoach: json['isCoach'] is bool ? json['isCoach'] as bool : false,
      requiresPremium: json['requiresPremium'] is bool ? json['requiresPremium'] as bool : false,
    );
  }
}
