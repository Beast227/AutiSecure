class Appointment {
  final String id;
  final String patientId;
  final String doctorId;
  final String startDate;
  final String endDate;
  final String startTime;
  final String endTime;
  final String description;
  final String status;

  Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.description,
    required this.status,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['_id'] ?? '',
      patientId: json['patientId'] ?? '',
      doctorId: json['doctorId'] ?? '',
      startDate: json['appointmentStartDate'] ?? '',
      endDate: json['appointmentEndDate'] ?? '',
      startTime: json['appointmentStartTime'] ?? '',
      endTime: json['appointmentEndTime'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? '',
    );
  }
}
