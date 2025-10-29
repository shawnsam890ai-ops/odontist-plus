class Medicine {
  final String id;
  String name;
  double storeAmount; // purchase price per strip
  double mrp; // selling price per strip
  int stripsAvailable;
  int unitsPerStrip; // tablets/ml per strip (for accurate profit calc)
  int freeStrips; // free strips from supplier (100% profit)
  int looseTabs; // loose tablets cut from strips

  Medicine({
    required this.id,
    required this.name,
    required this.storeAmount,
    required this.mrp,
    required this.stripsAvailable,
    this.unitsPerStrip = 10,
    this.freeStrips = 0,
    this.looseTabs = 0,
  });

  double get profitPerStrip => mrp - storeAmount;
  
  // Profit from free strips (entire MRP is profit)
  double get profitFromFreeStrips => freeStrips * mrp;
  
  // Profit from loose tabs (proportional to profit per strip)
  double get profitFromLooseTabs {
    if (unitsPerStrip <= 0) return 0.0;
    final profitPerTab = profitPerStrip / unitsPerStrip;
    return looseTabs * profitPerTab;
  }
  
  // Total profit including regular strips, free strips, and loose tabs
  double get totalProfit {
    final regularProfit = stripsAvailable * profitPerStrip;
    return regularProfit + profitFromFreeStrips + profitFromLooseTabs;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'storeAmount': storeAmount,
        'mrp': mrp,
        'stripsAvailable': stripsAvailable,
        'unitsPerStrip': unitsPerStrip,
        'freeStrips': freeStrips,
        'looseTabs': looseTabs,
      };

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
        id: j['id'] as String,
        name: j['name'] as String,
        storeAmount: (j['storeAmount'] as num).toDouble(),
        mrp: (j['mrp'] as num).toDouble(),
        stripsAvailable: j['stripsAvailable'] as int,
        unitsPerStrip: (j['unitsPerStrip'] ?? 10) as int,
        freeStrips: (j['freeStrips'] ?? 0) as int,
        looseTabs: (j['looseTabs'] ?? 0) as int,
      );
}