// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_point.dart';

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
