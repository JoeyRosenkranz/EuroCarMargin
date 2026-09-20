import 'vehicle_model.dart';

enum RiskLevel {
  green,
  orange,
  red;

  String get label => switch (this) {
    RiskLevel.green => 'Rentable',
    RiskLevel.orange => 'A verifier',
    RiskLevel.red => 'Risque eleve',
  };
}

/// Resultat financier. Les couts de tresorerie et le cout economique final sont
/// volontairement separes : l'avantage famille nombreuse est rembourse apres
/// l'immatriculation, il ne diminue donc pas la somme a avancer.
class CalculationResult {
  final VehicleEntry vehicle;

  final double taxeRegionale;
  final double malusCO2;
  final double malusCO2BeforeVetuste;
  final double malusPoids;
  final double cashMalusCO2;
  final double cashMalusPoids;
  final double familyRefund;
  final double taxeFixe;
  final double redevance;
  final double totalCarteGrise;
  final double cashCarteGrise;

  /// Cout apres remboursement eventuel, hors frais professionnels.
  final double totalInvested;

  /// Somme a decaisser avant le remboursement famille nombreuse.
  final double cashRequired;

  final double resaleEUQuick;
  final double resaleEUMarket;
  final double resaleFRQuick;
  final double resaleFRMarket;

  final double proCosts;
  final bool vatOnMargin;
  final bool calculationReliable;
  final List<String> warnings;
  final int comparableCount;

  double get grossProfitEUQuick => resaleEUQuick - totalInvested;
  double get grossProfitEUMarket => resaleEUMarket - totalInvested;
  double get grossProfitFRQuick => resaleFRQuick - totalInvested;
  double get grossProfitFRMarket => resaleFRMarket - totalInvested;

  /// TVA sur marge : (prix de vente TTC - prix d'achat TTC) x 20/120.
  /// Le regime ne s'applique que si l'achat ouvre droit au regime de la marge.
  double _calcTva(double resale) {
    if (!vatOnMargin || resale <= vehicle.purchasePrice) return 0;
    return (resale - vehicle.purchasePrice) / 6;
  }

  double get tvaMarginEUQuick => _calcTva(resaleEUQuick);
  double get tvaMarginEUMarket => _calcTva(resaleEUMarket);
  double get tvaMarginFRQuick => _calcTva(resaleFRQuick);
  double get tvaMarginFRMarket => _calcTva(resaleFRMarket);

  double get profitEUQuick => grossProfitEUQuick - tvaMarginEUQuick - proCosts;
  double get profitEUMarket =>
      grossProfitEUMarket - tvaMarginEUMarket - proCosts;
  double get profitFRQuick => grossProfitFRQuick - tvaMarginFRQuick - proCosts;
  double get profitFRMarket =>
      grossProfitFRMarket - tvaMarginFRMarket - proCosts;

  double get marginEUQuick =>
      totalInvested > 0 ? (profitEUQuick / totalInvested) * 100 : 0;
  double get marginEUMarket =>
      totalInvested > 0 ? (profitEUMarket / totalInvested) * 100 : 0;
  double get marginFRQuick =>
      totalInvested > 0 ? (profitFRQuick / totalInvested) * 100 : 0;
  double get marginFRMarket =>
      totalInvested > 0 ? (profitFRMarket / totalInvested) * 100 : 0;

  RiskLevel get riskLevel {
    if (!calculationReliable || resaleFRMarket <= 0) return RiskLevel.red;
    if (marginFRMarket >= 15 && comparableCount >= 3) return RiskLevel.green;
    if (marginFRMarket >= 7) return RiskLevel.orange;
    return RiskLevel.red;
  }

  final int vetustYears;
  final int familyCO2Deduction;
  final int familyWeightDeduction;
  final int ageReductionPct;

  const CalculationResult({
    required this.vehicle,
    required this.taxeRegionale,
    required this.malusCO2,
    required this.malusCO2BeforeVetuste,
    required this.malusPoids,
    required this.cashMalusCO2,
    required this.cashMalusPoids,
    required this.familyRefund,
    required this.taxeFixe,
    required this.redevance,
    required this.totalCarteGrise,
    required this.cashCarteGrise,
    required this.totalInvested,
    required this.cashRequired,
    required this.resaleEUQuick,
    required this.resaleEUMarket,
    required this.resaleFRQuick,
    required this.resaleFRMarket,
    required this.vetustYears,
    this.familyCO2Deduction = 0,
    this.familyWeightDeduction = 0,
    this.ageReductionPct = 0,
    this.proCosts = 1500.0,
    this.vatOnMargin = true,
    this.calculationReliable = true,
    this.warnings = const [],
    this.comparableCount = 0,
  });

  Map<String, dynamic> toMap() => {
    ...vehicle.toMap(),
    'taxe_regionale': taxeRegionale,
    'malus_co2': malusCO2,
    'malus_co2_before_vetuste': malusCO2BeforeVetuste,
    'malus_poids': malusPoids,
    'cash_malus_co2': cashMalusCO2,
    'cash_malus_poids': cashMalusPoids,
    'family_refund': familyRefund,
    'total_carte_grise': totalCarteGrise,
    'cash_carte_grise': cashCarteGrise,
    'total_invested': totalInvested,
    'cash_required': cashRequired,
    'resale_quick': resaleEUQuick,
    'resale_market': resaleEUMarket,
    'resale_fr_quick': resaleFRQuick,
    'resale_fr_market': resaleFRMarket,
    'profit_quick': profitFRQuick,
    'profit_market': profitFRMarket,
    'pro_costs': proCosts,
    'vat_on_margin': vatOnMargin ? 1 : 0,
    'risk_level': riskLevel.name,
    'vetust_years': vetustYears,
    'family_co2_deduction': familyCO2Deduction,
    'family_weight_deduction': familyWeightDeduction,
    'age_reduction_pct': ageReductionPct,
    'calculation_reliable': calculationReliable ? 1 : 0,
    'comparable_count': comparableCount,
  };
}
