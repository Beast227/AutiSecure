import 'package:flutter/material.dart';

class SimpleCard extends StatefulWidget {
  final String? title;
  final String? description;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final String? imageUrl;

  const SimpleCard({
    super.key,
    this.title,
    this.description,
    this.buttonText,
    this.onButtonPressed,
    this.imageUrl,
  });

  @override
  State<SimpleCard> createState() => _SimpleCardState();
}

class _SimpleCardState extends State<SimpleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _floatAnimation;

  bool isFloating = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2), // slow float
      vsync: this,
    ); // infinite up-down

    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, 0.02), // a little down
      end: const Offset(0, -0.02), // a little up
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFloating() {
    setState(() {
      if (isFloating) {
        _controller.stop();
        isFloating = false;
      } else {
        _controller.repeat(reverse: true);
        isFloating = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleFloating,
      child: SlideTransition(
        position:
            isFloating
                ? _floatAnimation
                : const AlwaysStoppedAnimation(Offset.zero),
        child: Card(
          elevation: 3,
          shadowColor: Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.title != null)
                  Text(
                    widget.title!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: "merriweather",
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                if (widget.title != null) SizedBox(height: 12),
                if (widget.description != null)
                  Text(widget.description!, textAlign: TextAlign.center),
                if (widget.description != null) const SizedBox(height: 16),
                if (widget.imageUrl != null)
                  Image.asset(
                    widget.imageUrl!,
                    height: 200, // increase height here
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                if (widget.imageUrl != null) const SizedBox(height: 16),
                if (widget.buttonText != null)
                  ElevatedButton(
                    onPressed: widget.onButtonPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: Text(
                      widget.buttonText!,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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
