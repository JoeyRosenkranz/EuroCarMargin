import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/car_listing.dart';

/// Recherche publique sur mobile.de.
///
/// Le parseur privilégie les données structurées puis utilise le DOM comme
/// repli. Si mobile.de refuse une requête, l'agrégateur conserve les résultats
/// AutoScout24 au lieu de faire échouer toute la recherche.
class MobileDeService {
  static const _baseUrl = 'https://suchen.mobile.de';
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  final http.Client _client;

  MobileDeService({http.Client? client}) : _client = client ?? http.Client();

  Uri buildSearchUri({
    required String brand,
    String? model,
    int? priceFrom,
    int? priceTo,
    int? yearFrom,
    int? yearTo,
    int? kmTo,
    String? fuel,
    int page = 1,
  }) {
    final query = [brand, if (model != null && model.trim().isNotEmpty) model]
        .join(' ');
    return Uri.parse('$_baseUrl/fahrzeuge/search.html').replace(
      queryParameters: {
        'vc': 'Car',
        'dam': '0',
        'isSearchRequest': 'true',
        'sb': 'p',
        'od': 'up',
        'kw': query,
        if (priceFrom != null || priceTo != null)
          'p': '${priceFrom ?? ''}:${priceTo ?? ''}',
        if (yearFrom != null || yearTo != null)
          'fr': '${yearFrom ?? ''}:${yearTo ?? ''}',
        if (kmTo != null) 'ml': ':$kmTo',
        if (fuel != null && fuel.isNotEmpty) 'ft': fuel,
        if (page > 1) 'pageNumber': '$page',
      },
    );
  }

  Future<List<CarListing>> searchListings({
    required String brand,
    String? model,
    int? priceFrom,
    int? priceTo,
    int? yearFrom,
    int? yearTo,
    int? kmTo,
    String? fuel,
    int page = 1,
  }) async {
    final uri = buildSearchUri(
      brand: brand,
      model: model,
      priceFrom: priceFrom,
      priceTo: priceTo,
      yearFrom: yearFrom,
      yearTo: yearTo,
      kmTo: kmTo,
      fuel: fuel,
      page: page,
    );
    final requestUri = kIsWeb
        ? Uri.parse('https://corsproxy.io/?${Uri.encodeComponent('$uri')}')
        : uri;
    final response = await _client.get(requestUri, headers: _headers());
    if (response.statusCode != 200) {
      throw Exception('mobile.de returned ${response.statusCode}');
    }
    return parseSearchHtml(response.body, brand: brand, model: model ?? '');
  }

  Future<CarListing> enrichListing(CarListing listing) async {
    if (listing.detailUrl.isEmpty || listing.hasRequiredTechnicalData) {
      return listing;
    }
    final uri = Uri.tryParse(listing.absoluteDetailUrl);
    if (uri == null) return listing;
    final requestUri = kIsWeb
        ? Uri.parse('https://corsproxy.io/?${Uri.encodeComponent('$uri')}')
        : uri;
    try {
      final response = await _client.get(requestUri, headers: _headers());
      if (response.statusCode != 200) return listing;
      final document = html_parser.parse(response.body);
      final text = _normalize(document.body?.text ?? '');
      final registration = RegExp(
        r'(?:EZ|Erstzulassung)[^0-9]{0,30}(\d{1,2})[./-](\d{4})',
        caseSensitive: false,
      ).firstMatch(text);
      final power = RegExp(
        r'(\d{1,4})\s*kW(?:\s*\((\d{1,4})\s*PS\))?',
        caseSensitive: false,
      ).firstMatch(text);
      final images = document
          .querySelectorAll('img')
          .map(_bestImageUrl)
          .where((url) => url.isNotEmpty)
          .toSet()
          .take(20)
          .toList();

      final powerKW = int.tryParse(power?.group(1) ?? '');
      return listing.copyWith(
        mileage: _number(
          text,
          r'(\d{1,3}(?:[.\s]\d{3}){1,2}|\d{1,6})\s*km',
        ),
        year: int.tryParse(registration?.group(2) ?? ''),
        firstRegistrationMonth:
            int.tryParse(registration?.group(1) ?? ''),
        powerKW: powerKW,
        powerPS: int.tryParse(power?.group(2) ?? '') ??
            (powerKW == null ? null : (powerKW * 1.35962).round()),
        co2: _number(
          text,
          r'(?:CO₂|CO2)[^0-9]{0,100}(\d{1,3})\s*g/km',
        ),
        weightG1: _validWeight(
          _number(
            text,
            r'(?:Leergewicht|Masse in fahrbereitem Zustand)[^0-9]{0,80}([\d.\s]{3,8})\s*kg',
          ),
        ),
        seats: _number(
          text,
          r'(?:Sitzplätze|Anzahl Sitzplätze)[^0-9]{0,30}(\d{1,2})',
        ),
        electricRangeKm: _number(
          text,
          r'(?:Elektrische Reichweite|Reichweite elektrisch)[^0-9]{0,80}(\d{1,4})\s*km',
        ),
        imageUrls: images.isEmpty ? listing.imageUrls : images,
        description: text.isEmpty
            ? listing.description
            : text.substring(0, text.length > 20000 ? 20000 : text.length),
        technicalSource: 'Fiche mobile.de',
        marketplace: 'mobile.de',
      );
    } catch (_) {
      return listing;
    }
  }

  /// Visible pour les tests afin de détecter les changements de structure du
  /// site sans effectuer de requête réseau.
  static List<CarListing> parseSearchHtml(
    String html, {
    required String brand,
    required String model,
  }) {
    final document = html_parser.parse(html);
    final listings = <CarListing>[];
    final seenUrls = <String>{};

    for (final script in document.querySelectorAll('script[type="application/ld+json"]')) {
      try {
        final decoded = json.decode(script.text);
        _collectJsonLd(decoded, listings, seenUrls, brand, model);
      } catch (_) {
        // Le DOM reste disponible si un bloc JSON-LD est partiellement invalide.
      }
    }

    final candidates = document.querySelectorAll(
      'article, [data-testid*="listing"], [class*="result-item"], '
      '[class*="ResultItem"], [class*="cBox-body--resultitem"]',
    );
    for (final element in candidates) {
      final link = element.querySelector(
        'a[href*="/fahrzeuge/details.html"], a[href*="details.html?id="]',
      );
      if (link == null) continue;
      final href = link.attributes['href'] ?? '';
      if (href.isEmpty || !seenUrls.add(href)) continue;
      final text = _normalize(element.text);
      final title = _firstText(element, const [
        '[data-testid*="headline"]',
        '[class*="headline"]',
        'h2',
        'h3',
      ]);
      final price = _price(text);
      if (price <= 0) continue;
      final registration = RegExp(
        r'(?:EZ|Erstzulassung)[^0-9]{0,20}(\d{1,2})[./-](\d{4})',
        caseSensitive: false,
      ).firstMatch(text);
      final power = RegExp(
        r'(\d{1,4})\s*kW(?:\s*\((\d{1,4})\s*PS\))?',
        caseSensitive: false,
      ).firstMatch(text);
      final image = element.querySelector('img');
      final imageUrl = image == null ? '' : _bestImageUrl(image);

      listings.add(
        CarListing(
          id: 'mobile-${Uri.tryParse(href)?.queryParameters['id'] ?? href.hashCode}',
          title: title.isEmpty ? '$brand $model'.trim() : title,
          brand: brand,
          model: model,
          price: price,
          priceFormatted: '${price.round()} €',
          mileage: _number(
            text,
            r'(\d{1,3}(?:[.\s]\d{3}){1,2}|\d{1,6})\s*km',
          ),
          year: int.tryParse(registration?.group(2) ?? ''),
          firstRegistrationMonth:
              int.tryParse(registration?.group(1) ?? ''),
          fuel: _fuel(text),
          powerKW: int.tryParse(power?.group(1) ?? ''),
          powerPS: int.tryParse(power?.group(2) ?? ''),
          imageUrls: imageUrl.isEmpty ? const [] : [imageUrl],
          detailUrl: href,
          location: _location(text),
          technicalSource: 'Annonce mobile.de',
          marketplace: 'mobile.de',
        ),
      );
    }
    return listings;
  }

  static void _collectJsonLd(
    dynamic node,
    List<CarListing> output,
    Set<String> seenUrls,
    String brand,
    String model,
  ) {
    if (node is List) {
      for (final item in node) {
        _collectJsonLd(item, output, seenUrls, brand, model);
      }
      return;
    }
    if (node is! Map) return;
    if (node['itemListElement'] != null) {
      _collectJsonLd(node['itemListElement'], output, seenUrls, brand, model);
    }
    if (node['item'] != null) {
      _collectJsonLd(node['item'], output, seenUrls, brand, model);
    }
    final type = node['@type']?.toString().toLowerCase() ?? '';
    if (!type.contains('product') && !type.contains('vehicle') &&
        !type.contains('car')) {
      return;
    }
    final offers = node['offers'] is Map ? node['offers'] as Map : const {};
    final price = double.tryParse(
          offers['price']?.toString() ?? node['price']?.toString() ?? '',
        ) ??
        0;
    final url = node['url']?.toString() ?? '';
    if (price <= 0 || url.isEmpty || !seenUrls.add(url)) return;
    final imageNode = node['image'];
    final images = imageNode is List
        ? imageNode.map((value) => value.toString()).toList()
        : imageNode == null
        ? <String>[]
        : [imageNode.toString()];
    output.add(
      CarListing(
        id: 'mobile-${url.hashCode}',
        title: node['name']?.toString() ?? '$brand $model',
        brand: brand,
        model: model,
        price: price,
        priceFormatted: '${price.round()} €',
        imageUrls: images.map(_upgradeImage).toList(),
        detailUrl: url,
        technicalSource: 'Annonce mobile.de',
        marketplace: 'mobile.de',
      ),
    );
  }

  static Map<String, String> _headers() => const {
    'User-Agent': _userAgent,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'de-DE,de;q=0.9,en;q=0.5',
  };

  static String _normalize(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _firstText(Element element, List<String> selectors) {
    for (final selector in selectors) {
      final text = element.querySelector(selector)?.text.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static double _price(String text) {
    final match = RegExp(
      r'(\d{1,3}(?:[.\s]\d{3})+|\d{4,6})\s*€',
    ).firstMatch(text);
    return double.tryParse(
          (match?.group(1) ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
  }

  static int? _number(String text, String expression) {
    final raw = RegExp(expression, caseSensitive: false).firstMatch(text)?.group(1);
    if (raw == null) return null;
    return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  static int? _validWeight(int? value) =>
      value != null && value >= 500 && value <= 5000 ? value : null;

  static String? _fuel(String text) {
    const fuels = [
      'Plug-in-Hybrid',
      'Hybrid',
      'Elektro',
      'Diesel',
      'Benzin',
      'Erdgas',
      'Autogas',
    ];
    for (final fuel in fuels) {
      if (text.toLowerCase().contains(fuel.toLowerCase())) return fuel;
    }
    return null;
  }

  static String? _location(String text) {
    final match = RegExp(r'\b(D-)?\d{5}\s+[A-ZÄÖÜ][A-Za-zÄÖÜäöüß -]+')
        .firstMatch(text);
    return match?.group(0)?.trim();
  }

  static String _bestImageUrl(Element image) {
    final srcSet = image.attributes['srcset'] ?? '';
    final candidates = srcSet
        .split(',')
        .map((entry) => entry.trim().split(RegExp(r'\s+')).first)
        .where((url) => url.isNotEmpty)
        .toList();
    final url = candidates.isNotEmpty
        ? candidates.last
        : image.attributes['data-src'] ?? image.attributes['src'] ?? '';
    return _upgradeImage(url);
  }

  static String _upgradeImage(String value) {
    var url = value.startsWith('//') ? 'https:$value' : value;
    url = url.replaceAll(r'$_20.', r'$_57.');
    return url.replaceAllMapped(
      RegExp(r'/(\d{2,4})x(\d{2,4})(?=[./][^/]*$)'),
      (_) => '/1600x1200',
    );
  }

  void dispose() => _client.close();
}
