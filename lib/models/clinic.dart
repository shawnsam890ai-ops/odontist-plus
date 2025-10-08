import 'package:uuid/uuid.dart';

class Clinic {
  final String id;
  final String name;
  final String? address;

  Clinic({String? id, required this.name, this.address}) : id = id ?? const Uuid().v4();
}
