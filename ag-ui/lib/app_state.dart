import 'package:agui/socket_provider.dart';
import 'package:agui/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AppState extends ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  late final SocketProvider _socketProvider;

  AppState() {
    _socketProvider = SocketProvider(webSocketService: _webSocketService);
  }

  WebSocketService get webSocketService => _webSocketService;
  SocketProvider get socketProvider => _socketProvider;

  void connect() {
    _webSocketService.connect();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void disconnect() {
    _webSocketService.disconnect();
  }
}
