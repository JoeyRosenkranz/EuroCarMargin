import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/car_listing.dart';
import '../services/autoscout_service.dart';
import '../services/tax_calculator.dart';
import '../services/leboncoin_service.dart';
import '../services/vehicle_specs_resolver.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class ResultsScreen extends StatefulWidget {
  final List<CarListing> listings;
  final String brand;
  final String model;
  final double transportCost;
  final double prepCost;
  final double proCosts;
  final bool vatOnMargin;

  const ResultsScreen({
    super.key,
    required this.listings,
    required this.brand,
    required this.model,
    required this.transportCost,
    required this.prepCost,
    required this.proCosts,
    required this.vatOnMargin,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _fmt = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 0,
  );
  String _selectedRegion = 'Grand Est';
  bool _has3Children = false;
  LeBonCoinPriceResult? _lbcPrices;
  bool _loadingPrices = true;
  late List<CarListing> _listings;
  final _loadingTechnical = <String>{};
  final _autoScoutService = AutoScoutService();
  final _specsResolver = VehicleSpecsResolver();

  @override
  void initState() {
    super.initState();
    _listings = List<CarListing>.from(widget.listings);
    _fetchLeBonCoinPrices();
    _prefetchTechnicalData();
  }

  @override
  void dispose() {
    _autoScoutService.dispose();
    super.dispose();
  }

  Future<void> _prefetchTechnicalData() async {
    final limit = _listings.length < 8 ? _listings.length : 8;
    for (var start = 0; start < limit; start += 3) {
      final end = start + 3 < limit ? start + 3 : limit;
      await Future.wait([
        for (var index = start; index < end; index++)
          _enrichListing(_listings[index]),
      ]);
      if (!mounted) return;
    }
  }

  Future<CarListing> _enrichListing(CarListing listing) async {
    final current = _listings.firstWhere(
      (item) => item.id == listing.id,
      orElse: () => listing,
    );
    if (current.hasRequiredTechnicalData) return current;
    if (mounted) setState(() => _loadingTechnical.add(listing.id));
    final enriched = await _autoScoutService.enrichListing(current);
    if (!mounted) return enriched;
    setState(() {
      final index = _listings.indexWhere((item) => item.id == listing.id);
      if (index >= 0) _listings[index] = enriched;
      _listings = _specsResolver.resolveAll(_listings);
      _loadingTechnical.remove(listing.id);
    });
    return enriched;
  }

  Future<void> _fetchLeBonCoinPrices() async {
    try {
      final service = LeBonCoinService();
      final result = await service.fetchPrices(
        brand: widget.brand,
        model: widget.model.isNotEmpty ? widget.model : null,
        yearFrom: widget.listings.isNotEmpty
            ? widget.listings
                  .map((l) => l.year ?? 2020)
                  .reduce((a, b) => a < b ? a : b)
            : null,
      );
      if (mounted) {
        setState(() {
          _lbcPrices = result;
          _loadingPrices = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrices = false);
    }
  }

  Future<void> _openDetail(CarListing listing) async {
    var resolvedListing = listing;
    if (!listing.hasRequiredTechnicalData) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Lecture de la fiche technique…')),
            ],
          ),
        ),
      );
      resolvedListing = await _enrichListing(listing);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    }
    final comparable =
        _lbcPrices?.comparableFor(resolvedListing) ??
        ComparableMarketEstimate.empty();

    final vehicle = resolvedListing
        .toVehicleEntry(region: _selectedRegion)
        .copyWith(
          transportCost: widget.transportCost,
          prepCost: widget.prepCost,
        );
    final calculator = TaxCalculator();
    final result = calculator.calculate(
      vehicle,
      childrenCount: _has3Children ? 3 : 0,
      lbcMarketPrice: comparable.market,
      lbcQuickPrice: comparable.quick,
      comparableCount: comparable.count,
      proCosts: widget.proCosts,
      vatOnMargin: widget.vatOnMargin,
    );

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => DashboardScreen(
          result: result,
          imageUrl: resolvedListing.imageUrls.isNotEmpty
              ? resolvedListing.imageUrls.first
              : null,
          listingUrl: resolvedListing.detailUrl.isNotEmpty
              ? 'https://www.autoscout24.de${resolvedListing.detailUrl}'
              : null,
        ),
        transitionsBuilder: (_, anim, _, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  Future<void> _toggleFamilyBenefit() async {
    if (_has3Children) {
      setState(() => _has3Children = false);
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Abattement famille nombreuse'),
        content: Text(
          'À activer uniquement si le titulaire assume la charge effective '
          'd’au moins 3 enfants, si le véhicule a au moins 5 places et si le '
          'foyer n’a pas déjà obtenu ce remboursement depuis 2 ans. Le malus '
          'complet reste à avancer lors de l’immatriculation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Je suis éligible'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) setState(() => _has3Children = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.brand} ${widget.model}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Région picker
          PopupMenuButton<String>(
            icon: Icon(Icons.location_on, color: context.appColors.accent),
            tooltip: 'Région',
            onSelected: (r) => setState(() => _selectedRegion = r),
            itemBuilder: (_) =>
                [
                      'Grand Est',
                      'Île-de-France',
                      'Hauts-de-France',
                      'Auvergne-Rhône-Alpes',
                      'Nouvelle-Aquitaine',
                      'Occitanie',
                      'Provence-Alpes-Côte d\'Azur',
                      'Bretagne',
                      'Normandie',
                      'Pays de la Loire',
                    ]
                    .map(
                      (r) => PopupMenuItem(
                        value: r,
                        child: Text(
                          r,
                          style: TextStyle(
                            fontWeight: r == _selectedRegion
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(96),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chip(
                      '${widget.listings.length} annonces DE',
                      context.appColors.accent,
                    ),
                    _chip('📍 $_selectedRegion', context.appColors.accentPurple),
                  ],
                ),
                SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (_loadingPrices)
                      _chip('🔄 Marché FR…', context.appColors.accentOrange)
                    else if (_lbcPrices != null && _lbcPrices!.hasData)
                      _chip(
                        'Marché FR: ${_fmt.format(_lbcPrices!.market)}',
                        context.appColors.accentOrange,
                      )
                    else
                      _chip('Marché FR: —', context.appColors.textMuted),
                    _actionChip(
                      'Famille (3+)',
                      Icons.family_restroom,
                      _has3Children,
                      _toggleFamilyBenefit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(12),
        itemCount: _listings.length,
        itemBuilder: (context, i) => _buildListingCard(_listings[i], i),
      ),
    );
  }

  Widget _buildListingCard(CarListing listing, int index) {
    final comparable =
        _lbcPrices?.comparableFor(listing) ??
        ComparableMarketEstimate.empty();
    final vehicle = listing
        .toVehicleEntry(region: _selectedRegion)
        .copyWith(
          transportCost: widget.transportCost,
          prepCost: widget.prepCost,
        );
    final res = TaxCalculator().calculate(
      vehicle,
      childrenCount: _has3Children ? 3 : 0,
      lbcMarketPrice: comparable.market,
      lbcQuickPrice: comparable.quick,
      comparableCount: comparable.count,
      proCosts: widget.proCosts,
      vatOnMargin: widget.vatOnMargin,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _openDetail(listing),
        child: Container(
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Image ---
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: listing.imageUrls.isNotEmpty
                    ? SizedBox(
                        height: 250,
                        child: PageView.builder(
                          itemCount: listing.imageUrls.length,
                          itemBuilder: (context, index) {
                            return Container(
                              color: context.appColors.surfaceLight,
                              child: Image.network(
                                listing.imageUrls[index],
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                                gaplessPlayback: true,
                                headers: {'Accept': 'image/webp,image/*'},
                                errorBuilder: (_, _, _) => _imagePlaceholder(),
                                loadingBuilder: (_, child, loading) {
                                  if (loading == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: context.appColors.accent,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      )
                    : _imagePlaceholder(),
              ),

              // --- Content ---
              Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            listing.title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.appColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          listing.priceFormatted,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.appColors.accent,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),

                    // Specs row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (listing.year != null)
                          _specChip(Icons.calendar_today, '${listing.year}'),
                        if (listing.mileage != null)
                          _specChip(
                            Icons.speed,
                            '${(listing.mileage! / 1000).toStringAsFixed(0)}k km',
                          ),
                        if (listing.powerPS != null)
                          _specChip(Icons.bolt, '${listing.powerPS} PS'),
                        if (listing.fuel != null)
                          _specChip(Icons.local_gas_station, listing.fuel!),
                        if (listing.transmission != null)
                          _specChip(Icons.settings, listing.transmission!),
                        if (_has3Children)
                          _specChip(
                            Icons.family_restroom,
                            'Remboursement simulé',
                            color: context.appColors.accentGreen,
                          ),
                        if (_loadingTechnical.contains(listing.id))
                          _specChip(
                            Icons.sync_rounded,
                            'Données techniques…',
                            color: context.appColors.accentCyan,
                          )
                        else if (listing.hasRequiredTechnicalData)
                          _specChip(
                            Icons.verified_rounded,
                            'Fiche technique chargée',
                            color: context.appColors.accentGreen,
                          ),
                        if (res.ageReductionPct > 0)
                          _specChip(
                            Icons.trending_down,
                            'Décote légale −${res.ageReductionPct.toStringAsFixed(0)} %',
                            color: context.appColors.accentCyan,
                          ),
                      ],
                    ),
                    SizedBox(height: 12),
                    if (!res.calculationReliable) ...[
                      _warningBanner(res.warnings.first),
                      SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _buildMarginBlock(
                            'Marché FR',
                            res.marginFRMarket,
                            res.profitFRMarket,
                            _getRiskColor(res.marginFRMarket),
                            comparable.count >= 3 && res.calculationReliable,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildMarginBlock(
                            'Vente rapide',
                            res.marginFRQuick,
                            res.profitFRQuick,
                            _getRiskColor(res.marginFRQuick),
                            comparable.count >= 3 && res.calculationReliable,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      comparable.count >= 3
                          ? '${comparable.count} annonces françaises comparables · année ±1 · kilométrage proche'
                          : 'Prix de revente masqué : moins de 3 annonces réellement comparables.',
                      style: TextStyle(
                        color: context.appColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _warningBanner(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appColors.accentOrange.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: context.appColors.accentOrange.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 17,
            color: context.appColors.accentOrange,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 11,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarginBlock(
    String source,
    double margin,
    double profit,
    Color riskColor,
    bool hasData,
  ) {
    if (!hasData) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: context.appColors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.appColors.cardBorder),
        ),
        child: Column(
          children: [
            Text(
              'Revente $source',
              style: TextStyle(color: context.appColors.textMuted, fontSize: 11),
            ),
            SizedBox(height: 2),
            Text(
              'N/A',
              style: TextStyle(
                color: context.appColors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: riskColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: riskColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                margin >= 15
                    ? Icons.trending_up_rounded
                    : margin >= 5
                    ? Icons.trending_flat_rounded
                    : Icons.trending_down_rounded,
                color: riskColor,
                size: 14,
              ),
              SizedBox(width: 4),
              Text(
                'Marge $source',
                style: TextStyle(
                  color: riskColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            '${profit >= 0 ? '+' : ''}${_fmt.format(profit)}',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: riskColor,
            ),
          ),
          Text(
            '${margin.toStringAsFixed(1)}%',
            style: TextStyle(
              color: riskColor.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(double margin) {
    if (margin < 0) return context.appColors.accentRed;
    if (margin >= 15) return context.appColors.accentGreen;
    if (margin >= 7) return context.appColors.accentOrange;
    return context.appColors.textMuted;
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 180,
      color: context.appColors.surfaceLight,
      child: Center(
        child: Icon(
          Icons.directions_car_rounded,
          size: 48,
          color: context.appColors.textMuted,
        ),
      ),
    );
  }

  Widget _specChip(IconData icon, String text, {Color? color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? context.appColors.textSecondary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color ?? context.appColors.textSecondary),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color ?? context.appColors.textSecondary,
              fontSize: 12,
              fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actionChip(
    String text,
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? context.appColors.accent.withValues(alpha: 0.15)
              : context.appColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? context.appColors.accent : context.appColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? context.appColors.accent : context.appColors.textSecondary,
            ),
            SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: isActive ? context.appColors.accent : context.appColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
