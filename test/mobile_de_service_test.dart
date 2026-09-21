import 'package:eurocar_margin/services/mobile_de_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse une annonce mobile.de avec année, km, puissance et image', () {
    const html = '''
      <html><body>
        <article data-testid="listing-card">
          <a href="/fahrzeuge/details.html?id=123456">
            <h2>Audi RS3 Sportback quattro</h2>
          </a>
          <div>49.990 €</div>
          <span>EZ 06/2021</span>
          <span>58.400 km</span>
          <span>294 kW (400 PS)</span>
          <span>Benzin</span>
          <img src="https://img.classistatic.de/api/v1/mo-prod/images/aa/320x240.jpg" />
        </article>
      </body></html>
    ''';

    final listings = MobileDeService.parseSearchHtml(
      html,
      brand: 'Audi',
      model: 'RS3',
    );

    expect(listings, hasLength(1));
    expect(listings.single.marketplace, 'mobile.de');
    expect(listings.single.year, 2021);
    expect(listings.single.firstRegistrationMonth, 6);
    expect(listings.single.mileage, 58400);
    expect(listings.single.powerKW, 294);
    expect(listings.single.powerPS, 400);
    expect(listings.single.absoluteDetailUrl, contains('suchen.mobile.de'));
    expect(listings.single.imageUrls.single, contains('1600x1200'));
  });

  test('construit une recherche mobile.de triée du prix bas au prix haut', () {
    final uri = MobileDeService().buildSearchUri(
      brand: 'Audi',
      model: 'RS3',
      priceFrom: 20000,
      priceTo: 60000,
      yearFrom: 2018,
      yearTo: 2024,
      kmTo: 100000,
    );

    expect(uri.queryParameters['kw'], 'Audi RS3');
    expect(uri.queryParameters['p'], '20000:60000');
    expect(uri.queryParameters['fr'], '2018:2024');
    expect(uri.queryParameters['ml'], ':100000');
    expect(uri.queryParameters['sb'], 'p');
    expect(uri.queryParameters['od'], 'up');
  });
}
