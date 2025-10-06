import 'dart:async';

import 'package:agui/agUI/models.dart' as models;
import 'package:agui/agUI/websocket_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:uuid/uuid.dart';

class SocketProvider with ChangeNotifier implements LlmProvider {
  final WebSocketService webSocketService;
  final Uuid uuid = const Uuid();
  List<ChatMessage> _history = [];

  SocketProvider({required this.webSocketService});

  @override
  List<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> newHistory) {
    _history = newHistory.toList();
    notifyListeners();
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment>? attachments,
  }) {
    final controller = StreamController<String>();
    final messageId = uuid.v4();
    final responseCompleter = Completer<void>();

    // Add user message to history
    final userMessage = ChatMessage(
      origin: MessageOrigin.user,
      text: prompt,
      attachments: attachments?.toList() ?? [],
    );
    _history.add(userMessage);

    // Create empty LLM message for streaming
    final llmMessage = ChatMessage.llm();
    _history.add(llmMessage);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    // Create an ag-ui CustomEvent with a UserMessage.
    final event = models.CustomEvent(
      name: 'user_message',
      value: models.UserMessage(id: messageId, content: prompt).toJson(),
    );

    // Listen for events from the WebSocket service.
    final subscription = webSocketService.events.listen(
      (event) {
        print('SocketProvider received event: ${event.runtimeType}');
        if (event is models.TextMessageStartEvent) {
          // Backend started sending response
          print('Starting message response');
        } else if (event is models.TextMessageContentEvent) {
          // The backend is sending a content delta.
          print('Received content delta: ${event.delta}');
          // Append delta to the LLM message in history
          llmMessage.append(event.delta);
          // Yield the delta for the stream
          controller.add(event.delta);
          // Notify listeners so UI updates with the new text
          notifyListeners();
        } else if (event is models.TextMessageEndEvent) {
          // The backend has finished sending the response.
          print('Ending message response. Full response: ${llmMessage.text}');
          responseCompleter.complete();
        }
      },
      onError: (error) {
        controller.addError(error);
        responseCompleter.complete();
      },
    );

    // When the stream is closed, cancel the subscription.
    controller.onCancel = () {
      subscription.cancel();
      if (!responseCompleter.isCompleted) {
        responseCompleter.complete();
      }
    };

    // Send the user message to the backend.
    try {
      print('Sending event: ${event.toJson()}');
      webSocketService.sendEvent(event);
    } catch (error) {
      print('Error sending event: $error');
      controller.addError(error);
      responseCompleter.complete();
    }

    // Close the stream when the response is complete.
    responseCompleter.future.then((_) {
      controller.close();
      subscription.cancel();
    });

    return controller.stream;
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment>? attachments,
  }) {
    return generateStream(prompt, attachments: attachments);
  }
}
