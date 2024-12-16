import 'package:flutter/material.dart';
import 'package:my_flutter_app/widgets/dashboard_widget.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/widgets/right_panel_widget.dart';
import 'package:my_flutter_app/widgets/order_summary_widget.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<DashboardWidgetState> _dashboardKey = GlobalKey();

  void _handleProductsUpdated() {
    _dashboardKey.currentState?.refreshProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              flex: 1,
              child: SideMenuWidget(),
            ),
            Expanded(
              flex: 3,
              child: DashboardWidget(
                key: _dashboardKey,
              ),
            ),
            const Expanded(
              flex: 2,
              child: OrderSummaryWidget(),
            ),
          ],
        ),
      ),
    );
  }
}
