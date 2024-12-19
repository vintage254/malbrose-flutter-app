import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/widgets/dashboard_widget.dart';
import 'package:my_flutter_app/widgets/order_summary_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(flex: 1, child: SideMenuWidget()),
          const Expanded(flex: 3, child: DashboardWidget()),
          const Expanded(flex: 1, child: OrderSummaryWidget()),
        ],
      ),
    );
  }
} 