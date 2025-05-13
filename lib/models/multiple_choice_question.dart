import 'package:hive/hive.dart';

part 'multiple_choice_question.g.dart';

@HiveType(typeId: 2)
class MultipleChoiceQuestion extends HiveObject {
  @HiveField(0)
  String question;

  @HiveField(1)
  List<String> options;

  @HiveField(2)
  String correctAnswer;

  MultipleChoiceQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
  });
}
