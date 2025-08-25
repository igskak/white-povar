import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  final String message;
  final bool showProgress;
  final double? progress;

  const LoadingOverlay({
    super.key,
    required this.message,
    this.showProgress = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showProgress && progress != null)
                  CircularProgressIndicator(value: progress)
                else
                  const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (showProgress && progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${(progress! * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class IngredientLoadingAnimation extends StatefulWidget {
  final String message;

  const IngredientLoadingAnimation({
    super.key,
    required this.message,
  });

  @override
  State<IngredientLoadingAnimation> createState() => _IngredientLoadingAnimationState();
}

class _IngredientLoadingAnimationState extends State<IngredientLoadingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final List<IconData> _ingredientIcons = [
    Icons.local_pizza,
    Icons.restaurant,
    Icons.cake,
    Icons.coffee,
    Icons.lunch_dining,
    Icons.breakfast_dining,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 80,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _ingredientIcons.asMap().entries.map((entry) {
                          final index = entry.key;
                          final icon = entry.value;
                          final delay = index * 0.2;
                          final animationValue = (_animation.value - delay).clamp(0.0, 1.0);
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Transform.scale(
                              scale: 0.8 + (0.4 * animationValue),
                              child: Opacity(
                                opacity: 0.3 + (0.7 * animationValue),
                                child: Icon(
                                  icon,
                                  size: 24,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.message,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take a few seconds...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
