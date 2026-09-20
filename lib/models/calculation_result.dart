import 'vehicle_model.dart';

/// Niveaux de risque
enum RiskLevel {
  green, // marge >= 20 %
  orange, // marge 10-20 %
  red; // marge < 10 %

  String get label {
    switch (this) {
      case RiskLevel.green:
        return 'Rentable';
      case RiskLevel.orange:
        return 'Modéré';
      case RiskLevel.red:
        return 'Risqué';
    }
  }
}

/// Résultat complet du calcul de rentabilité
class CalculationResult {
  final VehicleEntry vehicle;

  // Carte grise decomposition
  final double taxeRegionale; // Y1
  final double malusCO2; // Y3 (après vétusté)
  final double malusCO2BeforeVetuste; // Y3 avant vétusté
  final double malusPoids; // TMOM
  final double taxeFixe; // Y4
  final double redevance; // Y5
  final double totalCarteGrise;

  // Totaux
  final double totalInvested;

  // Revente estimée (Europe / Base AutoScout)
  final double resaleEUQuick;
  final double resaleEUMarket;

  // Revente estimée (France / LeBonCoin)
  final double resaleFRQuick;
  final double resaleFRMarket;

  // Bénéfices bruts (avant frais pro et TVA)
  double get grossProfitEUQuick => resaleEUQuick - totalInvested;
  double get grossProfitEUMarket => resaleEUMarket - totalInvested;
  double get grossProfitFRQuick => resaleFRQuick - totalInvested;
  double get grossProfitFRMarket => resaleFRMarket - totalInvested;

  // TVA sur marge calculée spécifiquement : [(Prix Revente TTC - Prix Achat TTC) / 1,20] * 0,20
  double _calcTva(double resale) {
    if (resale <= totalInvested) return 0;
    return ((resale - totalInvested) / 1.20) * 0.20;
  }

  double get tvaMarginEUQuick => _calcTva(resaleEUQuick);
  double get tvaMarginEUMarket => _calcTva(resaleEUMarket);
  double get tvaMarginFRQuick => _calcTva(resaleFRQuick);
  double get tvaMarginFRMarket => _calcTva(resaleFRMarket);

  // Frais professionnels
  final double proCosts;

  // Bénéfices Nets finaux (après TVA et frais pro)
  double get profitEUQuick => grossProfitEUQuick - tvaMarginEUQuick - proCosts;
  double get profitEUMarket => grossProfitEUMarket - tvaMarginEUMarket - proCosts;
  double get profitFRQuick => grossProfitFRQuick - tvaMarginFRQuick - proCosts;
  double get profitFRMarket => grossProfitFRMarket - tvaMarginFRMarket - proCosts;

  // Marges (%)
  double get marginEUQuick => totalInvested > 0 ? (profitEUQuick / totalInvested) * 100 : 0;
  double get marginEUMarket => totalInvested > 0 ? (profitEUMarket / totalInvested) * 100 : 0;
  double get marginFRQuick => totalInvested > 0 ? (profitFRQuick / totalInvested) * 100 : 0;
  double get marginFRMarket => totalInvested > 0 ? (profitFRMarket / totalInvested) * 100 : 0;

  // Risque basé sur la marge FR marché prioritairement
  RiskLevel get riskLevel {
    final margin = marginFRMarket > 0 ? marginFRMarket : marginEUMarket;
    if (margin >= 20) return RiskLevel.green;
    if (margin >= 10) return RiskLevel.orange;
    return RiskLevel.red;
  }

  // Vétusté appliquée (nombre d'années)
  final int vetustYears;

  // Abattements explicites pour l'affichage
  final int familyCO2Deduction;
  final int familyWeightDeduction;
  final int ageReductionPct;

  const CalculationResult({
    required this.vehicle,
    required this.taxeRegionale,
    required this.malusCO2,
    required this.malusCO2BeforeVetuste,
    required this.malusPoids,
    required this.taxeFixe,
    required this.redevance,
    required this.totalCarteGrise,
    required this.totalInvested,
    required this.resaleEUQuick,
    required this.resaleEUMarket,
    required this.resaleFRQuick,
    required this.resaleFRMarket,
    required this.vetustYears,
    this.familyCO2Deduction = 0,
    this.familyWeightDeduction = 0,
    this.ageReductionPct = 0,
    this.proCosts = 1500.0,
  });

  Map<String, dynamic> toMap() => {
        ...vehicle.toMap(),
        'taxe_regionale': taxeRegionale,
        'malus_co2': malusCO2,
        'malus_co2_before_vetuste': malusCO2BeforeVetuste,
        'malus_poids': malusPoids,
        'total_carte_grise': totalCarteGrise,
        'total_invested': totalInvested,
        'resale_quick': resaleEUQuick, // Keep standard names for legacy compatibility
        'resale_market': resaleEUMarket, 
        'resale_fr_quick': resaleFRQuick,
        'resale_fr_market': resaleFRMarket,
        'pro_costs': proCosts,
        'risk_level': riskLevel.name,
        'vetust_years': vetustYears,
        'family_co2_deduction': familyCO2Deduction,
        'family_weight_deduction': familyWeightDeduction,
      };
}
