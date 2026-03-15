import 'package:flutter/material.dart';

import 'package:mishon_app/features/people/screens/people_overview_screen.dart';

class PeopleScreen extends StatelessWidget {
  final bool embeddedInNavigationShell;

  const PeopleScreen({super.key, this.embeddedInNavigationShell = false});

  @override
  Widget build(BuildContext context) {
    return PeopleOverviewScreen(
      embeddedInNavigationShell: embeddedInNavigationShell,
    );
  }
}
