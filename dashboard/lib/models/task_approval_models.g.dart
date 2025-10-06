// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_approval_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskApprovalRequest _$TaskApprovalRequestFromJson(Map<String, dynamic> json) =>
    TaskApprovalRequest(
      type: json['type'] as String,
      message: json['message'] as String,
      tasks: (json['tasks'] as List<dynamic>)
          .map((e) => ApprovalTask.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$TaskApprovalRequestToJson(
  TaskApprovalRequest instance,
) => <String, dynamic>{
  'type': instance.type,
  'message': instance.message,
  'tasks': instance.tasks,
};

ApprovalTask _$ApprovalTaskFromJson(Map<String, dynamic> json) => ApprovalTask(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  priority: $enumDecode(_$TaskPriorityEnumMap, json['priority']),
  estimatedDuration: json['estimatedDuration'] as String?,
  risks: (json['risks'] as List<dynamic>?)?.map((e) => e as String).toList(),
);

Map<String, dynamic> _$ApprovalTaskToJson(ApprovalTask instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'priority': _$TaskPriorityEnumMap[instance.priority]!,
      'estimatedDuration': instance.estimatedDuration,
      'risks': instance.risks,
    };

const _$TaskPriorityEnumMap = {
  TaskPriority.low: 'low',
  TaskPriority.medium: 'medium',
  TaskPriority.high: 'high',
  TaskPriority.critical: 'critical',
};

TaskApprovalResponse _$TaskApprovalResponseFromJson(
  Map<String, dynamic> json,
) => TaskApprovalResponse(
  type: json['type'] as String,
  approvals: Map<String, bool>.from(json['approvals'] as Map),
  comment: json['comment'] as String?,
);

Map<String, dynamic> _$TaskApprovalResponseToJson(
  TaskApprovalResponse instance,
) => <String, dynamic>{
  'type': instance.type,
  'approvals': instance.approvals,
  'comment': instance.comment,
};
