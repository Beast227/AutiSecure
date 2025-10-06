class Appointment {
  final String id;
  final String userId;
  final String userName;
  final String doctorId;
  final String doctorName;
  final String time;
  final String status;

  Appointment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.doctorId,
    required this.doctorName,
    required this.time,
    required this.status,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['_id']?.toString() ?? '',
      userId:
          json['user'] is Map ? json['user']['_id'] ?? '' : json['user'] ?? '',
      userName:
          json['user'] is Map ? json['user']['name'] ?? 'Unknown' : 'Unknown',
      doctorId:
          json['doctor'] is Map
              ? json['doctor']['_id'] ?? ''
              : json['doctor'] ?? '',
      doctorName:
          json['doctor'] is Map
              ? json['doctor']['name'] ?? 'Unknown'
              : 'Unknown',
      time: json['time'] ?? '',
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'userName': userName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'time': time,
      'status': status,
    };
  }
}
