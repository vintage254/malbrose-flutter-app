import 'package:flutter/material.dart';

class ProgressBarWidget extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final String label;
  final bool showPercentage;
  final Color barColor;
  final double height;
  final double width;
  final double borderRadius;

  const ProgressBarWidget({
    super.key,
    required this.value,
    this.label = '',
    this.showPercentage = true,
    this.barColor = Colors.blue,
    this.height = 10.0,
    this.width = double.infinity,
    this.borderRadius = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value * 100).toStringAsFixed(1);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            showPercentage 
                ? '$label $percentage%' 
                : label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.0,
            ),
          ),
          const SizedBox(height: 8.0),
        ],
        
        SizedBox(
          width: width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: LinearProgressIndicator(
              value: value,
              minHeight: height,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        
        if (label.isEmpty && showPercentage) ...[
          const SizedBox(height: 4.0),
          Text(
            '$percentage%',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.0,
            ),
          ),
        ],
      ],
    );
  }
}

class AnimatedProgressBar extends StatefulWidget {
  final Stream<double> progressStream;
  final String label;
  final bool showPercentage;
  final Color barColor;
  final double height;
  final double width;

  const AnimatedProgressBar({
    super.key,
    required this.progressStream,
    this.label = '',
    this.showPercentage = true,
    this.barColor = Colors.blue,
    this.height = 10.0,
    this.width = double.infinity,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _currentValue = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    widget.progressStream.listen((newValue) {
      // Update the animation
      _animation = Tween<double>(
        begin: _currentValue,
        end: newValue,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
      );
      
      _currentValue = newValue;
      _animationController.forward(from: 0.0);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ProgressBarWidget(
          value: _animation.value,
          label: widget.label,
          showPercentage: widget.showPercentage,
          barColor: widget.barColor,
          height: widget.height,
          width: widget.width,
        );
      },
    );
  }
}
