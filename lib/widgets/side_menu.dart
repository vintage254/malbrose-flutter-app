import 'package:flutter/material.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Wrap SideMenuWidget in a Drawer widget to make it usable as a drawer
    return Drawer(
      child: const SideMenuWidget(),
    );
  }
} 