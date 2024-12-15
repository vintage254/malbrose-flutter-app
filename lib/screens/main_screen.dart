import 'package:flutter/material.dart';
import 'package:my_flutter_app/widgets/dashboard_widget.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/widgets/right_panel_widget.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
      child: Row(children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            child: SideMenuWidget(),
          ),
        ),
        Expanded(flex: 8, child: DashboardWidget()),
        Expanded(
          flex: 2,
          child: RightPanelWidget(),
        ),
      ]),
    ));
  }
}
