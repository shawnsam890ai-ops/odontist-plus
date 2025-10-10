import 'package:uuid/uuid.dart';

class LabProduct {
  final String id;
  final String name;
  final double rate;

  LabProduct({String? id, required this.name, required this.rate}) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rate': rate,
      };

  factory LabProduct.fromJson(Map<String, dynamic> j) => LabProduct(
        id: j['id'] as String?,
        name: j['name'] as String,
        rate: (j['rate'] as num).toDouble(),
      );
}

class LabVendor {
  final String id;
  String name;
  String address;
  final List<LabProduct> products;

  LabVendor({String? id, required this.name, required this.address, List<LabProduct>? products})
      : id = id ?? const Uuid().v4(),
        products = products ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'products': products.map((e) => e.toJson()).toList(),
      };

  factory LabVendor.fromJson(Map<String, dynamic> j) => LabVendor(
        id: j['id'] as String?,
        name: j['name'] as String,
        address: j['address'] as String,
        products: (j['products'] as List<dynamic>? ?? []).map((e) => LabProduct.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
