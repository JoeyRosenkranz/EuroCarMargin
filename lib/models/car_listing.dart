import 'vehicle_model.dart';

/// Modèle pour une annonce automobile scrappée depuis AutoScout24
class CarListing {
  final String id;
  final String title;
  final String brand;
  final String model;
  final double price; // Prix en € (Allemagne)
  final String priceFormatted;
  final int? mileage; // km
  final int? year; // Année 1ère immat
  final String? fuel; // Benzin, Diesel, Elektro...
  final int? powerKW;
  final int? powerPS;
  final int? co2; // g/km WLTP
  final String? transmission; // Automatik, Schaltgetriebe
  final List<String> imageUrls;
  final String detailUrl; // URL relative AutoScout24
  final String? location;
  final String? sellerType; // Händler / Privat
  final int? weightG1; // Poids à vide G1 (kg)
  final String? description; // Description textuelle de l'annonce

  const CarListing({
    required this.id,
    required this.title,
    required this.brand,
    required this.model,
    required this.price,
    required this.priceFormatted,
    this.mileage,
    this.year,
    this.fuel,
    this.powerKW,
    this.powerPS,
    this.co2,
    this.transmission,
    this.imageUrls = const [],
    required this.detailUrl,
    this.location,
    this.sellerType,
    this.weightG1,
    this.description,
  });

  /// Puissance fiscale estimée (CV) — approximation officielle française
  /// Formule: 1 + (CO2/45) + (kW/40)^1.6
  int get estimatedFiscalPower {
    final co2Val = co2 ?? 0;
    final kwVal = powerKW ?? 0;
    if (co2Val == 0 && kwVal == 0) return 5; // Fallback
    final pa = (kwVal / 40);
    final cv = 1.0 + (co2Val / 45.0) + (pa * pa > 1 ? pa * pa : pa);
    return cv.round().clamp(1, 100);
  }

  /// Poids estimé G1 basé sur le segment (approximation)
  /// En l'absence de donnée exacte, on estime via la puissance
  int get estimatedWeightG1 {
    final ps = powerPS ?? 100;
    if (ps <= 110) return 1350;
    if (ps <= 150) return 1450;
    if (ps <= 200) return 1550;
    if (ps <= 250) return 1650;
    if (ps <= 350) return 1800;
    return 2000;
  }

  factory CarListing.fromAutoScoutJson(Map<String, dynamic> json) {
    // Parse vehicle info
    final vehicle = json['vehicle'] as Map<String, dynamic>? ?? {};
    final make = vehicle['make'] as String? ?? '';
    final model = vehicle['model'] as String? ?? '';

    // Parse price
    final priceData = json['price'] as Map<String, dynamic>? ?? {};
    final priceFormatted = priceData['priceFormatted'] as String? ?? '€ 0';
    final priceValue = _parsePrice(priceFormatted);

    // Parse images
    final imagesRaw = json['images'] as List<dynamic>? ?? [];
    final imageUrls = imagesRaw
        .map((img) {
          String url = '';
          if (img is Map<String, dynamic>) {
            url = img['url'] as String? ?? '';
          } else if (img is String) {
            url = img;
          }
          
          if (url.isNotEmpty) {
             final qmIndex = url.indexOf('?');
             if (qmIndex != -1) {
               return url.substring(0, qmIndex);
             }
          }
          return url;
        })
        .where((url) => url.isNotEmpty)
        .toList();

    // Parse vehicle details (mileage, year, power, fuel)
    final details = json['vehicleDetails'] as List<dynamic>? ?? [];
    int? mileage;
    int? year;
    int? powerKW;
    int? powerPS;
    int? co2;
    int? weightG1;
    String? fuel;
    String? transmission;

    for (final detail in details) {
      if (detail is! Map<String, dynamic>) continue;
      final label = (detail['ariaLabel'] as String? ?? '').toLowerCase();
      final data = detail['data'] as String? ?? '';

      if (label.contains('laufleistung') || label.contains('kilometer')) {
        mileage = _parseNumber(data);
      } else if (label.contains('erstzulassung') ||
          label.contains('registration')) {
        year = _parseYear(data);
      } else if (label.contains('leistung') || label.contains('power')) {
        final match = RegExp(r'(\d+)\s*kW').firstMatch(data);
        if (match != null) powerKW = int.tryParse(match.group(1)!);
        final psMatch = RegExp(r'(\d+)\s*PS').firstMatch(data);
        if (psMatch != null) powerPS = int.tryParse(psMatch.group(1)!);
      } else if (label.contains('kraftstoff') || label.contains('fuel')) {
        fuel = data;
      } else if (label.contains('getriebe') ||
          label.contains('transmission')) {
        transmission = data;
      } else if (label.contains('co2') || label.contains('emissionen')) {
        co2 = _parseNumber(data);
      } else if (label.contains('gewicht') || label.contains('weight') || label.contains('leergewicht')) {
        // Can be "1.585 kg"
        final w = _parseNumber(data);
        if (w != null && w > 500) weightG1 = w;
      }
    }
    
    // Fallback from raw JSON keys if not in vehicleDetails list
    co2 ??= _parseNumber(vehicle['co2Content']?.toString());
    weightG1 ??= _parseNumber(vehicle['weight']?.toString());

    // Also try top-level fields
    mileage ??= _parseNumber(vehicle['mileage']?.toString());
    year ??= vehicle['firstRegistrationYear'] as int?;
    fuel ??= vehicle['fuelType'] as String?;

    final url = json['url'] as String? ?? '';
    final id = json['id']?.toString() ?? url.hashCode.toString();
    final location = json['location'] as Map<String, dynamic>?;
    final locationStr = location != null
        ? '${location['city'] ?? ''}, ${location['country'] ?? ''}'
        : null;
    final seller = json['seller'] as Map<String, dynamic>?;
    final sellerType = seller?['type'] as String?;

    return CarListing(
      id: id,
      title: '$make $model${json['version'] != null ? ' ${json['version']}' : ''}',
      brand: make,
      model: model,
      price: priceValue,
      priceFormatted: priceFormatted,
      mileage: mileage,
      year: year,
      fuel: fuel,
      powerKW: powerKW,
      powerPS: powerPS,
      co2: co2,
      weightG1: weightG1,
      imageUrls: imageUrls.cast<String>(),
      detailUrl: url,
      location: locationStr,
      sellerType: sellerType,
      transmission: transmission,
    );
  }

  static double _parsePrice(String s) {
    // "€ 27.499" or "27 499 €" etc.
    final cleaned = s.replaceAll(RegExp(r'[^\d]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  static int? _parseNumber(String? s) {
    if (s == null) return null;
    final cleaned = s.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(cleaned);
  }

  static int? _parseYear(String s) {
    // "10/2023" or "2023"
    final match = RegExp(r'(\d{4})').firstMatch(s);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Convertit une annonce en objet de calcul fiscal avec priorité aux données réelles
  VehicleEntry toVehicleEntry({required String region}) {
    // --- Priorité 1 : Extraction depuis le texte/titre (Priority Data Override) ---
    int? extractedCV;
    int? extractedCO2;
    int? extractedWeight;

    // On scanne tout ce qu'on a
    final fullText = '$title ${description ?? ''} ${fuel ?? ''} ${transmission ?? ''}'.toLowerCase();

    // Regex pour CV fiscaux (ex: "24 CV", "24CV", "fiscal 24")
    final cvMatch = RegExp(r'(\d+)\s*cv').firstMatch(fullText);
    if (cvMatch != null) {
      extractedCV = int.tryParse(cvMatch.group(1)!);
    }

    // Regex pour CO2 (ex: "185g", "185 g/km")
    final co2Match = RegExp(r'(\d+)\s*(g/km|g)').firstMatch(fullText);
    if (co2Match != null) {
      extractedCO2 = int.tryParse(co2Match.group(1)!);
    }

    // Regex pour Poids (ex: "1585kg", "1585 kg")
    final weightMatch = RegExp(r'(\d{4})\s*kg').firstMatch(fullText);
    if (weightMatch != null) {
      extractedWeight = int.tryParse(weightMatch.group(1)!);
    }

    // Sources
    final sCV = extractedCV != null ? 'Annonce' : 'Manquant';
    final sCO2 = (extractedCO2 ?? co2) != null ? 'Annonce' : 'Manquant';
    final sW = (extractedWeight ?? weightG1) != null ? 'Annonce' : 'Manquant';

    return VehicleEntry(
      brand: brand,
      model: model,
      year: year ?? DateTime.now().year,
      powerDIN: powerPS ?? (powerKW != null ? (powerKW! * 1.36).round() : 100),
      // ON NE MET PLUS DE VALEUR AU HASARD (0 si non trouvé pour le rouge UI)
      powerFiscal: extractedCV ?? 0, 
      weightG1: extractedWeight ?? (weightG1 ?? 0),
      co2WLTP: extractedCO2 ?? (co2 ?? 0),
      fuelType: fuel,
      purchasePrice: price,
      region: region,
      sourceFiscal: sCV,
      sourceCO2: sCO2,
      sourceWeight: sW,
      rawDescription: description,
      createdAt: DateTime.now(),
    );
  }
}
