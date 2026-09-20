/// Donnees fiscales francaises verifiees pour une immatriculation en 2026.
///
/// Sources de reference (revues le 20/09/2026) :
/// - CIBS, art. L421-62 : baremes CO2 WLTP 2020-2026
/// - CIBS, art. L421-7-2 : coefficient mensuel de decote
/// - CIBS, art. L421-75 : baremes de masse 2022-2026
/// - Simulateur officiel Service-Public / France Titres : taxes regionales
library;

/// Prix indicatif du cheval fiscal en vigueur en septembre 2026.
/// Le simulateur officiel reste la reference car une region peut voter un
/// changement en cours d'annee.
const Map<String, double> regionalTaxPerCV = {
  'Auvergne-Rhône-Alpes': 43.00,
  'Bourgogne-Franche-Comté': 55.00,
  'Bretagne': 60.00,
  'Centre-Val de Loire': 60.00,
  'Corse': 53.00,
  'Grand Est': 60.00,
  'Hauts-de-France': 43.00,
  'Île-de-France': 68.95,
  'Normandie': 60.00,
  'Nouvelle-Aquitaine': 58.00,
  'Occitanie': 59.50,
  'Pays de la Loire': 51.00,
  'Provence-Alpes-Côte d\'Azur': 60.00,
  'Guadeloupe': 41.00,
  'Guyane': 42.50,
  'La Réunion': 60.00,
  'Martinique': 53.00,
  'Mayotte': 30.00,
};

/// Part de taxe regionale exoneree pour un vehicule electrique/hydrogene.
const Map<String, double> cleanVehicleRegionalExemption = {
  'Hauts-de-France': 0.50,
};

/// Suite de montants utilisee par les baremes WLTP 2024-2026.
const List<int> recentCo2Amounts = [
  50,
  75,
  100,
  125,
  150,
  170,
  190,
  210,
  230,
  240,
  260,
  280,
  310,
  330,
  360,
  400,
  450,
  540,
  650,
  740,
  818,
  898,
  983,
  1074,
  1172,
  1276,
  1386,
  1504,
  1629,
  1761,
  1901,
  2049,
  2205,
  2370,
  2544,
  2726,
  2918,
  3119,
  3331,
  3552,
  3784,
  4026,
  4279,
  4543,
  4818,
  5105,
  5404,
  5715,
  6126,
  6637,
  7248,
  7959,
  8770,
  9681,
  10692,
  11803,
  13014,
  14325,
  15736,
  17247,
  18858,
  20569,
  22380,
  24291,
  26302,
  28413,
  30624,
  32935,
  35346,
  37857,
  40468,
  43179,
  45990,
  48901,
  51912,
  55023,
  58134,
  61245,
  64356,
  67467,
  70578,
  73689,
  76800,
  79911,
];

/// Suite de montants utilisee par les baremes WLTP 2020-2023.
const List<int> legacyCo2Amounts = [
  50,
  75,
  100,
  125,
  150,
  170,
  190,
  210,
  230,
  240,
  260,
  280,
  310,
  330,
  360,
  400,
  450,
  540,
  650,
  740,
  818,
  898,
  983,
  1074,
  1172,
  1276,
  1386,
  1504,
  1629,
  1761,
  1901,
  2049,
  2205,
  2370,
  2544,
  2726,
  2918,
  3119,
  3331,
  3552,
  3784,
  4026,
  4279,
  4543,
  4818,
  5105,
  5404,
  5715,
  6039,
  6375,
  6724,
  7086,
  7462,
  7851,
  8254,
  8671,
  9103,
  9550,
  10011,
  10488,
  10980,
  11488,
  12012,
  12552,
  13109,
  13682,
  14273,
  14881,
  15506,
  16149,
  16810,
  17490,
  18188,
  18905,
  19641,
  20396,
  21171,
  21966,
  22781,
  23616,
  24472,
  25349,
  26247,
  27166,
  28107,
  29070,
  30056,
  31063,
  32094,
  33147,
  34224,
  35324,
  36447,
  37595,
  38767,
  39964,
  41185,
  42431,
  43703,
  45000,
  46323,
  47672,
  49047,
];

class Co2Schedule {
  final int threshold;
  final int maximum;
  final int maximumFrom;
  final List<int> amounts;
  final Map<int, int> overrides;

  const Co2Schedule({
    required this.threshold,
    required this.maximum,
    required this.maximumFrom,
    required this.amounts,
    this.overrides = const {},
  });
}

/// Le choix 2024 s'applique aussi aux immatriculations de janvier-fevrier 2025.
const Map<int, Co2Schedule> co2Schedules = {
  2020: Co2Schedule(
    threshold: 138,
    maximum: 20000,
    maximumFrom: 213,
    amounts: legacyCo2Amounts,
  ),
  2021: Co2Schedule(
    threshold: 133,
    maximum: 30000,
    maximumFrom: 219,
    amounts: legacyCo2Amounts,
  ),
  2022: Co2Schedule(
    threshold: 128,
    maximum: 40000,
    maximumFrom: 224,
    amounts: legacyCo2Amounts,
  ),
  2023: Co2Schedule(
    threshold: 123,
    maximum: 50000,
    maximumFrom: 226,
    amounts: legacyCo2Amounts,
  ),
  2024: Co2Schedule(
    threshold: 118,
    maximum: 60000,
    maximumFrom: 194,
    amounts: recentCo2Amounts,
    overrides: {167: 6537},
  ),
  2025: Co2Schedule(
    threshold: 113,
    maximum: 70000,
    maximumFrom: 193,
    amounts: recentCo2Amounts,
  ),
  2026: Co2Schedule(
    threshold: 108,
    maximum: 80000,
    maximumFrom: 192,
    amounts: recentCo2Amounts,
  ),
};

class AgeDiscountBracket {
  final int maxMonths;
  final int percent;
  const AgeDiscountBracket(this.maxMonths, this.percent);
}

/// CIBS L421-7-2, en vigueur du 01/03/2025 au 01/01/2027.
const List<AgeDiscountBracket> ageDiscountBrackets = [
  AgeDiscountBracket(3, 3),
  AgeDiscountBracket(6, 6),
  AgeDiscountBracket(9, 9),
  AgeDiscountBracket(12, 12),
  AgeDiscountBracket(18, 16),
  AgeDiscountBracket(24, 20),
  AgeDiscountBracket(36, 28),
  AgeDiscountBracket(48, 33),
  AgeDiscountBracket(60, 38),
  AgeDiscountBracket(72, 43),
  AgeDiscountBracket(84, 48),
  AgeDiscountBracket(96, 53),
  AgeDiscountBracket(108, 58),
  AgeDiscountBracket(120, 64),
  AgeDiscountBracket(132, 70),
  AgeDiscountBracket(144, 76),
  AgeDiscountBracket(156, 82),
  AgeDiscountBracket(168, 88),
  AgeDiscountBracket(180, 94),
  AgeDiscountBracket(9999, 100),
];

class WeightMalusBracket {
  final int fromKg;
  final int? toKg;
  final double euroPerKg;
  const WeightMalusBracket(this.fromKg, this.toKg, this.euroPerKg);
}

const List<WeightMalusBracket> weightBrackets2022 = [
  WeightMalusBracket(1800, null, 10),
];

const List<WeightMalusBracket> weightBrackets2024 = [
  WeightMalusBracket(1600, 1799, 10),
  WeightMalusBracket(1800, 1899, 15),
  WeightMalusBracket(1900, 1999, 20),
  WeightMalusBracket(2000, 2099, 25),
  WeightMalusBracket(2100, null, 30),
];

const List<WeightMalusBracket> weightBrackets2026 = [
  WeightMalusBracket(1500, 1699, 10),
  WeightMalusBracket(1700, 1799, 15),
  WeightMalusBracket(1800, 1899, 20),
  WeightMalusBracket(1900, 1999, 25),
  WeightMalusBracket(2000, null, 30),
];

const double taxeFixeY4 = 11.0;
const double redevanceAcheminementY5 = 2.76;
