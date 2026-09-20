/// Donnees fiscales francaises verifiees pour une immatriculation en 2026.
///
/// Sources de reference (revues le 20/09/2026) :
/// - CIBS, art. L421-62 : baremes CO2 WLTP 2020-2026
/// - CIBS, art. L421-63 : baremes CO2 NEDC 2015-2019
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

/// Barèmes NEDC historiques du CIBS, art. L421-63. Ils sont appliqués aux
/// véhicules importés selon leur année de première immatriculation à l'étranger.
const List<int> nedc2015And2016Amounts = [
  150, 150, 150, 150, 150,
  250, 250, 250, 250, 250,
  500, 500, 500, 500, 500,
  900, 900, 900, 900, 900,
  1600, 1600, 1600, 1600, 1600,
  2200, 2200, 2200, 2200, 2200, 2200, 2200, 2200, 2200, 2200,
  2200, 2200, 2200, 2200, 2200, 2200, 2200, 2200, 2200, 2200,
  3000, 3000, 3000, 3000, 3000,
  3600, 3600, 3600, 3600, 3600,
  4000, 4000, 4000, 4000, 4000,
  6500, 6500, 6500, 6500, 6500, 6500, 6500, 6500, 6500, 6500,
];

const List<int> nedc2017Amounts = [
  50, 53, 60, 73, 90, 113, 140, 173, 210, 253, 300, 353, 410,
  473, 540, 613, 690, 773, 860, 953, 1050, 1153, 1260, 1373, 1490,
  1613, 1740, 1873, 2010, 2153, 2300, 2453, 2610, 2773, 2940, 3113,
  3290, 3473, 3660, 3853, 4050, 4253, 4460, 4673, 4890, 5113, 5340,
  5573, 5810, 6053, 6300, 6553, 6810, 7073, 7340, 7613, 7890, 8173,
  8460, 8753, 9050, 9353, 9660, 9973,
];

const List<int> nedc2018Amounts = [
  50, 53, 60, 73, 90, 113, 140, 173, 210, 253, 300, 353, 410,
  473, 540, 613, 690, 773, 860, 953, 1050, 1153, 1260, 1373, 1490,
  1613, 1740, 1873, 2010, 2153, 2300, 2453, 2610, 2773, 2940, 3113,
  3290, 3473, 3660, 3853, 4050, 4253, 4460, 4673, 4890, 5113, 5340,
  5573, 5810, 6053, 6300, 6553, 6810, 7073, 7340, 7613, 7890, 8173,
  8460, 8753, 9050, 9353, 9660, 9973, 10290,
];

const List<int> nedc2019Amounts = [
  35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 113, 140, 173,
  210, 253, 300, 353, 410, 473, 540, 613, 690, 773, 860, 953, 1050,
  1101, 1153, 1260, 1373, 1490, 1613, 1740, 1873, 2010, 2153, 2300,
  2453, 2610, 2773, 2940, 3113, 3290, 3473, 3660, 3756, 3853, 4050,
  4253, 4460, 4673, 4890, 5113, 5340, 5573, 5810, 6053, 6300, 6553,
  6810, 7073, 7340, 7613, 7890, 8173, 8460, 8753, 9050, 9353, 9660,
  9973, 10290,
];

/// Le choix 2024 s'applique aussi aux immatriculations de janvier-fevrier 2025.
const Map<int, Co2Schedule> co2Schedules = {
  2015: Co2Schedule(
    threshold: 131,
    maximum: 8000,
    maximumFrom: 201,
    amounts: nedc2015And2016Amounts,
  ),
  2016: Co2Schedule(
    threshold: 131,
    maximum: 8000,
    maximumFrom: 201,
    amounts: nedc2015And2016Amounts,
  ),
  2017: Co2Schedule(
    threshold: 127,
    maximum: 10000,
    maximumFrom: 191,
    amounts: nedc2017Amounts,
  ),
  2018: Co2Schedule(
    threshold: 120,
    maximum: 10500,
    maximumFrom: 185,
    amounts: nedc2018Amounts,
  ),
  2019: Co2Schedule(
    threshold: 117,
    maximum: 10500,
    maximumFrom: 191,
    amounts: nedc2019Amounts,
  ),
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
