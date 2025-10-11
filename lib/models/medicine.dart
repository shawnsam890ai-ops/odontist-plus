class Medicine {
  final String id;
  String name;
  double storeAmount; // purchase price per strip
  double mrp; // selling price per strip
  int stripsAvailable;

  Medicine({required this.id, required this.name, required this.storeAmount, required this.mrp, required this.stripsAvailable});

  double get profitPerStrip => mrp - storeAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'storeAmount': storeAmount,
        'mrp': mrp,
        'stripsAvailable': stripsAvailable,
      };

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
        id: j['id'] as String,
        name: j['name'] as String,
        storeAmount: (j['storeAmount'] as num).toDouble(),
        mrp: (j['mrp'] as num).toDouble(),
        stripsAvailable: j['stripsAvailable'] as int,
      );
}