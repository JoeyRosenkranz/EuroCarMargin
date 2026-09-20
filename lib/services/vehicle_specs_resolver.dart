import '../models/car_listing.dart';

/// Complète une fiche uniquement à partir d'annonces strictement comparables.
///
/// La marque, le modèle, l'année, la puissance en kW et l'énergie doivent être
/// identiques. Une valeur n'est retenue que si au moins deux annonces sources
/// concordent et représentent au moins deux tiers des valeurs disponibles.
class VehicleSpecsResolver {
  List<CarListing> resolveAll(List<CarListing> listings) {
    return [for (final listing in listings) resolve(listing, listings)];
  }

  CarListing resolve(CarListing target, List<CarListing> candidates) {
    final peers = candidates.where((candidate) {
      if (candidate.id == target.id) return false;
      if (target.year == null || target.powerKW == null) return false;
      return _normalize(candidate.brand) == _normalize(target.brand) &&
          _normalize(candidate.model) == _normalize(target.model) &&
          candidate.year == target.year &&
          candidate.powerKW == target.powerKW &&
          _fuelFamily(candidate.fuel) == _fuelFamily(target.fuel);
    }).toList();

    final co2 = target.co2 ?? _consensus(peers.map((e) => e.co2));
    final weight =
        target.weightG1 ?? _consensus(peers.map((e) => e.weightG1));
    final seats = target.seats ?? _consensus(peers.map((e) => e.seats));
    final range = target.electricRangeKm ??
        _consensus(peers.map((e) => e.electricRangeKm));

    final inferred = co2 != target.co2 ||
        weight != target.weightG1 ||
        seats != target.seats ||
        range != target.electricRangeKm;
    if (!inferred) return target;

    return target.copyWith(
      co2: co2,
      weightG1: weight,
      seats: seats,
      electricRangeKm: range,
      technicalSource: 'Consensus moteur (${peers.length} annonces)',
    );
  }

  int? _consensus(Iterable<int?> values) {
    final present = values.whereType<int>().where((value) => value > 0).toList();
    if (present.length < 2) return null;
    final counts = <int, int>{};
    for (final value in present) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final winner = sorted.first;
    if (winner.value < 2 || winner.value / present.length < 2 / 3) return null;
    if (sorted.length > 1 && sorted[1].value == winner.value) return null;
    return winner.key;
  }

  String _normalize(String? value) => (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _fuelFamily(String? value) {
    final fuel = (value ?? '').toLowerCase();
    if (fuel.contains('plug') ||
        fuel.contains('phev') ||
        fuel.contains('rechargeable')) {
      return 'phev';
    }
    if (fuel.contains('hybrid') || fuel.contains('hybride')) return 'hybrid';
    if (fuel.contains('diesel')) return 'diesel';
    if (fuel.contains('elektro') ||
        fuel.contains('electric') ||
        fuel.contains('électrique')) {
      return 'electric';
    }
    if (fuel.contains('benzin') || fuel.contains('essence')) return 'petrol';
    return _normalize(fuel);
  }
}
