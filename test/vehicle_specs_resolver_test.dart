import 'package:eurocar_margin/models/car_listing.dart';
import 'package:eurocar_margin/services/vehicle_specs_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

CarListing listing(
  String id, {
  int? co2,
  int? weight,
  int year = 2024,
  int? powerKW = 110,
  int? powerPS,
  String marketplace = 'AutoScout24',
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
    powerPS: powerPS,
    co2: co2,
    weightG1: weight,
    detailUrl: '/$id',
    marketplace: marketplace,
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

  test('retrouve le même moteur via les chevaux si les kW sont absents', () {
    final target = listing('target', powerKW: null, powerPS: 400);
    final result = resolver.resolve(target, [
      target,
      listing(
        'a',
        powerKW: null,
        powerPS: 400,
        co2: 208,
        marketplace: 'AutoScout24',
      ),
      listing(
        'b',
        powerKW: null,
        powerPS: 401,
        co2: 208,
        marketplace: 'mobile.de',
      ),
    ]);

    expect(result.co2, 208);
    expect(result.technicalSource, contains('2 source(s)'));
  });
}
