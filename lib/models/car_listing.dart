import 'dart:math' as math;

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
  final int? firstRegistrationMonth;
  final String? fuel; // Benzin, Diesel, Elektro...
  final int? powerKW;
  final int? powerPS;
  final int? co2; // g/km WLTP
  final String? transmission; // Automatik, Schaltgetriebe
  final List<String> imageUrls;
  final String detailUrl; // URL relative AutoScout24
  final String? location;
  final String? sellerType; // Händler / Privat
  final int? weightG1; // Masse en ordre de marche, rubrique G (kg)
  final int? seats;
  final int? electricRangeKm;
  final String? description; // Description textuelle de l'annonce
  final String technicalSource;

  const CarListing({
    required this.id,
    required this.title,
    required this.brand,
    required this.model,
    required this.price,
    required this.priceFormatted,
    this.mileage,
    this.year,
    this.firstRegistrationMonth,
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
    this.seats,
    this.electricRangeKm,
    this.description,
    this.technicalSource = 'Annonce AutoScout24',
  });

  bool get hasRequiredTechnicalData {
    final energy = (fuel ?? '').toLowerCase();
    final isElectric = energy.contains('elektro') ||
        energy.contains('electric') ||
        energy.contains('électrique');
    final needsWeight = !isElectric && (year ?? DateTime.now().year) >= 2022;
    return estimatedFiscalPower > 0 &&
        year != null &&
        mileage != null &&
        (!needsWeight || (weightG1 != null && weightG1! > 0)) &&
        (isElectric || (co2 != null && co2! > 0));
  }

  CarListing copyWith({
    String? title,
    int? mileage,
    int? year,
    int? firstRegistrationMonth,
    String? fuel,
    int? powerKW,
    int? powerPS,
    int? co2,
    String? transmission,
    List<String>? imageUrls,
    String? location,
    String? sellerType,
    int? weightG1,
    int? seats,
    int? electricRangeKm,
    String? description,
    String? technicalSource,
  }) {
    return CarListing(
      id: id,
      title: title ?? this.title,
      brand: brand,
      model: model,
      price: price,
      priceFormatted: priceFormatted,
      mileage: mileage ?? this.mileage,
      year: year ?? this.year,
      firstRegistrationMonth:
          firstRegistrationMonth ?? this.firstRegistrationMonth,
      fuel: fuel ?? this.fuel,
      powerKW: powerKW ?? this.powerKW,
      powerPS: powerPS ?? this.powerPS,
      co2: co2 ?? this.co2,
      transmission: transmission ?? this.transmission,
      imageUrls: imageUrls ?? this.imageUrls,
      detailUrl: detailUrl,
      location: location ?? this.location,
      sellerType: sellerType ?? this.sellerType,
      weightG1: weightG1 ?? this.weightG1,
      seats: seats ?? this.seats,
      electricRangeKm: electricRangeKm ?? this.electricRangeKm,
      description: description ?? this.description,
      technicalSource: technicalSource ?? this.technicalSource,
    );
  }

  /// Estimation de la puissance administrative à partir des formules légales.
  /// Avant 2020, le calcul utilise aussi le CO2 NEDC ; depuis 2020 il repose
  /// uniquement sur la puissance nette maximale en kW.
  int get estimatedFiscalPower {
    final kw = powerKW;
    if (kw == null || kw <= 0) return 0;
    if ((year ?? 0) < 2020) {
      final emissions = co2;
      if (emissions == null || emissions <= 0) return 0;
      return (emissions / 45 + math.pow(kw / 40, 1.6))
          .round()
          .clamp(1, 100);
    }
    final p = kw / 100;
    return (1.34 + 1.8 * p * p + 3.87 * p).round().clamp(1, 100);
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
        .map(_extractBestImageUrl)
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();

    // Parse vehicle details (mileage, year, power, fuel)
    final details = json['vehicleDetails'] as List<dynamic>? ?? [];
    int? mileage;
    int? year;
    int? firstRegistrationMonth;
    int? powerKW;
    int? powerPS;
    int? co2;
    int? weightG1;
    int? seats;
    int? electricRangeKm;
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
        final registration = _parseRegistration(data);
        year = registration.$1;
        firstRegistrationMonth = registration.$2;
      } else if (label.contains('leistung') || label.contains('power')) {
        final match = RegExp(r'(\d+)\s*kW').firstMatch(data);
        if (match != null) powerKW = int.tryParse(match.group(1)!);
        final psMatch = RegExp(r'(\d+)\s*PS').firstMatch(data);
        if (psMatch != null) powerPS = int.tryParse(psMatch.group(1)!);
      } else if (label.contains('kraftstoff') || label.contains('fuel')) {
        fuel = data;
      } else if (label.contains('getriebe') || label.contains('transmission')) {
        transmission = data;
      } else if (label.contains('co2') || label.contains('emissionen')) {
        co2 = _parseNumber(data);
      } else if (label.contains('gewicht') ||
          label.contains('weight') ||
          label.contains('leergewicht')) {
        // Can be "1.585 kg"
        final w = _parseNumber(data);
        if (w != null && w > 500) weightG1 = w;
      } else if (label.contains('sitzpl') || label.contains('seats')) {
        seats = _parseNumber(data);
      } else if (label.contains('reichweite') ||
          label.contains('electric range')) {
        electricRangeKm = _parseNumber(data);
      }
    }

    // Fallback from raw JSON keys if not in vehicleDetails list
    co2 ??= _parseNumber(vehicle['co2Content']?.toString());
    weightG1 ??= _parseNumber(vehicle['weight']?.toString());

    // AutoScout déplace régulièrement ces valeurs entre vehicleDetails et des
    // blocs structurés (WLTP/consommation). On inspecte les clés, sans jamais
    // prendre un nombre qui ne soit pas rattaché explicitement à la donnée.
    co2 ??= _findNumberByKeys(json, const [
      'co2emission',
      'co2content',
      'co2value',
    ]);
    weightG1 ??= _findNumberByKeys(json, const [
      'curbweight',
      'emptyweight',
      'leergewicht',
    ]);
    seats ??= _findNumberByKeys(json, const ['seats', 'numberofseats']);
    electricRangeKm ??= _findNumberByKeys(json, const [
      'electricrange',
      'wltprange',
    ]);

    // Also try top-level fields
    mileage ??= _parseNumber(vehicle['mileage']?.toString());
    year ??= vehicle['firstRegistrationYear'] as int?;
    firstRegistrationMonth ??= int.tryParse(
      vehicle['firstRegistrationMonth']?.toString() ?? '',
    );
    fuel ??= vehicle['fuelType'] as String?;

    final url = json['url'] as String? ?? '';
    final id = json['id']?.toString() ?? url.hashCode.toString();
    final location = json['location'] as Map<String, dynamic>?;
    final locationStr = location != null
        ? '${location['city'] ?? ''}, ${location['country'] ?? ''}'
        : null;
    final seller = json['seller'] as Map<String, dynamic>?;
    final sellerType = seller?['type'] as String?;
    final description =
        json['description']?.toString() ?? vehicle['description']?.toString();

    return CarListing(
      id: id,
      title:
          '$make $model${json['version'] != null ? ' ${json['version']}' : ''}',
      brand: make,
      model: model,
      price: priceValue,
      priceFormatted: priceFormatted,
      mileage: mileage,
      year: year,
      firstRegistrationMonth: firstRegistrationMonth,
      fuel: fuel,
      powerKW: powerKW,
      powerPS: powerPS,
      co2: co2,
      weightG1: weightG1,
      seats: seats,
      electricRangeKm: electricRangeKm,
      imageUrls: imageUrls.cast<String>(),
      detailUrl: url,
      location: locationStr,
      sellerType: sellerType,
      transmission: transmission,
      description: description,
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

  static int? _findNumberByKeys(dynamic node, List<String> acceptedKeys) {
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key
            .toString()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (acceptedKeys.any(key.contains)) {
          final value = _structuredNumber(entry.value);
          if (value != null && value > 0) return value;
        }
      }
      for (final value in node.values) {
        final found = _findNumberByKeys(value, acceptedKeys);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findNumberByKeys(value, acceptedKeys);
        if (found != null) return found;
      }
    }
    return null;
  }

  static int? _structuredNumber(dynamic value) {
    if (value is num) return value.round();
    if (value is String) return _parseNumber(value);
    if (value is Map) {
      for (final key in const ['value', 'rawValue', 'formattedValue', 'text']) {
        if (value.containsKey(key)) {
          final parsed = _structuredNumber(value[key]);
          if (parsed != null) return parsed;
        }
      }
      if (value.length == 1) return _structuredNumber(value.values.first);
    }
    if (value is List && value.length == 1) {
      return _structuredNumber(value.first);
    }
    return null;
  }

  static (int?, int?) _parseRegistration(String value) {
    final match = RegExp(r'(?:(\d{1,2})[./-])?(\d{4})').firstMatch(value);
    if (match == null) return (null, null);
    final month = int.tryParse(match.group(1) ?? '');
    final year = int.tryParse(match.group(2) ?? '');
    return (year, month != null && month >= 1 && month <= 12 ? month : null);
  }

  static String _extractBestImageUrl(dynamic image) {
    String url = '';
    if (image is String) {
      url = image;
    } else if (image is Map<String, dynamic>) {
      for (final key in const [
        'urlFull',
        'fullUrl',
        'urlLarge',
        'large',
        'url',
        'src',
      ]) {
        final candidate = image[key];
        if (candidate is String && candidate.isNotEmpty) {
          url = candidate;
          break;
        }
      }
    }
    if (url.isEmpty) return '';
    if (url.startsWith('//')) url = 'https:$url';
    url = url.replaceAllMapped(
      RegExp(r'/(\d{2,4})x(\d{2,4})(?=[./][^/]*$)'),
      (_) => '/1600x1200',
    );

    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final query = Map<String, String>.from(uri.queryParameters);
    // AutoScout sert parfois une vignette 320 px. On conserve le CDN et on
    // demande une version suffisamment grande pour les ecrans Retina.
    for (final key in const ['w', 'width']) {
      if (query.containsKey(key)) query[key] = '1600';
    }
    for (final key in const ['h', 'height']) {
      if (query.containsKey(key)) query[key] = '1200';
    }
    if (query.containsKey('quality')) query['quality'] = '90';
    return uri
        .replace(queryParameters: query.isEmpty ? null : query)
        .toString();
  }

  /// Convertit une annonce en objet de calcul fiscal avec priorité aux données réelles
  VehicleEntry toVehicleEntry({required String region}) {
    // --- Priorité 1 : Extraction depuis le texte/titre (Priority Data Override) ---
    int? extractedCV;
    int? extractedCO2;
    int? extractedWeight;

    // On scanne tout ce qu'on a
    final fullText =
        '$title ${description ?? ''} ${fuel ?? ''} ${transmission ?? ''}'
            .toLowerCase();
    final identity = '$brand $model'.trim();
    final trim = title.toLowerCase().startsWith(identity.toLowerCase())
        ? title.substring(identity.length).trim()
        : title.trim();

    // Ne retenir un CV que s'il est explicitement qualifie de fiscal. Dans
    // certaines annonces, "CV" designe la puissance moteur et fausserait P.6.
    final cvMatch = RegExp(
      r'(?:fiscal(?:e|es)?|p\.6)\s*[:=-]?\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(fullText);
    if (cvMatch != null) {
      extractedCV = int.tryParse(cvMatch.group(1)!);
    }

    // Regex pour CO2 (ex: "185g", "185 g/km")
    final co2Match = RegExp(
      r'(?:co2|co₂|v\.7)[^0-9]{0,40}(\d{1,3})\s*g(?:/km)?',
    ).firstMatch(fullText);
    if (co2Match != null) {
      extractedCO2 = int.tryParse(co2Match.group(1)!);
    }

    // Regex pour Poids (ex: "1585kg", "1585 kg")
    final weightMatch = RegExp(
      r'(?:leergewicht|poids|masse|champ g)[^0-9]{0,60}(\d{3,4})\s*kg',
    ).firstMatch(fullText);
    if (weightMatch != null) {
      extractedWeight = int.tryParse(weightMatch.group(1)!);
    }

    // Sources
    final calculatedCV = extractedCV ?? estimatedFiscalPower;
    final sCV = extractedCV != null
        ? 'Annonce'
        : calculatedCV > 0
        ? 'Calcul officiel kW'
        : 'Manquant';
    final sCO2 = (extractedCO2 ?? co2) != null
        ? technicalSource
        : 'Manquant';
    final sW = (extractedWeight ?? weightG1) != null
        ? technicalSource
        : 'Manquant';

    return VehicleEntry(
      brand: brand,
      model: model,
      trim: trim,
      year: year ?? 0,
      // Mois inconnu : decembre est le choix fiscal conservateur pour ne pas
      // surestimer la decote liee a l'age.
      firstRegistrationMonth: firstRegistrationMonth ?? 12,
      mileage: mileage,
      powerDIN: powerPS ?? (powerKW != null ? (powerKW! * 1.36).round() : 0),
      // ON NE MET PLUS DE VALEUR AU HASARD (0 si non trouvé pour le rouge UI)
      powerFiscal: calculatedCV,
      weightG1: extractedWeight ?? (weightG1 ?? 0),
      co2WLTP: extractedCO2 ?? (co2 ?? 0),
      fuelType: fuel,
      seats: seats ?? 0,
      electricRangeKm: electricRangeKm,
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
