/// Barèmes fiscaux français 2026 — données offline
/// Sources: service-public.gouv.fr, malus-ecologique.fr, assurland.com
library;

/// Prix du cheval fiscal 2026 par région (€/CV)
const Map<String, double> regionalTaxPerCV = {
  'Auvergne-Rhône-Alpes': 50.00,
  'Bourgogne-Franche-Comté': 60.00,
  'Bretagne': 60.00,
  'Centre-Val de Loire': 55.00,
  'Corse': 53.00,
  'Grand Est': 60.00,
  'Hauts-de-France': 50.00,
  'Île-de-France': 68.95,
  'Normandie': 46.00,
  'Nouvelle-Aquitaine': 55.00,
  'Occitanie': 59.50,
  'Pays de la Loire': 51.00,
  'Provence-Alpes-Côte d\'Azur': 60.00,
  'Guadeloupe': 41.00,
  'Guyane': 42.50,
  'La Réunion': 60.00,
  'Martinique': 53.00,
  'Mayotte': 30.00,
};

/// Barème malus CO2 2026 (g/km WLTP → €)
/// Seuil : 108 g/km — Plafond : 80 000 € à 192 g/km+
const Map<int, int> co2MalusBareme = {
  108: 50,
  109: 75,
  110: 100,
  111: 125,
  112: 150,
  113: 170,
  114: 190,
  115: 210,
  116: 230,
  117: 240,
  118: 260,
  119: 280,
  120: 310,
  121: 330,
  122: 360,
  123: 400,
  124: 450,
  125: 540,
  126: 650,
  127: 740,
  128: 818,
  129: 898,
  130: 983,
  131: 1074,
  132: 1172,
  133: 1276,
  134: 1386,
  135: 1504,
  136: 1629,
  137: 1761,
  138: 1901,
  139: 2049,
  140: 2205,
  141: 2370,
  142: 2544,
  143: 2726,
  144: 2918,
  145: 3119,
  146: 3331,
  147: 3552,
  148: 3784,
  149: 4026,
  150: 4279,
  151: 4543,
  152: 4818,
  153: 5105,
  154: 5404,
  155: 5715,
  156: 6126,
  157: 6637,
  158: 7248,
  159: 7959,
  160: 8770,
  161: 9681,
  162: 10692,
  163: 11803,
  164: 13014,
  165: 14325,
  166: 15736,
  167: 17247,
  168: 18858,
  169: 20569,
  170: 22380,
  171: 24291,
  172: 26302,
  173: 28413,
  174: 30624,
  175: 32935,
  176: 35346,
  177: 37857,
  178: 40468,
  179: 43179,
  180: 45990,
  181: 48901,
  182: 51912,
  183: 55023,
  184: 58134,
  185: 61245,
  186: 64356,
  187: 67467,
  188: 70578,
  189: 73689,
  190: 76800,
  191: 79911,
  192: 80000,
};

/// Malus au poids (TMOM) 2026 — tranches progressives
/// Seuil : 1 499 kg — prix par kg supplémentaire
class WeightMalusBracket {
  final int fromKg;
  final int toKg; // -1 = illimité
  final double euroPerKg;
  const WeightMalusBracket(this.fromKg, this.toKg, this.euroPerKg);
}

const List<WeightMalusBracket> weightMalusBrackets = [
  WeightMalusBracket(1500, 1699, 10),
  WeightMalusBracket(1700, 1799, 15),
  WeightMalusBracket(1800, 1899, 20),
  WeightMalusBracket(1900, 1999, 25),
  WeightMalusBracket(2000, -1, 30), // -1 = no upper limit
];

/// Frais fixes carte grise
const double taxeFixeY4 = 11.0;
const double redevanceAcheminementY5 = 2.76;

/// Seuil poids malus
const int weightMalusThreshold = 1499;

/// Seuil CO2 malus 2026
const int co2MalusThreshold = 108;

/// Plafond malus CO2 + poids cumulé
const int malusPlafond = 80000;

/// Seuils historiques CO2 (Y3) pour les imports
/// Source: info-gouv / service-public
const Map<int, int> historicalCO2Thresholds = {
  2026: 108,
  2025: 118,
  2024: 118,
  2023: 123,
  2022: 128,
  2021: 133,
  2020: 138,
};

/// Plafonds historiques malus (Y3)
const Map<int, int> historicalMaxMalus = {
  2026: 80000,
  2025: 70000,
  2024: 60000,
  2023: 50000,
  2022: 40000,
  2021: 30000,
  2020: 20000,
};
