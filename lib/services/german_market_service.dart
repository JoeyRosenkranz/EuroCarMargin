import 'package:flutter/foundation.dart';

import '../models/car_listing.dart';
import 'autoscout_service.dart';
import 'mobile_de_service.dart';

/// Point d'entrée unique pour le marché allemand.
class GermanMarketService {
  final AutoScoutService _autoScout;
  final MobileDeService _mobile;

  GermanMarketService({
    AutoScoutService? autoScout,
    MobileDeService? mobile,
  })  : _autoScout = autoScout ?? AutoScoutService(),
        _mobile = mobile ?? MobileDeService();

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
    Future<List<CarListing>> autoScout() async {
      try {
        return await _autoScout.searchListings(
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
      } catch (error) {
        debugPrint('AutoScout24 indisponible: $error');
        return const [];
      }
    }

    Future<List<CarListing>> mobile() async {
      try {
        return await _mobile.searchListings(
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
      } catch (error) {
        debugPrint('mobile.de indisponible: $error');
        return const [];
      }
    }

    final sources = await Future.wait([autoScout(), mobile()]);
    final deduplicated = <String, CarListing>{};
    for (final listing in sources.expand((items) => items)) {
      final key = [
        _compact(listing.title),
        listing.year ?? 0,
        listing.mileage ?? 0,
        listing.price.round(),
      ].join('|');
      deduplicated.putIfAbsent(key, () => listing);
    }
    final result = deduplicated.values.toList()
      ..sort((a, b) => a.price.compareTo(b.price));
    return result;
  }

  Future<CarListing> enrichListing(CarListing listing) {
    if (listing.marketplace.toLowerCase().contains('mobile') ||
        listing.detailUrl.contains('mobile.de')) {
      return _mobile.enrichListing(listing);
    }
    return _autoScout.enrichListing(listing);
  }

  static String _compact(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  void dispose() {
    _autoScout.dispose();
    _mobile.dispose();
  }
}
