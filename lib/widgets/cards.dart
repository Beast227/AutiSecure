import 'package:flutter/material.dart';

class SimpleCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(
                    title!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: "merriweather",
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                if (title != null) SizedBox(height: 12),
                if (description != null)
                  Text(description!, textAlign: TextAlign.center),
                if (description != null) const SizedBox(height: 16),
                if (imageUrl != null)
                  Image.asset(
                    imageUrl!,
                    height: 200, // increase height here
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                if (imageUrl != null) const SizedBox(height: 16),
                if (buttonText != null)
                  ElevatedButton(
                    onPressed: onButtonPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: Text(
                      buttonText!,
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
