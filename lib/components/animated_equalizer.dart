import 'package:flutter/material.dart';

class AnimatedEqualizer extends StatefulWidget {
  final Color color;
  final double size;
  final bool isPlaying;

  const AnimatedEqualizer({
    super.key,
    required this.color,
    this.size = 16.0,
    required this.isPlaying,
});

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = widget.isPlaying ? _controller.value : 0;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(0.4 + (0.6 * val)),
              _buildBar(1.0 - (0.7 * val)),
              _buildBar(0.3 + (0.7 * val)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double heightFactor) {
    return Container(
      width: widget.size * 0.2,
      height: widget.size * heightFactor.clamp(0.2, 1.0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2.0),
      ),
    );
  }
}