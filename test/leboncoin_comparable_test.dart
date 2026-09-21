import 'package:eurocar_margin/models/car_listing.dart';
import 'package:eurocar_margin/services/leboncoin_service.dart';
import 'package:flutter_test/flutter_test.dart';

CarListing target({
  required String title,
  required String brand,
  required String model,
  required int year,
  required String fuel,
  int mileage = 50000,
}) =>
    CarListing(
      id: 'target',
      title: title,
      brand: brand,
      model: model,
      price: 30000,
      priceFormatted: '30 000 €',
      mileage: mileage,
      year: year,
      fuel: fuel,
      powerKW: 250,
      detailUrl: '/target',
    );

LeBonCoinListing ad(
  String title,
  int year,
  int mileage,
  String fuel,
  double price,
) =>
    LeBonCoinListing(
      title: title,
      year: year,
      mileage: mileage,
      fuel: fuel,
      price: price,
    );

void main() {
  test('comparables français stricts: année, énergie et version électrique', () {
    final result = LeBonCoinPriceResult(
      quick: 0,
      market: 0,
      premium: 0,
      count: 6,
      listings: [
        ad('Tesla Model 3 Long Range', 2022, 45000, 'Electrique', 32000),
        ad('Tesla Model 3 Grande Autonomie', 2022, 52000, 'Électrique', 34000),
        ad('Tesla Model 3 Long Range AWD', 2022, 58000, 'Electrique', 36000),
        ad('Tesla Model 3 Performance', 2022, 50000, 'Electrique', 39000),
        ad('Tesla Model 3 Long Range', 2021, 50000, 'Electrique', 30000),
        ad('Tesla Model 3 Long Range', 2022, 50000, 'Essence', 10000),
      ],
    );

    final comparable = result.comparableFor(
      target(
        title: 'Tesla Model 3 Long Range AWD',
        brand: 'Tesla',
        model: 'Model 3',
        year: 2022,
        fuel: 'Elektro',
      ),
    );

    expect(comparable.count, 3);
    expect(comparable.market, 34000);
    expect(comparable.isReliable, isTrue);
  });

  test('une électrique sans version identifiable ne produit aucune marge', () {
    final result = LeBonCoinPriceResult(
      quick: 30000,
      market: 32000,
      premium: 34000,
      count: 3,
      listings: [
        ad('Tesla Model 3', 2022, 50000, 'Electrique', 32000),
      ],
    );

    final comparable = result.comparableFor(
      target(
        title: 'Tesla Model 3',
        brand: 'Tesla',
        model: 'Model 3',
        year: 2022,
        fuel: 'Elektro',
      ),
    );

    expect(comparable.count, 0);
  });

  test('propose un prix indicatif année ±1 quand le strict est insuffisant', () {
    final result = LeBonCoinPriceResult(
      quick: 0,
      market: 0,
      premium: 0,
      count: 2,
      listings: [
        ad('Audi RS3 Sportback quattro', 2021, 62000, 'Essence', 49500),
        ad('Audi RS3 Sportback quattro', 2023, 48000, 'Essence', 55000),
      ],
    );

    final comparable = result.comparableFor(
      target(
        title: 'Audi RS3 Sportback quattro',
        brand: 'Audi',
        model: 'RS3',
        year: 2022,
        fuel: 'Benzin',
        mileage: 55000,
      ),
    );

    expect(comparable.hasEstimate, isTrue);
    expect(comparable.approximate, isTrue);
    expect(comparable.isReliable, isFalse);
    expect(comparable.market, 52250);
  });
}
