import 'package:agui/widgets/chat_panel.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double? _chatPanelWidth;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    _chatPanelWidth ??= screenWidth / 3;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: _chatPanelWidth!, child: const ChatPanel()),
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _chatPanelWidth = (_chatPanelWidth! + details.delta.dx).clamp(
                  150,
                  screenWidth - 150,
                );
              });
            },
            child: const MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: VerticalDivider(width: 4, thickness: 1),
            ),
          ),
          const Expanded(
            child: Scaffold(body: Center(child: Text('Main Content'))),
          ),
        ],
      ),
    );
  }
}
