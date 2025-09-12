class QuestionModel {
  final String question;

  QuestionModel({required this.question});

  factory QuestionModel.fromJson(String json) {
    return QuestionModel(question: json);
  }
}