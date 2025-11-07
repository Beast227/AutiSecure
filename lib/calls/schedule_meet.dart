import 'package:flutter/material.dart';

class ScheduleMeet extends StatefulWidget {
  final String recieverName;
  const ScheduleMeet({super.key, required this.recieverName});

  @override
  State<ScheduleMeet> createState() => _ScheduleMeetState();
}

class _ScheduleMeetState extends State<ScheduleMeet> {
  DateTime? selectedDateTime;

  void _pickDateTime() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => selectedDateTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Schedule Meeting with ${widget.recieverName}"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: _pickDateTime,
            child: Text("Pick Meeting Date"),
          ),
          SizedBox(height: 10),
          Text(
            selectedDateTime == null
                ? "no date selected"
                : selectedDateTime.toString(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Meeting Scheduled")));
          },
          child: Text("Scheduled"),
        ),
      ],
    );
  }
}
