// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutAdapter extends TypeAdapter<Workout> {
  @override
  final int typeId = 1;

  @override
  Workout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Workout(
      id: fields[0] as String,
      startedAt: fields[1] as DateTime,
      endedAt: fields[2] as DateTime?,
      status: fields[3] as WorkoutStatus,
      notes: fields[4] as String?,
      exercises: (fields[5] as List).cast<Exercise>(),
    );
  }

  @override
  void write(BinaryWriter writer, Workout obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startedAt)
      ..writeByte(2)
      ..write(obj.endedAt)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.exercises);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutStatusAdapter extends TypeAdapter<WorkoutStatus> {
  @override
  final int typeId = 3;

  @override
  WorkoutStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return WorkoutStatus.notStarted;
      case 1:
        return WorkoutStatus.inProgress;
      case 2:
        return WorkoutStatus.completed;
      case 3:
        return WorkoutStatus.paused;
      default:
        return WorkoutStatus.notStarted;
    }
  }

  @override
  void write(BinaryWriter writer, WorkoutStatus obj) {
    switch (obj) {
      case WorkoutStatus.notStarted:
        writer.writeByte(0);
        break;
      case WorkoutStatus.inProgress:
        writer.writeByte(1);
        break;
      case WorkoutStatus.completed:
        writer.writeByte(2);
        break;
      case WorkoutStatus.paused:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
