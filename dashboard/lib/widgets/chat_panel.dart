import 'package:agui/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/task_approval_models.dart';
import 'task_approval_response_widget.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return LlmChatView(
      provider: appState.socketProvider,
      responseBuilder: (context, response) {
        // Check if this is a task approval request
        if (TaskApprovalRequest.isTaskApprovalRequest(response)) {
          return TaskApprovalResponseWidget(response);
        }

        // For all other responses, return default markdown rendering
        return MarkdownBody(data: response);
      },
    );
  }
}
