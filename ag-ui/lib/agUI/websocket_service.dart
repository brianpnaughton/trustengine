import 'dart:async';
import 'package:agui/agUI/models.dart';
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
          // Use the proper Event.fromJson method which handles all event types
          Event event = Event.fromJson(data);
          print('Created event: ${event.runtimeType}');
          _eventController.add(event);
        }
      } catch (e) {
        print('Error parsing event: $e');
        print('Event data was: $data');
        // Fallback: try manual parsing for debugging
        if (data is Map<String, dynamic>) {
          print('Event type: ${data['type']}');
          print('Available fields: ${data.keys.toList()}');
        }
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
