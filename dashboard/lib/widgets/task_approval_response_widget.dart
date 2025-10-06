import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_approval_models.dart';
import '../app_state.dart';
import '../agUI/models.dart' as agui_models;

class TaskApprovalResponseWidget extends StatefulWidget {
  final String response;

  const TaskApprovalResponseWidget(this.response, {super.key});

  @override
  State<TaskApprovalResponseWidget> createState() =>
      _TaskApprovalResponseWidgetState();
}

class _TaskApprovalResponseWidgetState
    extends State<TaskApprovalResponseWidget> {
  late TaskApprovalRequest approvalRequest;
  Map<String, TaskApprovalStatus> taskStatuses = {};
  bool isSubmitting = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _parseApprovalRequest();
  }

  void _parseApprovalRequest() {
    try {
      // Extract JSON from response text
      String jsonString = widget.response.trim();
      if (jsonString.contains('{')) {
        jsonString = jsonString.substring(jsonString.indexOf('{'));
        if (jsonString.contains('}')) {
          jsonString = jsonString.substring(0, jsonString.lastIndexOf('}') + 1);
        }
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      approvalRequest = TaskApprovalRequest.fromJson(json);

      // Initialize all tasks as pending
      for (final task in approvalRequest.tasks) {
        taskStatuses[task.id] = TaskApprovalStatus.pending;
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to parse approval request: $e';
      });
    }
  }

  void _updateTaskStatus(String taskId, TaskApprovalStatus status) {
    setState(() {
      taskStatuses[taskId] = status;
    });
  }

  void _approveAll() {
    setState(() {
      for (final task in approvalRequest.tasks) {
        taskStatuses[task.id] = TaskApprovalStatus.approved;
      }
    });
  }

  void _rejectAll() {
    setState(() {
      for (final task in approvalRequest.tasks) {
        taskStatuses[task.id] = TaskApprovalStatus.rejected;
      }
    });
  }

  Future<void> _submitApprovals() async {
    setState(() {
      isSubmitting = true;
      errorMessage = null;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);

      // Create approval response
      final approvals = <String, bool>{};
      for (final entry in taskStatuses.entries) {
        approvals[entry.key] = entry.value == TaskApprovalStatus.approved;
      }

      final response = TaskApprovalResponse(
        type: 'task_approval_response',
        approvals: approvals,
      );

      // Send response through WebSocket
      final event = agui_models.CustomEvent(
        name: 'task_approval_response',
        value: response.toJson(),
      );

      appState.socketProvider.webSocketService.sendEvent(event);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task approvals submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to submit approvals: $e';
      });
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.critical:
        return Colors.purple;
    }
  }

  IconData _getStatusIcon(TaskApprovalStatus status) {
    switch (status) {
      case TaskApprovalStatus.pending:
        return Icons.help_outline;
      case TaskApprovalStatus.approved:
        return Icons.check_circle;
      case TaskApprovalStatus.rejected:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(TaskApprovalStatus status) {
    switch (status) {
      case TaskApprovalStatus.pending:
        return Colors.grey;
      case TaskApprovalStatus.approved:
        return Colors.green;
      case TaskApprovalStatus.rejected:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Error',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(errorMessage!),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.approval, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Task Approval Required',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              approvalRequest.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Bulk actions
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: isSubmitting ? null : _approveAll,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Approve All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isSubmitting ? null : _rejectAll,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Reject All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Task list
            ...approvalRequest.tasks.map((task) => _buildTaskCard(task)),

            const SizedBox(height: 16),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : _submitApprovals,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  isSubmitting ? 'Submitting...' : 'Submit Approvals',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(ApprovalTask task) {
    final status = taskStatuses[task.id] ?? TaskApprovalStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task header
            Row(
              children: [
                // Priority indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(
                      task.priority,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getPriorityColor(task.priority),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    task.priority.displayName,
                    style: TextStyle(
                      color: _getPriorityColor(task.priority),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Status indicator
                Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Task description
            Text(
              task.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            // Additional info
            if (task.estimatedDuration != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Estimated duration: ${task.estimatedDuration}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],

            // Risks
            if (task.risks != null && task.risks!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Risks:',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        ...task.risks!.map(
                          (risk) => Text(
                            '• $risk',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.orange[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Approval buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () => _updateTaskStatus(
                          task.id,
                          TaskApprovalStatus.rejected,
                        ),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: TextButton.styleFrom(
                    foregroundColor: status == TaskApprovalStatus.rejected
                        ? Colors.red
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () => _updateTaskStatus(
                          task.id,
                          TaskApprovalStatus.approved,
                        ),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == TaskApprovalStatus.approved
                        ? Colors.green
                        : null,
                    foregroundColor: status == TaskApprovalStatus.approved
                        ? Colors.white
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
