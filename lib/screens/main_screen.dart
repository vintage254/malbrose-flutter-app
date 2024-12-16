import 'package:flutter/material.dart';
import 'package:my_flutter_app/widgets/dashboard_widget.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/widgets/right_panel_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<DashboardWidgetState> _dashboardKey = GlobalKey();

  void refreshDashboard() {
    _dashboardKey.currentState?.refreshProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: SideMenuWidget(onProductsUpdated: refreshDashboard),
            ),
            Expanded(
              flex: 8,
              child: DashboardWidget(dashboardKey: _dashboardKey),
            ),
            const Expanded(
              flex: 2,
              child: RightPanelWidget(),
            ),
          ],
        ),
      ),
    );
  }
}
