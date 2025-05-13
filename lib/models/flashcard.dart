import 'package:hive/hive.dart';
import 'dart:math' as math;

part 'flashcard.g.dart';

// Enum simple para la dificultad
enum Difficulty {
  easy,
  medium,
  hard
}

@HiveType(typeId: 1)
class Flashcard extends HiveObject {
  @HiveField(0)
  String question;

  @HiveField(1)
  String answer;
  
  // Propiedades que no se almacenan en Hive (no tienen @HiveField)
  Difficulty get difficulty => Difficulty.medium;
  List<String> get tags => [];
  int reviewCount = 0;
  int correctCount = 0;

  Flashcard({
    required this.question,
    required this.answer,
  });
  
  // Métodos para el modo de estudio
  bool isDueForReview() {
    return true; // Por defecto, todas las tarjetas están disponibles para revisar
  }
  
  // Método simple para actualizar el progreso de estudio
  void updateReviewSchedule(bool wasCorrect) {
    reviewCount++;
    if (wasCorrect) {
      correctCount++;
    }
  }
  
  // Porcentaje de acierto
  double get successRate {
    if (reviewCount == 0) return 0.0;
    return (correctCount / reviewCount) * 100;
  }
}
