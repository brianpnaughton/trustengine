import 'dart:async';
import 'package:agui/models.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class WebSocketService {
  late IO.Socket socket;
  final _eventController = StreamController<Event>.broadcast();

  Stream<Event> get events => _eventController.stream;

  void connect() {
    socket = IO.io('http://localhost:8080', <String, dynamic>{
      'transports': ['websocket'],
    });

    socket.onConnect((_) {
      print('WebSocket connected successfully');
    });

    socket.onDisconnect((_) {
      print('WebSocket disconnected');
    });

    socket.onError((error) {
      print('WebSocket error: $error');
    });

    socket.on('agui_event', (data) {
      print('Received event data: $data');
      try {
        // Handle the raw JSON data and create appropriate events
        if (data is Map<String, dynamic>) {
          Event? event;

          switch (data['type']) {
            case 'TEXT_MESSAGE_START':
              event = TextMessageStartEvent(
                messageId: data['messageId'] ?? '',
                role: Role.assistant,
              );
              break;
            case 'TEXT_MESSAGE_CONTENT':
              event = TextMessageContentEvent(
                messageId: data['messageId'] ?? '',
                delta: data['delta'] ?? '',
              );
              break;
            case 'TEXT_MESSAGE_END':
              event = TextMessageEndEvent(messageId: data['messageId'] ?? '');
              break;
            default:
              // Try to parse using the original method for other events
              event = Event.fromJson(data);
          }

          if (event != null) {
            print('Created event: ${event.runtimeType}');
            _eventController.add(event);
          }
        }
      } catch (e) {
        print('Error parsing event: $e');
        print('Event data was: $data');
      }
    });
  }

  void sendEvent(Event event) {
    socket.emit('agui_event', event.toJson());
  }

  void disconnect() {
    socket.disconnect();
    _eventController.close();
  }
}
