import 'package:flutter/material.dart';
import 'package:my_flutter_app/widgets/dashboard_widget.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/widgets/right_panel_widget.dart';
import 'package:my_flutter_app/widgets/order_summary_widget.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<DashboardWidgetState> _dashboardKey = GlobalKey();
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    // Initial load of stats
    OrderService.instance.refreshStats();
    _setupMidnightTimer();
  }

  void _setupMidnightTimer() {
    _midnightTimer?.cancel();
    
    // Calculate time until next midnight
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);

    // Set timer for midnight
    _midnightTimer = Timer(timeUntilMidnight, () {
      if (mounted) {
        OrderService.instance.refreshStats();
        _dashboardKey.currentState?.refreshProducts();
        // Reset the timer for the next day
        _setupMidnightTimer();
      }
    });
  }

  void _handleProductsUpdated() {
    _dashboardKey.currentState?.refreshProducts();
    // Refresh stats after product updates
    OrderService.instance.refreshStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              flex: 2,
              child: SideMenuWidget(),
            ),
            Expanded(
              flex: 5,
              child: DashboardWidget(
                key: _dashboardKey,
              ),
            ),
            const Expanded(
              flex: 3,
              child: OrderSummaryWidget(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    // Clean up any resources
    super.dispose();
  }
}
