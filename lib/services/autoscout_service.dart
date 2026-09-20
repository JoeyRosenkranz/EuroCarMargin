import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/car_listing.dart';

/// Service de scraping AutoScout24.de
/// Parse les données JSON embarquées via __NEXT_DATA__ (Next.js)
class AutoScoutService {
  static const _baseUrl = 'https://www.autoscout24.de';
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  final http.Client _client;

  AutoScoutService({http.Client? client}) : _client = client ?? http.Client();

  /// Construire l'URL de recherche AutoScout24
  String _buildSearchUrl({
    required String brand,
    String? model,
    int? priceFrom,
    int? priceTo,
    int? yearFrom,
    int? yearTo,
    int? kmTo,
    String? fuel,
    int page = 1,
    String country = 'D', // D = Germany
  }) {
    final slug = model != null && model.isNotEmpty
        ? '/lst/${_slugify(brand)}/${_slugify(model)}'
        : '/lst/${_slugify(brand)}';

    final params = <String, String>{
      'cy': country,
      'atype': 'C', // Cars
      'desc': '0', // Ascending
      'sort': 'standard',
    };

    if (priceFrom != null) params['pricefrom'] = priceFrom.toString();
    if (priceTo != null) params['priceto'] = priceTo.toString();
    if (yearFrom != null) params['fregfrom'] = yearFrom.toString();
    if (yearTo != null) params['fregto'] = yearTo.toString();
    if (kmTo != null) params['kmto'] = kmTo.toString();
    if (fuel != null) params['fuel'] = fuel;
    if (page > 1) params['page'] = page.toString();

    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$_baseUrl$slug?$query';
  }

  /// Rechercher des véhicules sur AutoScout24.de
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
    final url = _buildSearchUrl(
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

    try {
      String finalUrl = url;
      if (kIsWeb) {
        finalUrl = 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
      }

      final response = await _client.get(
        Uri.parse(finalUrl),
        headers: {
          'User-Agent': _userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'de-DE,de;q=0.9,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate',
          'Connection': 'keep-alive',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('AutoScout24 returned ${response.statusCode} for $url');
      }

      return _parseListingsFromHtml(response.body);
    } catch (e) {
      throw Exception('Erreur de recherche AutoScout24: $e');
    }
  }

  /// Charge la fiche complète d'une annonce pour récupérer les caractéristiques
  /// qui ne figurent pas toujours dans la liste de résultats. Aucune valeur
  /// fiscale n'est inventée : en cas d'absence, le champ reste manquant.
  Future<CarListing> enrichListing(CarListing listing) async {
    if (listing.detailUrl.isEmpty || listing.hasRequiredTechnicalData) {
      return listing;
    }

    final detailUrl = listing.detailUrl.startsWith('http')
        ? listing.detailUrl
        : '$_baseUrl${listing.detailUrl.startsWith('/') ? '' : '/'}${listing.detailUrl}';
    final requestUrl = kIsWeb
        ? 'https://corsproxy.io/?${Uri.encodeComponent(detailUrl)}'
        : detailUrl;

    try {
      final response = await _client.get(
        Uri.parse(requestUrl),
        headers: {
          'User-Agent': _userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'de-DE,de;q=0.9,en;q=0.5',
        },
      );
      if (response.statusCode != 200) return listing;

      final document = html_parser.parse(response.body);
      final normalizedText = (document.body?.text ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      int? numberFrom(RegExp expression, {int group = 1}) {
        final value = expression.firstMatch(normalizedText)?.group(group);
        if (value == null) return null;
        return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
      }

      final powerMatch = RegExp(
        r'(?:Leistung|Power)[^0-9]{0,40}(\d{1,4})\s*kW(?:\s*\((\d{1,4})\s*PS\))?',
        caseSensitive: false,
      ).firstMatch(normalizedText);
      final powerKW = powerMatch == null
          ? null
          : int.tryParse(powerMatch.group(1) ?? '');
      final powerPS = powerMatch == null
          ? null
          : int.tryParse(powerMatch.group(2) ?? '');
      final co2 = numberFrom(
        RegExp(
          r'(?:CO₂|CO2)[^0-9]{0,100}(\d{1,3})\s*g/km',
          caseSensitive: false,
        ),
      );
      final weight = numberFrom(
        RegExp(
          r'(?:Leergewicht|Gewicht|vehicle weight)[^0-9]{0,80}([0-9.\s]{3,8})\s*kg',
          caseSensitive: false,
        ),
      );
      final seats = numberFrom(
        RegExp(
          r'(?:Sitzplätze|Anzahl Sitzplätze|seats)[^0-9]{0,40}(\d{1,2})',
          caseSensitive: false,
        ),
      );
      final electricRange = numberFrom(
        RegExp(
          r'(?:Elektrische Reichweite|electric range)[^0-9]{0,80}(\d{1,4})\s*km',
          caseSensitive: false,
        ),
      );
      final registration = RegExp(
        r'(?:Erstzulassung|first registration)[^0-9]{0,30}(\d{1,2})[./-](\d{4})',
        caseSensitive: false,
      ).firstMatch(normalizedText);

      return listing.copyWith(
        powerKW: powerKW,
        powerPS: powerPS ??
            (powerKW == null ? null : (powerKW * 1.35962).round()),
        co2: co2,
        weightG1: weight != null && weight > 500 ? weight : null,
        seats: seats,
        electricRangeKm: electricRange,
        firstRegistrationMonth:
            int.tryParse(registration?.group(1) ?? ''),
        year: int.tryParse(registration?.group(2) ?? ''),
        description: normalizedText.isEmpty
            ? listing.description
            : normalizedText.substring(
                0,
                normalizedText.length > 20000 ? 20000 : normalizedText.length,
              ),
      );
    } catch (_) {
      return listing;
    }
  }

  /// Parse les listings depuis le HTML (via __NEXT_DATA__)
  List<CarListing> _parseListingsFromHtml(String html) {
    final document = html_parser.parse(html);

    // Chercher le script __NEXT_DATA__
    final scriptTags = document.querySelectorAll('script#__NEXT_DATA__');
    if (scriptTags.isEmpty) {
      // Fallback: essayer de parser le HTML directement
      return _parseListingsFromDom(document);
    }

    final jsonStr = scriptTags.first.text;
    final data = json.decode(jsonStr) as Map<String, dynamic>;

    // Navigate: props.pageProps.listings
    final props = data['props'] as Map<String, dynamic>? ?? {};
    final pageProps = props['pageProps'] as Map<String, dynamic>? ?? {};
    final listings = pageProps['listings'] as List<dynamic>? ?? [];

    return listings
        .map((item) {
          try {
            return CarListing.fromAutoScoutJson(item as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<CarListing>()
        .where((l) => l.price > 0)
        .toList();
  }

  /// Fallback: parse les articles HTML directement
  List<CarListing> _parseListingsFromDom(dynamic document) {
    final articles = document.querySelectorAll('article');
    final listings = <CarListing>[];

    for (final article in articles) {
      try {
        // Title + link
        final linkEl = article.querySelector('a[href*="/angebote/"]');
        if (linkEl == null) continue;
        final href = linkEl.attributes['href'] ?? '';
        final title = linkEl.text.trim();

        // Price
        final priceEl = article.querySelector('[class*="Price"]');
        final priceText = priceEl?.text ?? '€ 0';
        final price = _parsePrice(priceText);

        // Image
        final imgEl = article.querySelector('img');
        final srcSet = imgEl?.attributes['srcset'] ?? '';
        final srcSetUrls = srcSet
            .split(',')
            .map((entry) => entry.trim().split(RegExp(r'\s+')).first)
            .where((url) => url.isNotEmpty)
            .toList();
        var imgSrc = srcSetUrls.isNotEmpty
            ? srcSetUrls.last
            : imgEl?.attributes['data-src'] ?? imgEl?.attributes['src'] ?? '';
        if (imgSrc.startsWith('//')) imgSrc = 'https:$imgSrc';
        imgSrc = imgSrc.replaceAllMapped(
          RegExp(r'/(\d{2,4})x(\d{2,4})(?=[./][^/]*$)'),
          (_) => '/1600x1200',
        );

        // Specs (pills)
        final pills = article.querySelectorAll('span');
        int? mileage;
        int? year;
        int? firstRegistrationMonth;
        String? fuel;
        int? powerKW;
        int? powerPS;

        for (final pill in pills) {
          final text = pill.text.trim();
          if (text.contains('km')) {
            mileage = _parseNumber(text);
          } else if (RegExp(r'\d{2}/\d{4}').hasMatch(text)) {
            final registration = RegExp(r'(\d{1,2})/(\d{4})').firstMatch(text);
            firstRegistrationMonth = int.tryParse(registration?.group(1) ?? '');
            year = int.tryParse(registration?.group(2) ?? '');
          } else if (text.contains('kW')) {
            powerKW = int.tryParse(
              RegExp(r'(\d+)\s*kW').firstMatch(text)?.group(1) ?? '',
            );
            powerPS = int.tryParse(
              RegExp(r'(\d+)\s*PS').firstMatch(text)?.group(1) ?? '',
            );
          } else if ([
            'Benzin',
            'Diesel',
            'Elektro',
            'Hybrid',
          ].any((f) => text.contains(f))) {
            fuel = text;
          }
        }

        listings.add(
          CarListing(
            id: href.hashCode.toString(),
            title: title.isNotEmpty ? title : 'Véhicule',
            brand: '',
            model: '',
            price: price,
            priceFormatted: priceText,
            mileage: mileage,
            year: year,
            firstRegistrationMonth: firstRegistrationMonth,
            fuel: fuel,
            powerKW: powerKW,
            powerPS: powerPS,
            imageUrls: imgSrc.isNotEmpty ? [imgSrc] : [],
            detailUrl: href,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return listings;
  }

  /// Rechercher les prix du marché français pour le même modèle
  Future<Map<String, double>> fetchFrenchMarketPrices({
    required String brand,
    required String model,
    int? yearFrom,
    int? yearTo,
  }) async {
    final url = _buildSearchUrl(
      brand: brand,
      model: model,
      yearFrom: yearFrom,
      yearTo: yearTo,
      country: 'F', // France
    );

    try {
      final frenchUrl = url.replaceAll('autoscout24.de', 'autoscout24.fr');
      String finalUrl = frenchUrl;
      if (kIsWeb) {
        finalUrl = 'https://corsproxy.io/?${Uri.encodeComponent(frenchUrl)}';
      }

      final response = await _client.get(
        Uri.parse(finalUrl),
        headers: {
          'User-Agent': _userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.5',
        },
      );

      if (response.statusCode != 200) {
        return {'quick': 0, 'market': 0, 'premium': 0};
      }

      final listings = _parseListingsFromHtml(response.body);
      if (listings.isEmpty) {
        return {'quick': 0, 'market': 0, 'premium': 0};
      }

      final prices = listings.map((l) => l.price).toList()..sort();
      final avg = prices.reduce((a, b) => a + b) / prices.length;
      final low = prices[prices.length ~/ 4]; // Q1
      final high =
          prices[(prices.length * 3 ~/ 4).clamp(0, prices.length - 1)]; // Q3

      return {
        'quick': low.roundToDouble(),
        'market': avg.roundToDouble(),
        'premium': high.roundToDouble(),
      };
    } catch (_) {
      return {'quick': 0, 'market': 0, 'premium': 0};
    }
  }

  // --- Helpers ---

  String _slugify(String input) {
    return input
        .toLowerCase()
        .replaceAll(' ', '-')
        .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
  }

  double _parsePrice(String s) {
    final cleaned = s.replaceAll(RegExp(r'[^\d]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  int? _parseNumber(String? s) {
    if (s == null) return null;
    final cleaned = s.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(cleaned);
  }

  void dispose() => _client.close();
}
