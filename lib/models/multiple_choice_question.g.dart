// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'multiple_choice_question.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MultipleChoiceQuestionAdapter
    extends TypeAdapter<MultipleChoiceQuestion> {
  @override
  final int typeId = 2;

  @override
  MultipleChoiceQuestion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MultipleChoiceQuestion(
      question: fields[0] as String,
      options: (fields[1] as List).cast<String>(),
      correctAnswer: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MultipleChoiceQuestion obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.question)
      ..writeByte(1)
      ..write(obj.options)
      ..writeByte(2)
      ..write(obj.correctAnswer);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultipleChoiceQuestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
