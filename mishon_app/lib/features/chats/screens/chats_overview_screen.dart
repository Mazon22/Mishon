import 'package:flutter/material.dart';

import 'package:mishon_app/features/chats/screens/chats_screen.dart';

class ChatsOverviewScreen extends StatelessWidget {
  final bool embeddedInNavigationShell;

  const ChatsOverviewScreen({
    super.key,
    this.embeddedInNavigationShell = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChatsScreen(embeddedInNavigationShell: embeddedInNavigationShell);
  }
}
