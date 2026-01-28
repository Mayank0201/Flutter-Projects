// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MovieAdapter extends TypeAdapter<Movie> {
  @override
  final int typeId = 0;

  @override
  Movie read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Movie(
      title: fields[0] as String,
      year: fields[1] as String,
      imdbId: fields[2] as String,
      poster: fields[3] as String,
      plot: fields[4] as String,
      genre: fields[5] as String,
      director: fields[6] as String,
      actors: fields[7] as String,
      runtime: fields[8] as String,
      released: fields[9] as String,
      imdbRating: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Movie obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.year)
      ..writeByte(2)
      ..write(obj.imdbId)
      ..writeByte(3)
      ..write(obj.poster)
      ..writeByte(4)
      ..write(obj.plot)
      ..writeByte(5)
      ..write(obj.genre)
      ..writeByte(6)
      ..write(obj.director)
      ..writeByte(7)
      ..write(obj.actors)
      ..writeByte(8)
      ..write(obj.runtime)
      ..writeByte(9)
      ..write(obj.released)
      ..writeByte(10)
      ..write(obj.imdbRating);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MovieAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
