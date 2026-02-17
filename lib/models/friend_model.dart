enum FriendStatus {
  accepted,
  pending,
}

extension FriendStatusX on FriendStatus {
  String get label {
    switch (this) {
      case FriendStatus.accepted:
        return 'Amigo';
      case FriendStatus.pending:
        return 'Pendiente';
    }
  }
}

class FriendModel {
  final String id;
  final String name;
  final String avatarKey;
  final FriendStatus status;

  const FriendModel({
    required this.id,
    required this.name,
    required this.avatarKey,
    required this.status,
  });

  FriendModel copyWith({
    String? name,
    String? avatarKey,
    FriendStatus? status,
  }) {
    return FriendModel(
      id: id,
      name: name ?? this.name,
      avatarKey: avatarKey ?? this.avatarKey,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'avatarKey': avatarKey,
        'status': status.name,
      };

  static FriendModel? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final avatarKey = json['avatarKey'];
    final statusRaw = json['status'];

    if (id is! String || id.trim().isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;

    FriendStatus status = FriendStatus.accepted;
    for (final v in FriendStatus.values) {
      if (v.name == statusRaw) {
        status = v;
        break;
      }
    }

    return FriendModel(
      id: id.trim(),
      name: name.trim(),
      avatarKey: avatarKey is String && avatarKey.trim().isNotEmpty ? avatarKey.trim() : name.trim(),
      status: status,
    );
  }
}
