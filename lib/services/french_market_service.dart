import 'package:flutter/foundation.dart';

import '../models/car_listing.dart';
import 'autoscout_service.dart';
import 'leboncoin_service.dart';

/// Agrège plusieurs catalogues français avant de construire les comparables.
class FrenchMarketService {
  final LeBonCoinService _leBonCoin;
  final AutoScoutService _autoScout;

  FrenchMarketService({
    LeBonCoinService? leBonCoin,
    AutoScoutService? autoScout,
  })  : _leBonCoin = leBonCoin ?? LeBonCoinService(),
        _autoScout = autoScout ?? AutoScoutService();

  Future<LeBonCoinPriceResult> fetchPrices({
    required String brand,
    String? model,
    int? yearFrom,
    int? yearTo,
    int? mileage,
  }) async {
    Future<LeBonCoinPriceResult> leBonCoin() async {
      try {
        return await _leBonCoin.fetchPrices(
          brand: brand,
          model: model,
          yearFrom: yearFrom,
          yearTo: yearTo,
        );
      } catch (error) {
        debugPrint('Leboncoin indisponible: $error');
        return LeBonCoinPriceResult.empty();
      }
    }

    Future<List<CarListing>> autoScout() async {
      try {
        return await _autoScout.searchFrenchListings(
          brand: brand,
          model: model,
          yearFrom: yearFrom,
          yearTo: yearTo,
          kmTo: mileage == null ? null : mileage + 60000,
        );
      } catch (error) {
        debugPrint('AutoScout24 France indisponible: $error');
        return const [];
      }
    }

    final results = await Future.wait<dynamic>([leBonCoin(), autoScout()]);
    final lbc = results[0] as LeBonCoinPriceResult;
    final autoScoutListings = results[1] as List<CarListing>;
    final merged = <LeBonCoinListing>[
      ...lbc.listings,
      ...autoScoutListings.map(
        (listing) => LeBonCoinListing(
          title: listing.title,
          price: listing.price,
          year: listing.year,
          mileage: listing.mileage,
          fuel: listing.fuel,
          url: listing.absoluteDetailUrl,
          imageUrl: listing.imageUrls.isEmpty ? null : listing.imageUrls.first,
          location: listing.location,
          source: 'AutoScout24 France',
        ),
      ),
    ];
    final deduplicated = <String, LeBonCoinListing>{};
    for (final listing in merged) {
      final key = [
        _compact(listing.title),
        listing.year ?? 0,
        listing.mileage ?? 0,
        listing.price.round(),
      ].join('|');
      deduplicated.putIfAbsent(key, () => listing);
    }
    return LeBonCoinPriceResult.fromListings(deduplicated.values.toList());
  }

  static String _compact(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  void dispose() {
    _leBonCoin.dispose();
    _autoScout.dispose();
  }
}
