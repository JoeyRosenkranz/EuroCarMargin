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
    final peers = candidates
        .where((candidate) => matchesTechnicalVariant(target, candidate))
        .toList();

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

  /// N'accepte comme source technique que le même modèle, la même année, le
  /// même moteur (kW), la même énergie et la même carrosserie lorsqu'elle est
  /// identifiable dans le titre.
  bool matchesTechnicalVariant(CarListing target, CarListing candidate) {
    if (candidate.id == target.id) return false;
    if (target.year == null || target.powerKW == null) return false;
    if (_normalize(candidate.brand) != _normalize(target.brand) ||
        _normalize(candidate.model) != _normalize(target.model) ||
        candidate.year != target.year ||
        candidate.powerKW != target.powerKW ||
        _fuelFamily(candidate.fuel) != _fuelFamily(target.fuel)) {
      return false;
    }
    final targetBody = _bodyStyle(target.title);
    return targetBody.isEmpty || _bodyStyle(candidate.title) == targetBody;
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

  String _bodyStyle(String value) {
    final normalized = value.toLowerCase();
    const styles = {
      'sportback': ['sportback'],
      'avant': ['avant', 'break', 'estate', 'touring'],
      'sedan': ['limousine', 'sedan', 'berline'],
      'cabriolet': ['cabrio', 'cabriolet', 'roadster'],
      'coupe': ['coupé', 'coupe'],
      'suv': ['suv'],
    };
    for (final entry in styles.entries) {
      if (entry.value.any(normalized.contains)) return entry.key;
    }
    return '';
  }
}
