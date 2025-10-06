import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'task_approval_models.g.dart';

@JsonSerializable()
class TaskApprovalRequest {
  final String type;
  final String message;
  final List<ApprovalTask> tasks;

  TaskApprovalRequest({
    required this.type,
    required this.message,
    required this.tasks,
  });

  factory TaskApprovalRequest.fromJson(Map<String, dynamic> json) =>
      _$TaskApprovalRequestFromJson(json);
  Map<String, dynamic> toJson() => _$TaskApprovalRequestToJson(this);

  static bool isTaskApprovalRequest(String responseText) {
    try {
      // Extract JSON from response text
      String jsonString = responseText.trim();
      if (jsonString.contains('{')) {
        jsonString = jsonString.substring(jsonString.indexOf('{'));
        if (jsonString.contains('}')) {
          jsonString = jsonString.substring(0, jsonString.lastIndexOf('}') + 1);
        }
      }

      // Try to parse as JSON
      final json = Map<String, dynamic>.from(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
      return json['type'] == 'task_approval' && json.containsKey('tasks');
    } catch (e) {
      return false;
    }
  }
}

@JsonSerializable()
class ApprovalTask {
  final String id;
  final String title;
  final String description;
  final TaskPriority priority;
  final String? estimatedDuration;
  final List<String>? risks;

  ApprovalTask({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    this.estimatedDuration,
    this.risks,
  });

  factory ApprovalTask.fromJson(Map<String, dynamic> json) =>
      _$ApprovalTaskFromJson(json);
  Map<String, dynamic> toJson() => _$ApprovalTaskToJson(this);
}

enum TaskPriority {
  @JsonValue('low')
  low,
  @JsonValue('medium')
  medium,
  @JsonValue('high')
  high,
  @JsonValue('critical')
  critical,
}

extension TaskPriorityExtension on TaskPriority {
  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.critical:
        return 'Critical';
    }
  }

  int get sortOrder {
    switch (this) {
      case TaskPriority.low:
        return 1;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.high:
        return 3;
      case TaskPriority.critical:
        return 4;
    }
  }
}

@JsonSerializable()
class TaskApprovalResponse {
  final String type;
  final Map<String, bool> approvals; // task_id -> approved
  final String? comment;

  TaskApprovalResponse({
    required this.type,
    required this.approvals,
    this.comment,
  });

  factory TaskApprovalResponse.fromJson(Map<String, dynamic> json) =>
      _$TaskApprovalResponseFromJson(json);
  Map<String, dynamic> toJson() => _$TaskApprovalResponseToJson(this);
}

enum TaskApprovalStatus { pending, approved, rejected }
