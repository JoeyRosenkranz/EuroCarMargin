import 'package:eurocar_margin/models/vehicle_model.dart';
import 'package:eurocar_margin/services/tax_calculator.dart';

void expectEqual(Object actual, Object expected, String label) {
  if (actual != expected) {
    throw StateError('$label: attendu $expected, obtenu $actual');
  }
}

void expectTrue(bool value, String label) {
  if (!value) throw StateError(label);
}

void main() {
  final calculator = TaxCalculator(registrationDate: DateTime(2026, 9, 19));

  expectEqual(
    calculator.calcMalusCO2(
      108,
      2026,
      firstRegistrationMonth: 9,
      model: 'Golf',
    ),
    50.0,
    'Seuil CO2 2026',
  );
  expectEqual(
    calculator.calcMalusCO2(
      192,
      2026,
      firstRegistrationMonth: 9,
      model: 'Golf',
    ),
    80000.0,
    'Plafond CO2 2026',
  );
  expectEqual(
    calculator.calcMalusCO2(
      167,
      2024,
      firstRegistrationMonth: 12,
      model: 'Golf',
    ),
    5230.0,
    'Barème CO2 2024 avec décote mensuelle',
  );
  expectEqual(
    calculator.calcMalusPoids(
      1700,
      anneeImmat: 2026,
      firstRegistrationMonth: 9,
      model: 'Golf',
    ),
    2015.0,
    'Malus masse progressif 2026',
  );

  final vehicle = VehicleEntry(
    brand: 'Volkswagen',
    model: 'Tiguan',
    year: 2026,
    firstRegistrationMonth: 9,
    powerDIN: 150,
    powerFiscal: 8,
    weightG1: 1800,
    co2WLTP: 150,
    fuelType: 'Essence',
    seats: 5,
    purchasePrice: 25000,
    transportCost: 800,
    prepCost: 500,
    region: 'Grand Est',
    createdAt: DateTime(2026, 9, 19),
  );
  final result = calculator.calculate(
    vehicle,
    childrenCount: 3,
    lbcMarketPrice: 40000,
    comparableCount: 5,
  );
  expectEqual(result.familyCO2Deduction, 60, 'Abattement CO2 famille');
  expectEqual(result.familyWeightDeduction, 600, 'Abattement masse famille');
  expectTrue(
    result.familyRefund > 0,
    'Le remboursement famille doit être positif',
  );
  expectTrue(
    result.cashRequired > result.totalInvested,
    'Le cash à avancer doit dépasser le coût final après remboursement',
  );
  expectTrue(result.calculationReliable, 'Le dossier complet doit être fiable');

  // ignore: avoid_print
  print('Audit fiscal OK: CO2, masse, décote, famille et trésorerie.');
}
