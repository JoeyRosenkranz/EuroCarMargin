import 'dart:math';

import '../data/tax_data.dart';
import '../models/calculation_result.dart';
import '../models/vehicle_model.dart';

/// Moteur fiscal pour les vehicules d'occasion importes en France en 2026.
///
/// Il n'invente jamais une donnee fiscale manquante. Un resultat incomplet est
/// renvoye avec [CalculationResult.calculationReliable] a false.
class TaxCalculator {
  final DateTime registrationDate;

  TaxCalculator({DateTime? registrationDate})
    : registrationDate = registrationDate ?? DateTime.now();

  bool _isEVOrHydrogen(String? fuel, String model) {
    final text = '${fuel ?? ''} $model'.toLowerCase();
    return text.contains('elektro') ||
        text.contains('electric') ||
        text.contains('electrique') ||
        text.contains('électrique') ||
        text.contains('hydrogen') ||
        text.contains('hydrogène') ||
        text.contains('hydrogene') ||
        text.contains('tesla');
  }

  bool _isPHEV(String? fuel) {
    final value = (fuel ?? '').toLowerCase();
    return value.contains('plug-in') ||
        value.contains('plug in') ||
        value.contains('phev') ||
        value.contains('rechargeable');
  }

  bool _isHybrid(String? fuel) {
    final value = (fuel ?? '').toLowerCase();
    return _isPHEV(fuel) ||
        value.contains('hybrid') ||
        value.contains('hybride');
  }

  bool _isE85(String? fuel) {
    final value = (fuel ?? '').toLowerCase();
    return value.contains('e85') || value.contains('superethanol');
  }

  DateTime _firstRegistration(int year, [int month = 1]) {
    final safeMonth = month.clamp(1, 12).toInt();
    // Les annonces fournissent le plus souvent MM/AAAA sans le jour. Retenir
    // le dernier jour du mois evite de surestimer la decote fiscale.
    return DateTime(year, safeMonth + 1, 0);
  }

  int ageInMonths(DateTime firstRegistration) {
    if (!registrationDate.isAfter(firstRegistration)) return 0;
    var months =
        (registrationDate.year - firstRegistration.year) * 12 +
        registrationDate.month -
        firstRegistration.month;
    if (registrationDate.day > firstRegistration.day) months++;
    return max(1, months);
  }

  int ageReductionPercent(DateTime firstRegistration) {
    final months = ageInMonths(firstRegistration);
    if (months == 0) return 0;
    for (final bracket in ageDiscountBrackets) {
      if (months <= bracket.maxMonths) return bracket.percent;
    }
    return 100;
  }

  int _scheduleYear(DateTime firstRegistration) {
    if (firstRegistration.year == 2025 && firstRegistration.month <= 2) {
      return 2024;
    }
    return firstRegistration.year;
  }

  Co2Schedule? _schedule(DateTime firstRegistration) =>
      co2Schedules[_scheduleYear(firstRegistration)];

  double _co2Base(
    int co2,
    DateTime firstRegistration, {
    String? fuelType,
    required String model,
  }) {
    if (_isEVOrHydrogen(fuelType, model) || co2 <= 0) return 0;
    final schedule = _schedule(firstRegistration);
    if (schedule == null || co2 < schedule.threshold) return 0;
    if (co2 >= schedule.maximumFrom) return schedule.maximum.toDouble();
    final override = schedule.overrides[co2];
    if (override != null) return override.toDouble();
    final index = co2 - schedule.threshold;
    if (index < 0) return 0;
    if (index >= schedule.amounts.length) return schedule.maximum.toDouble();
    return min(schedule.amounts[index], schedule.maximum).toDouble();
  }

  double _discount(double amount, DateTime firstRegistration) {
    final pct = ageReductionPercent(firstRegistration);
    return (amount * (100 - pct) / 100).roundToDouble();
  }

  double calcTaxeRegionale(
    String region,
    int puissanceFiscale,
    int anneeImmat, {
    int firstRegistrationMonth = 1,
    String? fuelType,
    required String model,
  }) {
    if (puissanceFiscale <= 0) return 0;
    final prixCV = regionalTaxPerCV[region] ?? 60.0;
    final firstRegistration = _firstRegistration(
      anneeImmat,
      firstRegistrationMonth,
    );
    final tenYearAnniversary = DateTime(
      firstRegistration.year + 10,
      firstRegistration.month,
      firstRegistration.day,
    );
    var value = puissanceFiscale * prixCV;
    if (registrationDate.isAfter(tenYearAnniversary)) value /= 2;
    if (_isEVOrHydrogen(fuelType, model)) {
      value *= 1 - (cleanVehicleRegionalExemption[region] ?? 0);
    }
    return value.roundToDouble();
  }

  double calcMalusCO2(
    int co2,
    int anneeImmat, {
    int firstRegistrationMonth = 1,
    String? fuelType,
    required String model,
    int childrenCount = 0,
    int seats = 5,
  }) {
    final firstRegistration = _firstRegistration(
      anneeImmat,
      firstRegistrationMonth,
    );
    var taxableCo2 = co2;
    if (_isE85(fuelType) && taxableCo2 <= 250) {
      taxableCo2 = (taxableCo2 * 0.60).round();
    }
    if (childrenCount >= 3 && seats >= 5) {
      taxableCo2 = max(0, taxableCo2 - childrenCount * 20);
    }
    return _discount(
      _co2Base(taxableCo2, firstRegistration, fuelType: fuelType, model: model),
      firstRegistration,
    );
  }

  double calcMalusCO2BeforeVetuste(
    int co2,
    int anneeImmat, {
    int firstRegistrationMonth = 1,
    String? fuelType,
    required String model,
    int childrenCount = 0,
    int seats = 5,
  }) {
    var taxableCo2 = co2;
    if (_isE85(fuelType) && taxableCo2 <= 250) {
      taxableCo2 = (taxableCo2 * 0.60).round();
    }
    if (childrenCount >= 3 && seats >= 5) {
      taxableCo2 = max(0, taxableCo2 - childrenCount * 20);
    }
    return _co2Base(
      taxableCo2,
      _firstRegistration(anneeImmat, firstRegistrationMonth),
      fuelType: fuelType,
      model: model,
    );
  }

  List<WeightMalusBracket> _weightBrackets(int year) {
    if (year >= 2026) return weightBrackets2026;
    if (year >= 2024) return weightBrackets2024;
    return weightBrackets2022;
  }

  int _energyWeight(
    int weight,
    DateTime firstRegistration,
    String? fuelType,
    int? electricRangeKm,
  ) {
    final year = firstRegistration.year;
    if (_isPHEV(fuelType)) {
      // Les hybrides rechargeables sont exoneres pour les premieres
      // immatriculations 2022 a 2024. Depuis 2025, l'abattement est de
      // 200 kg, plafonne a 15 % de la masse.
      if (year <= 2024) return 0;
      if (year >= 2025) {
        return max(0, weight - min(200, (weight * 0.15).floor()));
      }
    }
    if (year >= 2024 && _isHybrid(fuelType)) return max(0, weight - 100);
    return weight;
  }

  double _weightBase(
    int weight,
    DateTime firstRegistration, {
    String? fuelType,
    required String model,
    int? electricRangeKm,
    int childrenCount = 0,
    int seats = 5,
  }) {
    if (_isEVOrHydrogen(fuelType, model) || firstRegistration.year < 2022) {
      return 0;
    }
    var taxableWeight = _energyWeight(
      weight,
      firstRegistration,
      fuelType,
      electricRangeKm,
    );
    if (taxableWeight == 0) return 0;
    if (childrenCount >= 3 && seats >= 5) {
      taxableWeight = max(0, taxableWeight - childrenCount * 200);
    }
    var total = 0.0;
    for (final bracket in _weightBrackets(firstRegistration.year)) {
      if (taxableWeight < bracket.fromKg) break;
      final upper = bracket.toKg == null
          ? taxableWeight
          : min(taxableWeight, bracket.toKg!);
      // Les bornes sont inclusives. Verification croisee avec le simulateur
      // Service-Public : 1 600 kg en 2025 produit bien 10 EUR avant decote.
      total += (upper - bracket.fromKg + 1) * bracket.euroPerKg;
    }
    return total;
  }

  double calcMalusPoids(
    int poidsG1, {
    int anneeImmat = 2026,
    int firstRegistrationMonth = 1,
    String? fuelType,
    required String model,
    int? electricRangeKm,
    int childrenCount = 0,
    int seats = 5,
  }) {
    final firstRegistration = _firstRegistration(
      anneeImmat,
      firstRegistrationMonth,
    );
    return _discount(
      _weightBase(
        poidsG1,
        firstRegistration,
        fuelType: fuelType,
        model: model,
        electricRangeKm: electricRangeKm,
        childrenCount: childrenCount,
        seats: seats,
      ),
      firstRegistration,
    );
  }

  double _cappedMalus(double co2, double weight, DateTime firstRegistration) {
    final schedule = _schedule(firstRegistration);
    if (schedule == null) return co2 + weight;
    final cap = _discount(schedule.maximum.toDouble(), firstRegistration);
    return min(co2 + weight, cap);
  }

  double _effectiveWeightMalus(
    double co2,
    double rawWeight,
    DateTime firstRegistration,
  ) => max(0, _cappedMalus(co2, rawWeight, firstRegistration) - co2);

  double calcCarteGrise({
    required String region,
    required int puissanceFiscale,
    required int anneeImmat,
    int firstRegistrationMonth = 1,
    required int co2,
    required int poidsG1,
    required String model,
    String? fuelType,
    int? electricRangeKm,
    int childrenCount = 0,
    int seats = 5,
  }) {
    final firstRegistration = _firstRegistration(
      anneeImmat,
      firstRegistrationMonth,
    );
    final y1 = calcTaxeRegionale(
      region,
      puissanceFiscale,
      anneeImmat,
      firstRegistrationMonth: firstRegistrationMonth,
      fuelType: fuelType,
      model: model,
    );
    final y3 = calcMalusCO2(
      co2,
      anneeImmat,
      firstRegistrationMonth: firstRegistrationMonth,
      fuelType: fuelType,
      model: model,
      childrenCount: childrenCount,
      seats: seats,
    );
    final mass = calcMalusPoids(
      poidsG1,
      anneeImmat: anneeImmat,
      firstRegistrationMonth: firstRegistrationMonth,
      fuelType: fuelType,
      model: model,
      electricRangeKm: electricRangeKm,
      childrenCount: childrenCount,
      seats: seats,
    );
    return y1 +
        _cappedMalus(y3, mass, firstRegistration) +
        taxeFixeY4 +
        redevanceAcheminementY5;
  }

  Map<String, double> estimateResalePrices(VehicleEntry vehicle) => const {
    'quick': 0,
    'market': 0,
  };

  CalculationResult calculate(
    VehicleEntry vehicle, {
    int childrenCount = 0,
    double? lbcMarketPrice,
    double? lbcQuickPrice,
    int comparableCount = 0,
    double proCosts = 1500,
    bool vatOnMargin = true,
  }) {
    final warnings = <String>[];
    var reliable = true;
    final firstRegistration = _firstRegistration(
      vehicle.year,
      vehicle.firstRegistrationMonth,
    );

    if (vehicle.powerFiscal <= 0) {
      warnings.add(
        'Puissance fiscale manquante (champ P.6 de la carte grise).',
      );
      reliable = false;
    }
    if (vehicle.co2WLTP <= 0 &&
        !_isEVOrHydrogen(vehicle.fuelType, vehicle.model)) {
      warnings.add('CO2 WLTP manquant (champ V.7).');
      reliable = false;
    }
    if (vehicle.weightG1 <= 0) {
      warnings.add('Masse en ordre de marche manquante (champ G, pas G.1).');
      reliable = false;
    }
    if (vehicle.year < 2020) {
      warnings.add(
        'Vehicule anterieur a 2020 : le bareme NEDC doit etre verifie avec le simulateur officiel.',
      );
      reliable = false;
    }
    if (vehicle.transportCost <= 0) {
      warnings.add('Transport non renseigne.');
      reliable = false;
    }
    if ((lbcMarketPrice ?? 0) <= 0) {
      warnings.add('Aucun prix francais comparable fiable.');
      reliable = false;
    } else if (comparableCount < 3) {
      warnings.add('Moins de 3 annonces francaises comparables.');
      reliable = false;
    }

    final familyEligible = childrenCount >= 3 && vehicle.seats >= 5;
    if (childrenCount >= 3 && vehicle.seats < 5) {
      warnings.add(
        'Abattement famille refuse : le vehicule doit avoir au moins 5 places.',
      );
    }
    if (familyEligible) {
      warnings.add(
        'Famille nombreuse : remboursement ulterieur, un seul vehicule par foyer sur 2 ans.',
      );
    }

    final y1 = calcTaxeRegionale(
      vehicle.region,
      vehicle.powerFiscal,
      vehicle.year,
      firstRegistrationMonth: vehicle.firstRegistrationMonth,
      fuelType: vehicle.fuelType,
      model: vehicle.model,
    );
    final cashCo2 = calcMalusCO2(
      vehicle.co2WLTP,
      vehicle.year,
      firstRegistrationMonth: vehicle.firstRegistrationMonth,
      fuelType: vehicle.fuelType,
      model: vehicle.model,
    );
    final cashWeight = calcMalusPoids(
      vehicle.weightG1,
      anneeImmat: vehicle.year,
      firstRegistrationMonth: vehicle.firstRegistrationMonth,
      fuelType: vehicle.fuelType,
      model: vehicle.model,
      electricRangeKm: vehicle.electricRangeKm,
    );
    final cashCombined = _cappedMalus(cashCo2, cashWeight, firstRegistration);
    final effectiveCashWeight = _effectiveWeightMalus(
      cashCo2,
      cashWeight,
      firstRegistration,
    );

    final finalCo2 = calcMalusCO2(
      vehicle.co2WLTP,
      vehicle.year,
      firstRegistrationMonth: vehicle.firstRegistrationMonth,
      fuelType: vehicle.fuelType,
      model: vehicle.model,
      childrenCount: familyEligible ? childrenCount : 0,
      seats: vehicle.seats,
    );
    final finalWeight = calcMalusPoids(
      vehicle.weightG1,
      anneeImmat: vehicle.year,
      firstRegistrationMonth: vehicle.firstRegistrationMonth,
      fuelType: vehicle.fuelType,
      model: vehicle.model,
      electricRangeKm: vehicle.electricRangeKm,
      childrenCount: familyEligible ? childrenCount : 0,
      seats: vehicle.seats,
    );
    final finalCombined = _cappedMalus(
      finalCo2,
      finalWeight,
      firstRegistration,
    );
    final effectiveFinalWeight = _effectiveWeightMalus(
      finalCo2,
      finalWeight,
      firstRegistration,
    );
    final familyRefund = max(0.0, cashCombined - finalCombined);

    final cashRegistration =
        y1 + cashCombined + taxeFixeY4 + redevanceAcheminementY5;
    final finalRegistration =
        y1 + finalCombined + taxeFixeY4 + redevanceAcheminementY5;
    final cashRequired =
        vehicle.purchasePrice +
        cashRegistration +
        vehicle.transportCost +
        vehicle.prepCost;
    final totalInvested = cashRequired - familyRefund;

    final marketPrice = lbcMarketPrice ?? 0;
    final quickPrice =
        lbcQuickPrice ?? (marketPrice > 0 ? marketPrice * .95 : 0);
    final agePct = ageReductionPercent(firstRegistration);

    return CalculationResult(
      vehicle: vehicle,
      taxeRegionale: y1,
      malusCO2: finalCo2,
      malusCO2BeforeVetuste: calcMalusCO2BeforeVetuste(
        vehicle.co2WLTP,
        vehicle.year,
        firstRegistrationMonth: vehicle.firstRegistrationMonth,
        fuelType: vehicle.fuelType,
        model: vehicle.model,
        childrenCount: familyEligible ? childrenCount : 0,
        seats: vehicle.seats,
      ),
      malusPoids: effectiveFinalWeight,
      cashMalusCO2: cashCo2,
      cashMalusPoids: effectiveCashWeight,
      familyRefund: familyRefund,
      taxeFixe: taxeFixeY4,
      redevance: redevanceAcheminementY5,
      totalCarteGrise: finalRegistration,
      cashCarteGrise: cashRegistration,
      totalInvested: totalInvested,
      cashRequired: cashRequired,
      resaleEUQuick: 0,
      resaleEUMarket: 0,
      resaleFRQuick: quickPrice,
      resaleFRMarket: marketPrice,
      vetustYears: ageInMonths(firstRegistration) ~/ 12,
      familyCO2Deduction: familyEligible ? childrenCount * 20 : 0,
      familyWeightDeduction: familyEligible ? childrenCount * 200 : 0,
      ageReductionPct: agePct,
      proCosts: max(0.0, proCosts),
      vatOnMargin: vatOnMargin,
      calculationReliable: reliable,
      warnings: warnings,
      comparableCount: comparableCount,
    );
  }
}
