import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/car_listing.dart';

/// Service pour récupérer les prix de revente sur LeBonCoin.fr
/// Utilise l'API interne LeBonCoin pour les recherches voitures
class LeBonCoinService {
  static const _apiUrl = 'https://api.leboncoin.fr/finder/search';
  static const _apiKey = String.fromEnvironment('LEBONCOIN_API_KEY');
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final http.Client _client;

  LeBonCoinService({http.Client? client}) : _client = client ?? http.Client();

  /// Mapping marques vers ID LeBonCoin (principales marques)
  static const Map<String, String> _brandSlugs = {
    'Audi': 'audi',
    'BMW': 'bmw',
    'Mercedes-Benz': 'mercedes',
    'Volkswagen': 'volkswagen',
    'Porsche': 'porsche',
    'Opel': 'opel',
    'Renault': 'renault',
    'Peugeot': 'peugeot',
    'Citroën': 'citroen',
    'Citroen': 'citroen',
    'Fiat': 'fiat',
    'Toyota': 'toyota',
    'Honda': 'honda',
    'Hyundai': 'hyundai',
    'Kia': 'kia',
    'Volvo': 'volvo',
    'Ford': 'ford',
    'Skoda': 'skoda',
    'SEAT': 'seat',
    'Seat': 'seat',
    'CUPRA': 'cupra',
    'Nissan': 'nissan',
    'Mazda': 'mazda',
    'Mini': 'mini',
    'Tesla': 'tesla',
    'Jaguar': 'jaguar',
    'Land Rover': 'land-rover',
    'Alfa Romeo': 'alfa-romeo',
    'Dacia': 'dacia',
    'Jeep': 'jeep',
  };

  /// Rechercher les prix du marché français sur LeBonCoin
  /// Retourne les prix quick (Q1), market (mediane), premium (Q3)
  Future<LeBonCoinPriceResult> fetchPrices({
    required String brand,
    String? model,
    int? yearFrom,
    int? yearTo,
  }) async {
    try {
      // Strategy 1: Try the LeBonCoin API
      final result = await _fetchFromApi(
        brand: brand,
        model: model,
        yearFrom: yearFrom,
        yearTo: yearTo,
      );
      if (result.count > 0) return result;

      // Strategy 2: Fallback to web scraping
      return await _fetchFromWeb(
        brand: brand,
        model: model,
        yearFrom: yearFrom,
        yearTo: yearTo,
      );
    } catch (_) {
      // Strategy 2: Fallback to web scraping
      try {
        return await _fetchFromWeb(
          brand: brand,
          model: model,
          yearFrom: yearFrom,
          yearTo: yearTo,
        );
      } catch (_) {
        return LeBonCoinPriceResult.empty();
      }
    }
  }

  /// Fetch prices via LeBonCoin's internal API
  Future<LeBonCoinPriceResult> _fetchFromApi({
    required String brand,
    String? model,
    int? yearFrom,
    int? yearTo,
  }) async {
    final brandSlug = _brandSlugs[brand] ?? brand.toLowerCase();

    // Build keywords for search
    final keywords = model != null && model.isNotEmpty
        ? '$brand $model'
        : brand;

    final body = {
      'limit': 50,
      'limit_alu': 3,
      'filters': {
        'category': {'id': '2'}, // Voitures
        'keywords': {'text': keywords},
        'ranges': {
          if (yearFrom != null || yearTo != null)
            'regdate': {'min': ?yearFrom, 'max': ?yearTo},
        },
        'enums': {
          'ad_type': ['offer'],
          'owner_type': ['pro'],
        },
      },
      'sort_by': 'time',
      'sort_order': 'desc',
    };

    String finalUrl = _apiUrl;
    if (kIsWeb) {
      finalUrl = 'https://corsproxy.io/?${Uri.encodeComponent(_apiUrl)}';
    }

    final response = await _client.post(
      Uri.parse(finalUrl),
      headers: {
        'User-Agent': _userAgent,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Origin': 'https://www.leboncoin.fr',
        'Referer': 'https://www.leboncoin.fr/',
        if (_apiKey.isNotEmpty) 'api_key': _apiKey,
      },
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('LeBonCoin API returned ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final ads = data['ads'] as List<dynamic>? ?? [];

    return _extractPricesFromAds(ads, brandSlug);
  }

  /// Fallback: scrape from LeBonCoin website
  Future<LeBonCoinPriceResult> _fetchFromWeb({
    required String brand,
    String? model,
    int? yearFrom,
    int? yearTo,
  }) async {
    final brandSlug = _brandSlugs[brand] ?? brand.toLowerCase();
    final searchQuery = model != null && model.isNotEmpty
        ? '$brand+$model'
        : brand;

    var url =
        'https://www.leboncoin.fr/recherche?category=2'
        '&text=${Uri.encodeComponent(searchQuery)}'
        '&owner_type=pro'
        '&brand=$brandSlug';

    if (model != null && model.isNotEmpty) {
      url += '&model=${Uri.encodeComponent(model.toLowerCase())}';
    }
    if (yearFrom != null) url += '&regdate_min=$yearFrom';
    if (yearTo != null) url += '&regdate_max=$yearTo';

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
        'Accept-Language': 'fr-FR,fr;q=0.9',
      },
    );

    if (response.statusCode != 200) {
      return LeBonCoinPriceResult.empty();
    }

    // Try to extract __NEXT_DATA__ JSON
    final body = response.body;
    final nextDataMatch = RegExp(
      r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
      dotAll: true,
    ).firstMatch(body);

    if (nextDataMatch != null) {
      try {
        final jsonData =
            json.decode(nextDataMatch.group(1)!) as Map<String, dynamic>;
        final props = jsonData['props'] as Map<String, dynamic>? ?? {};
        final pageProps = props['pageProps'] as Map<String, dynamic>? ?? {};
        final searchData =
            pageProps['searchData'] as Map<String, dynamic>? ?? {};
        final ads = searchData['ads'] as List<dynamic>? ?? [];
        return _extractPricesFromAds(ads, brandSlug);
      } catch (_) {
        // Fall through to price regex
      }
    }

    // Last resort: extract prices from HTML with regex
    final priceMatches = RegExp(r'(\d[\d\s]*)\s*€').allMatches(body);
    final prices = <double>[];
    for (final m in priceMatches) {
      final cleaned = m.group(1)!.replaceAll(RegExp(r'\s'), '');
      final val = double.tryParse(cleaned);
      if (val != null && val >= 1000 && val <= 200000) {
        prices.add(val);
      }
    }

    if (prices.isEmpty) return LeBonCoinPriceResult.empty();
    return _calculateStats(prices);
  }

  /// Extract prices from LeBonCoin ads JSON
  LeBonCoinPriceResult _extractPricesFromAds(
    List<dynamic> ads,
    String brandSlug,
  ) {
    final prices = <double>[];
    final listings = <LeBonCoinListing>[];

    for (final ad in ads) {
      if (ad is! Map<String, dynamic>) continue;
      try {
        // Get price
        final priceList = ad['price'] as List<dynamic>?;
        final price = priceList != null && priceList.isNotEmpty
            ? (priceList.first as num).toDouble()
            : null;

        if (price == null || price < 500 || price > 200000) continue;
        prices.add(price);

        // Extract listing details
        final attributes = ad['attributes'] as List<dynamic>? ?? [];
        int? year;
        int? mileage;
        String? fuel;

        for (final attr in attributes) {
          if (attr is! Map<String, dynamic>) continue;
          final key = attr['key'] as String? ?? '';
          final value = attr['value']?.toString() ?? '';
          final label = attr['value_label']?.toString() ?? value;
          if (key == 'regdate') year = _parseInt(label);
          if (key == 'mileage') mileage = _parseInt(label);
          if (key == 'fuel') fuel = label;
        }

        listings.add(
          LeBonCoinListing(
            title: ad['subject'] as String? ?? '',
            price: price,
            year: year,
            mileage: mileage,
            fuel: fuel,
            url: ad['url'] as String? ?? '',
            imageUrl: _extractImageUrl(ad),
            location: _extractLocation(ad),
          ),
        );
      } catch (_) {
        continue;
      }
    }

    if (prices.isEmpty) return LeBonCoinPriceResult.empty();

    final stats = _calculateStats(prices);
    return LeBonCoinPriceResult(
      quick: stats.quick,
      market: stats.market,
      premium: stats.premium,
      count: prices.length,
      listings: listings,
    );
  }

  String? _extractImageUrl(Map<String, dynamic> ad) {
    final images = ad['images'] as Map<String, dynamic>?;
    if (images == null) return null;
    final urls =
        images['urls_large'] as List<dynamic>? ??
        images['urls'] as List<dynamic>? ??
        images['urls_thumb'] as List<dynamic>? ??
        images['small_url'] as List<dynamic>?;
    if (urls != null && urls.isNotEmpty) return urls.first as String?;
    return null;
  }

  String? _extractLocation(Map<String, dynamic> ad) {
    final loc = ad['location'] as Map<String, dynamic>?;
    if (loc == null) return null;
    final city = loc['city'] as String? ?? '';
    final dept = loc['department_name'] as String? ?? '';
    return '$city${dept.isNotEmpty ? ', $dept' : ''}';
  }

  /// Calculate Q1, mean of lowest 10 Pro, Q3 from a list of prices
  LeBonCoinPriceResult _calculateStats(List<double> prices) {
    prices.sort();

    final q1Index = (prices.length * 0.25).floor().clamp(0, prices.length - 1);
    final q3Index = (prices.length * 0.75).floor().clamp(0, prices.length - 1);
    final middle = prices.length ~/ 2;
    final median = prices.length.isOdd
        ? prices[middle]
        : (prices[middle - 1] + prices[middle]) / 2;

    return LeBonCoinPriceResult(
      quick: prices[q1Index].roundToDouble(),
      market: median.roundToDouble(),
      premium: prices[q3Index].roundToDouble(),
      count: prices.length,
      listings: [],
    );
  }

  int? _parseInt(String? value) {
    if (value == null) return null;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits);
  }

  void dispose() => _client.close();
}

/// Résultat des prix LeBonCoin
class LeBonCoinPriceResult {
  final double quick; // Vente rapide (Q1)
  final double market; // Prix moyen marché
  final double premium; // Prix premium (Q3)
  final int count; // Nombre d'annonces
  final List<LeBonCoinListing> listings;

  const LeBonCoinPriceResult({
    required this.quick,
    required this.market,
    required this.premium,
    required this.count,
    this.listings = const [],
  });

  factory LeBonCoinPriceResult.empty() =>
      const LeBonCoinPriceResult(quick: 0, market: 0, premium: 0, count: 0);

  factory LeBonCoinPriceResult.fromListings(List<LeBonCoinListing> listings) {
    if (listings.isEmpty) return LeBonCoinPriceResult.empty();
    final prices = listings.map((listing) => listing.price).toList()..sort();
    final q1 = prices[(prices.length * .25).floor()];
    final q3Index = (prices.length * .75)
        .floor()
        .clamp(0, prices.length - 1)
        .toInt();
    final q3 = prices[q3Index];
    final middle = prices.length ~/ 2;
    final median = prices.length.isOdd
        ? prices[middle]
        : (prices[middle - 1] + prices[middle]) / 2;
    return LeBonCoinPriceResult(
      quick: q1.roundToDouble(),
      market: median.roundToDouble(),
      premium: q3.roundToDouble(),
      count: listings.length,
      listings: listings,
    );
  }

  bool get hasData => count > 0 && market > 0;

  /// Construit un échantillon strict : même marque/modèle, même année, énergie
  /// identique, kilométrage proche et même variante identifiable. Une version
  /// électrique non identifiable n'est jamais comparée à toute la gamme.
  ComparableMarketEstimate comparableFor(CarListing target) {
    final targetFuel = _fuelFamily(target.fuel);
    final targetVariant = _variantSignature(target.title);
    if (target.year == null || targetFuel.isEmpty) {
      return ComparableMarketEstimate.empty();
    }
    if (targetFuel == 'electric' && targetVariant.isEmpty) {
      return ComparableMarketEstimate.empty();
    }
    final brand = _compact(target.brand);
    final model = _compact(target.model);

    bool identityMatches(LeBonCoinListing ad) {
      final title = _compact(ad.title);
      return
          brand.isNotEmpty && model.isNotEmpty &&
          title.contains(brand) && title.contains(model);
    }

    bool variantMatches(LeBonCoinListing ad) => targetVariant.every(
      (token) => _variantSignature(ad.title).contains(token),
    );

    final strictMatches = listings.where((ad) {
      final yearOk = ad.year == target.year;
      final tolerance = target.mileage == null
          ? null
          : (target.mileage! * .15).round().clamp(15000, 40000);
      final mileageOk =
          tolerance == null ||
          (ad.mileage != null &&
              (ad.mileage! - target.mileage!).abs() <= tolerance);
      return identityMatches(ad) &&
          yearOk &&
          mileageOk &&
          _fuelFamily(ad.fuel) == targetFuel &&
          variantMatches(ad);
    }).toList();

    if (strictMatches.length >= 3) {
      return _estimate(strictMatches, approximate: false);
    }

    // Repli explicite et signalé : même modèle/version/énergie, année ±1 et
    // kilométrage plus large. Le prix devient indicatif, jamais présenté comme
    // un échantillon strict.
    final relaxedMatches = listings.where((ad) {
      final yearOk = ad.year != null && (ad.year! - target.year!).abs() <= 1;
      final tolerance = target.mileage == null
          ? null
          : (target.mileage! * .25).round().clamp(30000, 60000);
      final mileageOk = tolerance == null ||
          (ad.mileage != null &&
              (ad.mileage! - target.mileage!).abs() <= tolerance);
      return identityMatches(ad) &&
          yearOk &&
          mileageOk &&
          _fuelFamily(ad.fuel) == targetFuel &&
          variantMatches(ad);
    }).toList();

    final matches = relaxedMatches.isNotEmpty ? relaxedMatches : strictMatches;
    if (matches.isEmpty) return ComparableMarketEstimate.empty();
    return _estimate(matches, approximate: true);
  }

  ComparableMarketEstimate _estimate(
    List<LeBonCoinListing> matches, {
    required bool approximate,
  }) {
    final prices = matches.map((ad) => ad.price).toList()..sort();
    final q1 = prices[(prices.length * .25).floor()];
    final middle = prices.length ~/ 2;
    final median = prices.length.isOdd
        ? prices[middle]
        : (prices[middle - 1] + prices[middle]) / 2;
    return ComparableMarketEstimate(
      quick: q1.roundToDouble(),
      market: median.roundToDouble(),
      count: matches.length,
      listings: matches,
      approximate: approximate,
      sources: matches.map((listing) => listing.source).toSet(),
    );
  }

  static String _compact(String? value) => (value ?? '')
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String _fuelFamily(String? value) {
    final text = (value ?? '')
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e');
    if (text.contains('plug') ||
        text.contains('phev') ||
        text.contains('rechargeable')) {
      return 'phev';
    }
    if (text.contains('elect') || text.contains('elektro')) return 'electric';
    if (text.contains('hybrid') || text.contains('hybride')) return 'hybrid';
    if (text.contains('diesel')) return 'diesel';
    if (text.contains('benzin') || text.contains('essence')) return 'petrol';
    return '';
  }

  static Set<String> _variantSignature(String value) {
    final text = value.toLowerCase().replaceAll(',', '.');
    final result = <String>{};
    const variants = <String, List<String>>{
      'performance': ['performance'],
      'competition': ['competition'],
      'long-range': ['long range', 'grande autonomie'],
      'standard-range': ['standard range', 'autonomie standard'],
      'dual-motor': ['dual motor'],
      'propulsion': ['propulsion'],
      'quattro': ['quattro'],
      'xdrive': ['xdrive'],
      'sportback': ['sportback'],
      'avant': ['avant', 'break', 'touring'],
    };
    for (final entry in variants.entries) {
      if (entry.value.any(text.contains)) result.add(entry.key);
    }
    final battery = RegExp(r'\b(\d{2,3})\s*kwh\b').firstMatch(text);
    if (battery != null) result.add('${battery.group(1)}kwh');
    final engine = RegExp(
      r'\b(\d[.]\d)\s*(?:tfsi|tsi|tdi|litre|l\b)',
    ).firstMatch(text);
    if (engine != null) result.add('${engine.group(1)}l');
    return result;
  }
}

class ComparableMarketEstimate {
  final double quick;
  final double market;
  final int count;
  final List<LeBonCoinListing> listings;
  final bool approximate;
  final Set<String> sources;

  const ComparableMarketEstimate({
    required this.quick,
    required this.market,
    required this.count,
    this.listings = const [],
    this.approximate = false,
    this.sources = const {},
  });

  const ComparableMarketEstimate.empty()
    : quick = 0,
      market = 0,
      count = 0,
      listings = const [],
      approximate = false,
      sources = const {};

  bool get hasEstimate => count > 0 && market > 0;
  bool get isReliable => count >= 3 && market > 0 && !approximate;
}

/// Une annonce LeBonCoin simplifiée
class LeBonCoinListing {
  final String title;
  final double price;
  final int? year;
  final int? mileage;
  final String? fuel;
  final String url;
  final String? imageUrl;
  final String? location;
  final String source;

  const LeBonCoinListing({
    required this.title,
    required this.price,
    this.year,
    this.mileage,
    this.fuel,
    this.url = '',
    this.imageUrl,
    this.location,
    this.source = 'Leboncoin',
  });
}
