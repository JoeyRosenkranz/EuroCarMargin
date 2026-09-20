import 'package:eurocar_margin/models/car_listing.dart';
import 'package:eurocar_margin/services/vehicle_specs_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

CarListing listing(
  String id, {
  int? co2,
  int? weight,
  int year = 2024,
  int powerKW = 110,
}) {
  return CarListing(
    id: id,
    title: 'Volkswagen Golf 1.5 TSI',
    brand: 'Volkswagen',
    model: 'Golf',
    price: 20000,
    priceFormatted: '20 000 €',
    year: year,
    fuel: 'Benzin',
    powerKW: powerKW,
    co2: co2,
    weightG1: weight,
    detailUrl: '/$id',
  );
}

void main() {
  final resolver = VehicleSpecsResolver();

  test('complète depuis deux moteurs strictement identiques concordants', () {
    final target = listing('target');
    final result = resolver.resolve(target, [
      target,
      listing('a', co2: 128, weight: 1425),
      listing('b', co2: 128, weight: 1425),
    ]);
    expect(result.co2, 128);
    expect(result.weightG1, 1425);
    expect(result.technicalSource, contains('Consensus moteur'));
  });

  test('refuse une valeur ambiguë ou issue d’une autre motorisation', () {
    final target = listing('target');
    final result = resolver.resolve(target, [
      target,
      listing('a', co2: 128, weight: 1425),
      listing('b', co2: 140, weight: 1500),
      listing('other-engine', co2: 128, weight: 1425, powerKW: 96),
    ]);
    expect(result.co2, isNull);
    expect(result.weightG1, isNull);
  });
}
