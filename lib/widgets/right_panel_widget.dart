import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';

class RightPanelWidget extends StatelessWidget {
  const RightPanelWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color.fromARGB(255, 230, 227, 220).withAlpha(179),
            const Color.fromARGB(255, 230, 192, 80),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding / 2),
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  primaryColor,
                  secondaryColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'Financial Overview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: defaultPadding),
            _buildSection('Debtors', Icons.arrow_downward, Colors.red),
            const SizedBox(height: defaultPadding),
            _buildSection('Creditors', Icons.arrow_upward, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(defaultPadding / 2),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: defaultPadding / 2),
          const Text(
            'No records to display',
            style: TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
