import 'package:eurocar_margin/models/vehicle_model.dart';
import 'package:eurocar_margin/services/tax_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('barèmes import 2026', () {
    final calculator = TaxCalculator(registrationDate: DateTime(2026, 9, 19));

    test('barème CO2 2026 et plafond', () {
      expect(
        calculator.calcMalusCO2(
          108,
          2026,
          firstRegistrationMonth: 9,
          model: 'Golf',
        ),
        50,
      );
      expect(
        calculator.calcMalusCO2(
          192,
          2026,
          firstRegistrationMonth: 9,
          model: 'Golf',
        ),
        80000,
      );
    });

    test('décote légale par mois', () {
      expect(calculator.ageReductionPercent(DateTime(2026, 8, 1)), 3);
      expect(calculator.ageReductionPercent(DateTime(2025, 9, 1)), 16);
      expect(calculator.ageReductionPercent(DateTime(2011, 8, 1)), 100);
    });

    test('malus masse progressif 2026', () {
      expect(
        calculator.calcMalusPoids(
          1500,
          anneeImmat: 2026,
          firstRegistrationMonth: 9,
          model: 'Golf',
        ),
        10,
      );
      expect(
        calculator.calcMalusPoids(
          1700,
          anneeImmat: 2026,
          firstRegistrationMonth: 9,
          model: 'Golf',
        ),
        2015,
      );
    });

    test('seuil masse confirmé par le simulateur officiel', () {
      final officialCase = TaxCalculator(
        registrationDate: DateTime(2025, 9, 1),
      );
      expect(
        officialCase.calcMalusPoids(
          1600,
          anneeImmat: 2025,
          firstRegistrationMonth: 9,
          model: 'Véhicule témoin',
        ),
        10,
      );
      // Avec la date exacte du cas officiel (01/09/2025 -> 20/09/2026),
      // la décote est de 16 % : 10 € deviennent 8,40 €.
      expect(
        calculator.ageReductionPercent(DateTime(2025, 9, 1)),
        16,
      );
    });

    test('hybride rechargeable 2024 exonéré du malus masse', () {
      expect(
        calculator.calcMalusPoids(
          2200,
          anneeImmat: 2024,
          firstRegistrationMonth: 12,
          fuelType: 'Hybride rechargeable',
          model: 'SUV PHEV',
        ),
        0,
      );
    });

    test('demi-tarif régional seulement après dix ans révolus', () {
      final exactCalculator = TaxCalculator(
        registrationDate: DateTime(2026, 9, 19),
      );
      expect(
        exactCalculator.calcTaxeRegionale(
          'Grand Est',
          10,
          2016,
          firstRegistrationMonth: 10,
          model: 'Golf',
        ),
        600,
      );
      expect(
        exactCalculator.calcTaxeRegionale(
          'Grand Est',
          10,
          2016,
          firstRegistrationMonth: 8,
          model: 'Golf',
        ),
        300,
      );
    });

    test('famille: avance complète puis remboursement', () {
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
      expect(result.familyCO2Deduction, 60);
      expect(result.familyWeightDeduction, 600);
      expect(result.familyRefund, greaterThan(0));
      expect(result.cashRequired, greaterThan(result.totalInvested));
    });
  });
}
