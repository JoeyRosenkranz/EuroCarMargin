import 'package:eurocar_margin/models/car_listing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estime les CV pré-2020 avec kW et CO2 au lieu de retourner zéro', () {
    const rs3 = CarListing(
      id: 'rs3',
      title: 'Audi RS 3 2.5 TFSI quattro',
      brand: 'Audi',
      model: 'RS 3',
      price: 35000,
      priceFormatted: '35 000 €',
      mileage: 80000,
      year: 2017,
      fuel: 'Benzin',
      powerKW: 294,
      co2: 189,
      detailUrl: '/rs3',
    );

    expect(rs3.estimatedFiscalPower, greaterThan(0));
    expect(rs3.toVehicleEntry(region: 'Grand Est').powerFiscal, greaterThan(0));
  });
}
