import 'package:flutter/material.dart';

class AnimatedCartCard extends StatefulWidget {
  final int itemCount;
  final double total;
  final VoidCallback onTap;

  const AnimatedCartCard({super.key, required this.itemCount, required this.total, required this.onTap});

  @override
  State<AnimatedCartCard> createState() => AnimatedCartCardState();
}

class AnimatedCartCardState extends State<AnimatedCartCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Card(
          margin: const EdgeInsets.only(top: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
          color: Colors.deepPurple.shade100,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_cart, color: Colors.deepPurple),
                const SizedBox(width: 10),
                Text('${widget.itemCount} proizvoda • ${widget.total.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
