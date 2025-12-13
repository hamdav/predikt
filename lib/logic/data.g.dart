// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DataPointAdapter extends TypeAdapter<DataPoint> {
  @override
  final int typeId = 1;

  @override
  DataPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DataPoint(
      value: fields[0] as double,
      timestamp: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DataPoint obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.value)
      ..writeByte(1)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataPointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DataSetAdapter extends TypeAdapter<DataSet> {
  @override
  final int typeId = 2;

  @override
  DataSet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DataSet(
      fitFunc: fields[0] as FitFunction,
      points: (fields[1] as List).cast<DataPoint>(),
      target: fields[2] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, DataSet obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.fitFunc)
      ..writeByte(1)
      ..write(obj.points)
      ..writeByte(2)
      ..write(obj.target);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataSetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FitFunctionAdapter extends TypeAdapter<FitFunction> {
  @override
  final int typeId = 3;

  @override
  FitFunction read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FitFunction.linear;
      case 1:
        return FitFunction.exponential;
      default:
        return FitFunction.linear;
    }
  }

  @override
  void write(BinaryWriter writer, FitFunction obj) {
    switch (obj) {
      case FitFunction.linear:
        writer.writeByte(0);
        break;
      case FitFunction.exponential:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitFunctionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
