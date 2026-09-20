# EuroCar Margin

Application Flutter d’aide à la sélection de véhicules d’occasion en Allemagne
et à l’estimation d’une revente en France.

## Fonctions

- recherche AutoScout24 Allemagne ;
- lecture automatique des fiches détaillées (puissance, CO₂, masse, places) ;
- complément uniquement par consensus d'annonces de même moteur, même année et
  même énergie, sans valeur inventée ;
- comparaison avec des annonces professionnelles françaises du même modèle,
  année ±1, énergie identique et kilométrage proche ;
- médiane et premier quartile du panel français, sans extrapolation depuis le
  prix allemand ;
- carte grise, malus CO₂, malus masse et décote liée à l’âge pour une
  immatriculation française en 2026 ;
- famille nombreuse avec séparation entre montant à avancer et remboursement ;
- marge nette avec frais professionnels et scénario de TVA sur marge ;
- blocage de la marge si une donnée d’homologation ou le panel est insuffisant.
- thèmes clair et sombre, mise en page responsive et historique local.

## Données à vérifier

Les champs fiscaux doivent provenir du certificat de conformité européen ou de
la carte grise étrangère : puissance administrative P.6, CO₂ WLTP V.7 et masse
en ordre de marche G. L’application ne remplace ni France Titres, ni un conseil
fiscal ou comptable. Le régime de TVA sur marge dépend notamment du vendeur et
de la facture d’achat.

Le remboursement famille nombreuse suppose au moins trois enfants à charge, un
véhicule d’au moins cinq places et la limite d’un véhicule par foyer sur deux
ans. Le malus complet est d’abord payé.

## Références intégrées

- CIBS L421-62 : barèmes CO₂ WLTP 2020–2026 ;
- CIBS L421-7-2 : décote mensuelle des imports d’occasion ;
- CIBS L421-75 : barèmes du malus masse ;
- CIBS L421-79 et L421-79-1 : règles énergie/hybrides ;
- BOFiP BOI-AIS-MOB-10-20-40 : remboursement famille nombreuse ;
- simulateur France Titres / Service-Public : tarif régional.

Paramètres révisés le 20 septembre 2026. Les taux régionaux sont centralisés
dans `lib/data/tax_data.dart` et doivent être revérifiés à chaque changement.

Le cas témoin `1 600 kg`, première immatriculation au 01/09/2025, a été
comparé au simulateur officiel le 20/09/2026 : 10 € de TMOM avant décote et
8,40 € après la décote de 16 %.

## Lancer le projet

```bash
flutter pub get
flutter test
flutter run
```

Pour activer l'appel direct à l'API LeBonCoin sans publier de clé dans le
dépôt, fournissez-la uniquement au moment de la compilation :

```bash
flutter run --dart-define=LEBONCOIN_API_KEY=VOTRE_CLE
```

Sans cette valeur, l'application utilise automatiquement la recherche web de
secours. Ne placez jamais la clé directement dans le code source.

Flutter compatible Dart 3.10 ou version ultérieure est recommandé.
