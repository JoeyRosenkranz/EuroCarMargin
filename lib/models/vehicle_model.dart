/// Modèle de données pour un véhicule à évaluer
class VehicleEntry {
  final int? id;
  final String brand;
  final String model;
  final String trim;
  final int year; // Année de 1ère immatriculation
  final int firstRegistrationMonth;
  final int? mileage;
  final int powerDIN; // Puissance DIN (ch)
  final int powerFiscal; // Puissance fiscale (CV)
  final int weightG1; // Masse en ordre de marche, rubrique G (kg)
  final int co2WLTP; // Émissions CO2 WLTP (g/km)
  final String? fuelType; // Elektro, Hybrid (PHEV), Diesel, Benzin...
  final int seats;
  final int? electricRangeKm;
  final double purchasePrice; // Prix d'achat Allemagne (€)
  final double transportCost; // Frais transport/plateau (€)
  final double prepCost; // Frais entretien/prépa (€)
  final String region; // Région FR pour taxe régionale
  final String sourceFiscal; // 'Annonce', 'Manuel', 'Manquant'
  final String sourceCO2; // 'Annonce', 'Manuel', 'Manquant'
  final String sourceWeight; // 'Annonce', 'Manuel', 'Manquant'
  final String? rawDescription; // Stocké pour ré-analyse
  final DateTime createdAt;

  const VehicleEntry({
    this.id,
    required this.brand,
    required this.model,
    this.trim = '',
    required this.year,
    this.firstRegistrationMonth = 1,
    this.mileage,
    required this.powerDIN,
    required this.powerFiscal,
    required this.weightG1,
    required this.co2WLTP,
    this.fuelType,
    this.seats = 5,
    this.electricRangeKm,
    required this.purchasePrice,
    this.transportCost = 0,
    this.prepCost = 0,
    required this.region,
    this.sourceFiscal = 'Annonce',
    this.sourceCO2 = 'Annonce',
    this.sourceWeight = 'Annonce',
    this.rawDescription,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'brand': brand,
    'model': model,
    'trim': trim,
    'year': year,
    'first_registration_month': firstRegistrationMonth,
    'mileage': mileage,
    'power_din': powerDIN,
    'power_fiscal': powerFiscal,
    'weight_g1': weightG1,
    'co2_wltp': co2WLTP,
    if (fuelType != null) 'fuel_type': fuelType,
    'seats': seats,
    'electric_range_km': electricRangeKm,
    'purchase_price': purchasePrice,
    'transport_cost': transportCost,
    'prep_cost': prepCost,
    'region': region,
    'source_fiscal': sourceFiscal,
    'source_co2': sourceCO2,
    'source_weight': sourceWeight,
    'raw_description': rawDescription,
    'created_at': createdAt.toIso8601String(),
  };

  factory VehicleEntry.fromMap(Map<String, dynamic> m) => VehicleEntry(
    id: m['id'] as int?,
    brand: m['brand'] as String,
    model: m['model'] as String,
    trim: m['trim'] as String? ?? '',
    year: m['year'] as int,
    firstRegistrationMonth: ((m['first_registration_month'] as int?) ?? 1)
        .clamp(1, 12)
        .toInt(),
    mileage: m['mileage'] as int?,
    powerDIN: m['power_din'] as int,
    powerFiscal: m['power_fiscal'] as int,
    weightG1: m['weight_g1'] as int,
    co2WLTP: m['co2_wltp'] as int,
    fuelType: m['fuel_type'] as String?,
    seats: m['seats'] as int? ?? 5,
    electricRangeKm: m['electric_range_km'] as int?,
    purchasePrice: (m['purchase_price'] as num).toDouble(),
    transportCost: (m['transport_cost'] as num?)?.toDouble() ?? 0,
    prepCost: (m['prep_cost'] as num?)?.toDouble() ?? 0,
    region: m['region'] as String,
    sourceFiscal: m['source_fiscal'] as String? ?? 'Annonce',
    sourceCO2: m['source_co2'] as String? ?? 'Annonce',
    sourceWeight: m['source_weight'] as String? ?? 'Annonce',
    rawDescription: m['raw_description'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  VehicleEntry copyWith({
    int? id,
    String? brand,
    String? model,
    String? trim,
    int? year,
    int? firstRegistrationMonth,
    int? mileage,
    int? powerDIN,
    int? powerFiscal,
    int? weightG1,
    int? co2WLTP,
    String? fuelType,
    int? seats,
    int? electricRangeKm,
    double? purchasePrice,
    double? transportCost,
    double? prepCost,
    String? region,
    String? sourceFiscal,
    String? sourceCO2,
    String? sourceWeight,
    String? rawDescription,
    DateTime? createdAt,
  }) => VehicleEntry(
    id: id ?? this.id,
    brand: brand ?? this.brand,
    model: model ?? this.model,
    trim: trim ?? this.trim,
    year: year ?? this.year,
    firstRegistrationMonth:
        firstRegistrationMonth ?? this.firstRegistrationMonth,
    mileage: mileage ?? this.mileage,
    powerDIN: powerDIN ?? this.powerDIN,
    powerFiscal: powerFiscal ?? this.powerFiscal,
    weightG1: weightG1 ?? this.weightG1,
    co2WLTP: co2WLTP ?? this.co2WLTP,
    fuelType: fuelType ?? this.fuelType,
    seats: seats ?? this.seats,
    electricRangeKm: electricRangeKm ?? this.electricRangeKm,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    transportCost: transportCost ?? this.transportCost,
    prepCost: prepCost ?? this.prepCost,
    region: region ?? this.region,
    sourceFiscal: sourceFiscal ?? this.sourceFiscal,
    sourceCO2: sourceCO2 ?? this.sourceCO2,
    sourceWeight: sourceWeight ?? this.sourceWeight,
    rawDescription: rawDescription ?? this.rawDescription,
    createdAt: createdAt ?? this.createdAt,
  );
}
