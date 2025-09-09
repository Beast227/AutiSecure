import 'package:flutter/material.dart';

class QuestionCard extends StatelessWidget {
  final String question;
  final List<String> options;
  final String? selectedOption;
  final Function(String?) onChanged;

  const QuestionCard({
    super.key,
    required this.question,
    required this.options,
    required this.selectedOption,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            Column(
              children:
                  options.map((option) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: RadioListTile<String>(
                        title: Text(
                          option,
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                        value: option,
                        groupValue: selectedOption,
                        onChanged: onChanged,
                        activeColor: Colors.brown,
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
