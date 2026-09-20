import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/tax_data.dart';
import '../models/vehicle_model.dart';
import '../models/calculation_result.dart';

/// Moteur de calcul fiscal 2026 — 100% offline
class TaxCalculator {
  bool _isEV(String? fuel, String model) {
    if (model.toLowerCase().contains('e-tron') || model.toLowerCase().contains('tesla')) return true;
    if (fuel == null) return false;
    final f = fuel.toLowerCase();
    return f == 'elektro' || f == 'electric' || f == 'électrique' || f.contains('électrique');
  }

  bool _isPHEV(String? fuel) {
    if (fuel == null) return false;
    final f = fuel.toLowerCase();
    return f.contains('plug-in') || f.contains('phev') || f.contains('rechargeable');
  }

  double calcTaxeRegionale(String region, int puissanceFiscale, int anneeImmat, {String? fuelType, required String model}) {
    if (_isEV(fuelType, model)) return 0.0;
    
    final prixCV = regionalTaxPerCV[region] ?? 50.0;
    final age = DateTime.now().year - anneeImmat;
    
    // LOGIQUE IMPOSÉE : Si voiture > 10 ans, réduction de 50%
    return (age > 10) ? (puissanceFiscale * prixCV) / 2 : (puissanceFiscale * prixCV.toDouble());
  }

  /// Seuil du malus CO2 historique (approx WLTP/NEDC)
  int _getCO2ThresholdForYear(int annee) {
    if (annee >= 2026) return 108;
    if (annee == 2025) return 118;
    if (annee == 2024) return 118;
    if (annee == 2023) return 123;
    if (annee == 2022) return 128;
    if (annee == 2021) return 133;
    if (annee == 2020) return 138;
    if (annee == 2019) return 117; // NEDC
    if (annee == 2018) return 120;
    return 131; // Fallback NEDC historique
  }

  /// Décalage du Seuil CO2 pour utiliser le barème 2026 comme base relative
  /// Ajusté pour coller aux montants historiques (approximativement)
  int _getCO2ShiftForYear(int annee) {
    if (annee >= 2026) return 0;
    if (annee == 2025) return -5;
    if (annee == 2024) return -10;
    if (annee == 2023) return -12;
    if (annee == 2022) return -15;
    if (annee == 2021) return -18;
    if (annee == 2020) return -25;
    return -35; // Approx NEDC
  }

  double calcMalusCO2(int co2, int anneeImmat, {String? fuelType, required String model, int childrenCount = 0}) {
    if (_isEV(fuelType, model) || _isPHEV(fuelType)) return 0.0;
    
    // LOGIQUE IMPOSÉE : Si familleNombreuse (3+ enfants), retrait de 60g (20g * 3)
    // Note: L'utilisateur a spécifié 'famille ? (co2 - 60) : co2', on applique ce seuil de 3 enfants.
    int co2Final = (childrenCount >= 3) ? (co2 - 60) : co2;
    co2Final = max(0, co2Final);

    // Chercher dans le barème de l'ANNEE de la voiture
    double malusBase = _getHistoricalMalusBase(anneeImmat, co2Final);

    // Appliquer la vétusté de 10% par an (Logique imposée : 1 - (anneesAnciennete * 0.1))
    final anneesAnciennete = _calcVetustYears(anneeImmat);
    return malusBase * (1 - (anneesAnciennete * 0.1));
  }

  /// Recherche exacte du malus historique pour une année et un CO2 donnés
  double _getHistoricalMalusBase(int annee, int co2) {
    int threshold = _getCO2ThresholdForYear(annee);
    if (co2 < threshold) return 0.0;

    if (annee >= 2026) {
      if (co2 >= 192) return malusPlafond.toDouble();
      return (co2MalusBareme[co2] ?? 0).toDouble();
    }

    // Pour les années historiques, on utilise la courbe calibrée (Expert)
    // car le barème complet n'est pas en mémoire pour chaque année.
    final maxM = (historicalMaxMalus[annee] ?? 20000).toDouble();
    final t = threshold.toDouble();
    final co2Max = 215.0; // Point de saturation moyen historique

    if (co2 >= co2Max) return maxM;
    
    final power = (annee >= 2024) ? 3.0 : 2.2;
    return pow((co2 - t) / (co2Max - t), power) * maxM;
  }

  /// Nombre d'années de vétusté (entamées)
  int _calcVetustYears(int anneeImmat) {
    final now = DateTime.now();
    int years = now.year - anneeImmat;
    // "Année entamée" = si on est dans l'année suivante, ça compte
    if (years < 0) years = 0;
    return years;
  }

  /// Malus CO2 brut (avant vétusté) — pour affichage
  double calcMalusCO2BeforeVetuste(int co2, int anneeImmat, {String? fuelType, required String model, int childrenCount = 0}) {
    if (_isEV(fuelType, model) || _isPHEV(fuelType)) return 0.0;
    
    int effectiveCO2 = co2 - (childrenCount * 20);
    if (effectiveCO2 < 0) effectiveCO2 = 0;

    final threshold = historicalCO2Thresholds[anneeImmat] ?? co2MalusThreshold;
    if (effectiveCO2 < threshold) return 0;

    final shift = _getCO2ShiftForYear(anneeImmat);
    final adjustedCO2 = max(0, effectiveCO2 + shift);

    if (adjustedCO2 >= 192) return (historicalMaxMalus[anneeImmat] ?? malusPlafond).toDouble();
    return (co2MalusBareme[adjustedCO2] ?? 0).toDouble();
  }

  /// Malus au Poids (TMOM)
  /// Règle RS3/Famille : -200kg par enfant (si 3+)
  double calcMalusPoids(int poidsG1, {String? fuelType, required String model, int childrenCount = 0}) {
    if (_isEV(fuelType, model)) return 0.0;

    int poidsCalcul = poidsG1;
    debugPrint('DEBUG TMOM: poids initial=$poidsG1, enfants=$childrenCount');

    
    // Abattement PHEV (200kg max 15%)
    if (_isPHEV(fuelType)) {
      int maxAbattement = (poidsG1 * 0.15).round();
      int abattementReel = min(200, maxAbattement);
      poidsCalcul -= abattementReel;
    }
    
    // RÈGLE FAMILLE : -200kg par enfant (3 et +)
    if (childrenCount >= 3) {
      final abattementPoids = childrenCount * 200;
      poidsCalcul -= abattementPoids;
      debugPrint('TMOM DEBUG: Abattement famille -$abattementPoids kg appliqué. Poids calculé: $poidsCalcul');
    }

    if (poidsCalcul <= weightMalusThreshold) {
      debugPrint('TMOM DEBUG: Exonération (poids $poidsCalcul <= seuil $weightMalusThreshold)');
      return 0.0;
    }

    double total = 0;
    for (final bracket in weightMalusBrackets) {
      if (poidsCalcul < bracket.fromKg) break;

      final upperLimit = bracket.toKg == -1 ? poidsCalcul : min(poidsCalcul, bracket.toKg);
      final kgsInBracket = upperLimit - bracket.fromKg + 1;
      if (kgsInBracket > 0) {
        total += kgsInBracket * bracket.euroPerKg;
      }
    }
    debugPrint('TMOM DEBUG: Malus poids final = $total €');
    return total.roundToDouble();
  }

  /// Calcul complet de la Carte Grise
  double calcCarteGrise({
    required String region,
    required int puissanceFiscale,
    required int anneeImmat,
    required int co2,
    required int poidsG1,
    required String model,
    String? fuelType,
    int childrenCount = 0,
  }) {
    final y1 = calcTaxeRegionale(region, puissanceFiscale, anneeImmat, fuelType: fuelType, model: model);
    final y3 = calcMalusCO2(co2, anneeImmat, fuelType: fuelType, model: model, childrenCount: childrenCount);
    final tmom = calcMalusPoids(poidsG1, fuelType: fuelType, model: model, childrenCount: childrenCount);
    // Plafond cumulé malus CO2 + poids
    final malusCumule = min(y3 + tmom, malusPlafond.toDouble());
    return y1 + malusCumule + taxeFixeY4 + redevanceAcheminementY5;
  }

  /// Estimation de prix de revente basée sur le prix d'achat
  /// Simule une comparaison marché (LBC, La Centrale, AutoScout24)
  /// En production, remplacer par un vrai scraping / API
  Map<String, double> estimateResalePrices(VehicleEntry vehicle) {
    // Estimation basée sur le prix d'achat + marge import typique
    // Un véhicule allemand est généralement 15-25% moins cher qu'en France
    final base = vehicle.purchasePrice;
    final age = DateTime.now().year - vehicle.year;

    // Facteur d'augmentation par rapport au prix DE
    // Plus le véhicule est récent, plus la marge est grande
    double factor;
    if (age <= 2) {
      factor = 1.25; // 25% plus cher en France
    } else if (age <= 5) {
      factor = 1.20; // 20% plus cher
    } else if (age <= 8) {
      factor = 1.15; // 15% plus cher
    } else {
      factor = 1.10; // 10% plus cher
    }

    final marketPrice = base * factor;
    return {
      'quick': (marketPrice * 0.90).roundToDouble(), // -10% pour vente rapide
      'market': marketPrice.roundToDouble(),
    };
  }

  /// Calcul complet de la rentabilité (A à Z)
  CalculationResult calculate(VehicleEntry vehicle, {int childrenCount = 0, double? lbcMarketPrice, double? lbcQuickPrice}) {
    final y1 = calcTaxeRegionale(
        vehicle.region, vehicle.powerFiscal, vehicle.year, fuelType: vehicle.fuelType, model: vehicle.model);
    final y3Fixed = calcMalusCO2(vehicle.co2WLTP, vehicle.year, fuelType: vehicle.fuelType, model: vehicle.model, childrenCount: childrenCount);
    // Malus brut pour info
    final y3Brut = calcMalusCO2BeforeVetuste(vehicle.co2WLTP, vehicle.year, fuelType: vehicle.fuelType, model: vehicle.model, childrenCount: childrenCount);
    final tmom = calcMalusPoids(vehicle.weightG1, fuelType: vehicle.fuelType, model: vehicle.model, childrenCount: childrenCount);

    // Plafond cumulé
    final malusCumule = min(y3Fixed + tmom, (historicalMaxMalus[vehicle.year] ?? malusPlafond).toDouble());

    // Frais transport minimum 900€
    final transportCost = max(900.0, vehicle.transportCost);

    final totalCG = y1 + malusCumule + taxeFixeY4 + redevanceAcheminementY5;
    final totalInvested = vehicle.purchasePrice + totalCG + transportCost + vehicle.prepCost;

    // Estimations de revente
    final resale = estimateResalePrices(vehicle);
    final frMarket = lbcMarketPrice ?? 0.0;
    final frQuick = lbcQuickPrice ?? (frMarket > 0 ? frMarket * 0.90 : 0.0);

    return CalculationResult(
      vehicle: vehicle,
      taxeRegionale: y1,
      malusCO2: y3Fixed,
      malusCO2BeforeVetuste: y3Brut,
      malusPoids: tmom,
      taxeFixe: taxeFixeY4,
      redevance: redevanceAcheminementY5,
      totalCarteGrise: totalCG,
      totalInvested: totalInvested,
      resaleEUQuick: resale['quick']!,
      resaleEUMarket: resale['market']!,
      resaleFRQuick: frQuick,
      resaleFRMarket: frMarket,
      vetustYears: _calcVetustYears(vehicle.year),
      familyCO2Deduction: (childrenCount >= 3) ? (childrenCount * 20) : 0,
      familyWeightDeduction: (childrenCount >= 3) ? (childrenCount * 200) : 0,
      ageReductionPct: min(_calcVetustYears(vehicle.year) * 10, 100),
    );
  }
}
