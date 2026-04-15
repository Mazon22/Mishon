class ReportItemModel {
  final int id;
  final String source;
  final String targetType;
  final int targetId;
  final int? targetUserId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final int? assignedModeratorUserId;
  final String? assignedModeratorUsername;

  const ReportItemModel({
    required this.id,
    required this.source,
    required this.targetType,
    required this.targetId,
    required this.targetUserId,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.assignedModeratorUserId,
    required this.assignedModeratorUsername,
  });

  factory ReportItemModel.fromJson(Map<String, dynamic> json) {
    return ReportItemModel(
      id: json['id'] as int,
      source: json['source'] as String,
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as int,
      targetUserId: json['targetUserId'] as int?,
      reason: json['reason'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      assignedModeratorUserId: json['assignedModeratorUserId'] as int?,
      assignedModeratorUsername: json['assignedModeratorUsername'] as String?,
    );
  }
}

class ReportDetailModel {
  final int id;
  final String source;
  final String targetType;
  final int targetId;
  final int? targetUserId;
  final String reason;
  final String? customNote;
  final String status;
  final int? reporterUserId;
  final String? reporterUsername;
  final int? assignedModeratorUserId;
  final String? assignedModeratorUsername;
  final String resolution;
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  const ReportDetailModel({
    required this.id,
    required this.source,
    required this.targetType,
    required this.targetId,
    required this.targetUserId,
    required this.reason,
    required this.customNote,
    required this.status,
    required this.reporterUserId,
    required this.reporterUsername,
    required this.assignedModeratorUserId,
    required this.assignedModeratorUsername,
    required this.resolution,
    required this.resolutionNote,
    required this.createdAt,
    required this.updatedAt,
    required this.resolvedAt,
  });

  factory ReportDetailModel.fromJson(Map<String, dynamic> json) {
    return ReportDetailModel(
      id: json['id'] as int,
      source: json['source'] as String,
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as int,
      targetUserId: json['targetUserId'] as int?,
      reason: json['reason'] as String,
      customNote: json['customNote'] as String?,
      status: json['status'] as String,
      reporterUserId: json['reporterUserId'] as int?,
      reporterUsername: json['reporterUsername'] as String?,
      assignedModeratorUserId: json['assignedModeratorUserId'] as int?,
      assignedModeratorUsername: json['assignedModeratorUsername'] as String?,
      resolution: json['resolution'] as String? ?? 'None',
      resolutionNote: json['resolutionNote'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      resolvedAt:
          json['resolvedAt'] != null
              ? DateTime.parse(json['resolvedAt'] as String)
              : null,
    );
  }
}

class ModerationActionModel {
  final int id;
  final int actorUserId;
  final String actorUsername;
  final int? targetUserId;
  final String actionType;
  final String? targetType;
  final int? targetId;
  final int? reportId;
  final String? note;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const ModerationActionModel({
    required this.id,
    required this.actorUserId,
    required this.actorUsername,
    required this.targetUserId,
    required this.actionType,
    required this.targetType,
    required this.targetId,
    required this.reportId,
    required this.note,
    required this.createdAt,
    required this.expiresAt,
  });

  factory ModerationActionModel.fromJson(Map<String, dynamic> json) {
    return ModerationActionModel(
      id: json['id'] as int,
      actorUserId: json['actorUserId'] as int,
      actorUsername: json['actorUsername'] as String,
      targetUserId: json['targetUserId'] as int?,
      actionType: json['actionType'] as String,
      targetType: json['targetType'] as String?,
      targetId: json['targetId'] as int?,
      reportId: json['reportId'] as int?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt:
          json['expiresAt'] != null
              ? DateTime.parse(json['expiresAt'] as String)
              : null,
    );
  }
}
