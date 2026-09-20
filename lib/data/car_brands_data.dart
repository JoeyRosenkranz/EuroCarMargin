/// Données marques et modèles pour le marché import DE → FR
/// Liste des marques et modèles les plus courants sur AutoScout24
library;

const Map<String, List<String>> carBrandsModels = {
  'Audi': [
    'A1', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8',
    'Q2', 'Q3', 'Q5', 'Q7', 'Q8',
    'TT', 'R8',
    'RS3', 'RS4', 'RS5', 'RS6', 'RS7',
    'S3', 'S4', 'S5', 'S6', 'S7',
    'e-tron', 'e-tron GT', 'Q4 e-tron', 'Q8 e-tron',
  ],
  'BMW': [
    'Série 1', 'Série 2', 'Série 3', 'Série 4', 'Série 5', 'Série 7', 'Série 8',
    'X1', 'X2', 'X3', 'X4', 'X5', 'X6', 'X7',
    'Z4', 'M2', 'M3', 'M4', 'M5', 'M8',
    'i3', 'i4', 'i5', 'i7', 'iX', 'iX1', 'iX3',
  ],
  'Mercedes-Benz': [
    'Classe A', 'Classe B', 'Classe C', 'Classe E', 'Classe S',
    'CLA', 'CLS', 'CLK',
    'GLA', 'GLB', 'GLC', 'GLE', 'GLS', 'Classe G',
    'AMG GT', 'SL', 'SLK',
    'EQA', 'EQB', 'EQC', 'EQE', 'EQS',
    'Vito', 'Classe V',
  ],
  'Volkswagen': [
    'Polo', 'Golf', 'Up!', 'T-Roc', 'T-Cross', 'Tiguan', 'Touareg',
    'Passat', 'Arteon', 'Touran', 'Sharan',
    'Caddy', 'Transporter', 'Multivan',
    'ID.3', 'ID.4', 'ID.5', 'ID.7', 'ID.Buzz',
    'Golf GTI', 'Golf R', 'Golf GTD',
  ],
  'Porsche': [
    '911', '718 Cayman', '718 Boxster',
    'Cayenne', 'Macan', 'Panamera',
    'Taycan',
  ],
  'Opel': [
    'Corsa', 'Astra', 'Insignia', 'Mokka', 'Crossland', 'Grandland',
    'Combo', 'Zafira', 'Vivaro',
  ],
  'Renault': [
    'Clio', 'Mégane', 'Captur', 'Kadjar', 'Arkana', 'Austral',
    'Scénic', 'Espace', 'Talisman', 'Twingo',
    'Zoé', 'Mégane E-Tech',
  ],
  'Peugeot': [
    '208', '308', '508', '2008', '3008', '5008',
    'e-208', 'e-308', 'e-2008', 'e-3008',
    'Rifter', 'Partner', 'Expert',
  ],
  'Citroën': [
    'C3', 'C4', 'C5 X', 'C3 Aircross', 'C5 Aircross',
    'Berlingo', 'SpaceTourer',
    'ë-C4', 'ë-Berlingo',
  ],
  'Fiat': [
    '500', '500X', '500L', 'Panda', 'Tipo', 'Punto',
    'Ducato', 'Doblò',
    '500e',
  ],
  'Toyota': [
    'Yaris', 'Corolla', 'Camry', 'Supra',
    'C-HR', 'RAV4', 'Highlander', 'Land Cruiser',
    'Yaris Cross', 'Aygo X', 'bZ4X',
  ],
  'Honda': [
    'Civic', 'Jazz', 'HR-V', 'CR-V', 'ZR-V',
    'e', 'Honda e',
  ],
  'Hyundai': [
    'i10', 'i20', 'i30', 'i40',
    'Kona', 'Tucson', 'Santa Fe', 'Bayon',
    'Ioniq', 'Ioniq 5', 'Ioniq 6',
  ],
  'Kia': [
    'Picanto', 'Rio', 'Ceed', 'Proceed', 'Stinger',
    'Stonic', 'Niro', 'Sportage', 'Sorento',
    'EV6', 'EV9',
  ],
  'Volvo': [
    'V40', 'V60', 'V90', 'S60', 'S90',
    'XC40', 'XC60', 'XC90',
    'C40 Recharge', 'EX30', 'EX90',
  ],
  'Ford': [
    'Fiesta', 'Focus', 'Mondeo', 'Mustang',
    'Puma', 'Kuga', 'Explorer', 'Ranger',
    'Mustang Mach-E',
  ],
  'Skoda': [
    'Fabia', 'Octavia', 'Superb', 'Scala',
    'Kamiq', 'Karoq', 'Kodiaq',
    'Enyaq',
  ],
  'SEAT': [
    'Ibiza', 'Leon', 'Arona', 'Ateca', 'Tarraco',
  ],
  'CUPRA': [
    'Formentor', 'Leon', 'Ateca', 'Born', 'Tavascan',
  ],
  'Nissan': [
    'Micra', 'Juke', 'Qashqai', 'X-Trail', 'Leaf',
    'Ariya', 'GT-R', '370Z',
  ],
  'Mazda': [
    'Mazda2', 'Mazda3', 'Mazda6',
    'CX-3', 'CX-30', 'CX-5', 'CX-60', 'MX-5',
  ],
  'Mini': [
    'Cooper', 'Clubman', 'Countryman',
    'Cooper SE', 'Aceman',
  ],
  'Tesla': [
    'Model 3', 'Model Y', 'Model S', 'Model X',
  ],
  'Jaguar': [
    'XE', 'XF', 'F-Type',
    'E-Pace', 'F-Pace', 'I-Pace',
  ],
  'Land Rover': [
    'Range Rover', 'Range Rover Sport', 'Range Rover Velar', 'Range Rover Evoque',
    'Defender', 'Discovery', 'Discovery Sport',
  ],
  'Alfa Romeo': [
    'Giulia', 'Stelvio', 'Tonale', 'Giulietta',
  ],
  'Dacia': [
    'Sandero', 'Duster', 'Jogger', 'Spring',
  ],
  'Jeep': [
    'Renegade', 'Compass', 'Cherokee', 'Grand Cherokee',
    'Wrangler', 'Avenger',
  ],
};

/// Liste triée des marques
List<String> get sortedBrands {
  final brands = carBrandsModels.keys.toList();
  brands.sort();
  return brands;
}

/// Modèles triés pour une marque donnée
List<String> getModelsForBrand(String brand) {
  final models = carBrandsModels[brand] ?? [];
  final sorted = List<String>.from(models);
  sorted.sort();
  return sorted;
}
