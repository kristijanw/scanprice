// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductInfoAdapter extends TypeAdapter<ProductInfo> {
  @override
  final int typeId = 0;

  @override
  ProductInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductInfo(
      title: fields[0] as String,
      price: fields[1] as double,
      priceDiscount: fields[2] as double,
      card: fields[3] as bool,
      imagePath: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductInfo obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.price)
      ..writeByte(2)
      ..write(obj.priceDiscount)
      ..writeByte(3)
      ..write(obj.card)
      ..writeByte(4)
      ..write(obj.imagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
