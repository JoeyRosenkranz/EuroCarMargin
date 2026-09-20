import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/car_listing.dart';
import '../models/vehicle_model.dart';
import '../models/calculation_result.dart';
import '../services/tax_calculator.dart';
import '../services/autoscout_service.dart';
import '../services/leboncoin_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class ResultsScreen extends StatefulWidget {
  final List<CarListing> listings;
  final String brand;
  final String model;

  const ResultsScreen({
    super.key,
    required this.listings,
    required this.brand,
    required this.model,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);
  String _selectedRegion = 'Grand Est';
  bool _has3Children = false;
  LeBonCoinPriceResult? _lbcPrices;
  bool _loadingPrices = true;

  /// Best available French market price for calculations
  double? get _bestFrenchMarketPrice {
    if (_lbcPrices != null && _lbcPrices!.hasData) return _lbcPrices!.market;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _fetchLeBonCoinPrices();
  }

  Future<void> _fetchLeBonCoinPrices() async {
    try {
      final service = LeBonCoinService();
      final result = await service.fetchPrices(
        brand: widget.brand,
        model: widget.model.isNotEmpty ? widget.model : null,
        yearFrom: widget.listings.isNotEmpty
            ? widget.listings.map((l) => l.year ?? 2020).reduce((a, b) => a < b ? a : b)
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

  void _openDetail(CarListing listing) {
    // --- LBC Market Price calculation ---
    double lbcMarketPrice = 0;
    double lbcQuickPrice = 0;
    if (_lbcPrices != null && _lbcPrices!.hasData && widget.listings.isNotEmpty) {
      double sumDE = 0;
      for (var l in widget.listings) sumDE += l.price;
      double avgDE = sumDE / widget.listings.length;
      if (avgDE > 0) {
        lbcMarketPrice = listing.price * (_lbcPrices!.market / avgDE);
        lbcQuickPrice = listing.price * (_lbcPrices!.quick / avgDE);
      }
    }

    final calculator = TaxCalculator();
    final result = calculator.calculate(
      listing.toVehicleEntry(region: _selectedRegion),
      childrenCount: _has3Children ? 3 : 0,
      lbcMarketPrice: lbcMarketPrice,
      lbcQuickPrice: lbcQuickPrice,
    );

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => DashboardScreen(
          result: result,
          imageUrl: listing.imageUrls.isNotEmpty ? listing.imageUrls.first : null,
          listingUrl: listing.detailUrl.isNotEmpty
              ? 'https://www.autoscout24.de${listing.detailUrl}'
              : null,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  int _estimateCO2(CarListing listing) {
    // Estimation CO2 basée sur la puissance et le carburant
    final ps = listing.powerPS ?? 100;
    final fuel = (listing.fuel ?? '').toLowerCase();
    if (fuel.contains('elektro')) return 0;
    if (fuel.contains('hybrid')) return (ps * 0.5).round().clamp(50, 200);
    if (fuel.contains('diesel')) return (ps * 0.7 + 50).round().clamp(90, 250);
    return (ps * 0.8 + 40).round().clamp(100, 300); // Benzin default
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.brand} ${widget.model}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Région picker
          PopupMenuButton<String>(
            icon: const Icon(Icons.location_on, color: AppColors.accent),
            tooltip: 'Région',
            onSelected: (r) => setState(() => _selectedRegion = r),
            itemBuilder: (_) => [
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
                .map((r) => PopupMenuItem(
                      value: r,
                      child: Text(r,
                          style: TextStyle(
                            fontWeight: r == _selectedRegion
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )),
                    ))
                .toList(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                Row(
                  children: [
                    _chip('${widget.listings.length} annonces DE', AppColors.accent),
                    const SizedBox(width: 8),
                    _chip('📍 $_selectedRegion', AppColors.accentPurple),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (_loadingPrices)
                          _chip('🔄 LBC...', AppColors.accentOrange)
                        else if (_lbcPrices != null && _lbcPrices!.hasData)
                          _chip(
                            '🟠 LBC: ${_fmt.format(_lbcPrices!.market)}',
                            AppColors.accentOrange,
                          )
                        else
                          _chip('LBC: —', AppColors.textMuted),
                      ],
                    ),
                    _actionChip(
                      'Famille (3+)',
                      Icons.family_restroom,
                      _has3Children,
                      () => setState(() => _has3Children = !_has3Children),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: widget.listings.length,
        itemBuilder: (context, i) => _buildListingCard(widget.listings[i], i),
      ),
    );
  }

  Widget _buildListingCard(CarListing listing, int index) {
    // --- LBC Market Price calculation ---
    double lbcMarketPrice = 0;
    if (_lbcPrices != null && _lbcPrices!.hasData && widget.listings.isNotEmpty) {
      double sumDE = 0;
      for (var l in widget.listings) sumDE += l.price;
      double avgDE = sumDE / widget.listings.length;
      if (avgDE > 0) {
        double ratio = _lbcPrices!.market / avgDE;
        lbcMarketPrice = listing.price * ratio;
      }
    }

    // --- Core Calculation (Recalculé A à Z) ---
    final calc = TaxCalculator();
    final res = calc.calculate(
      listing.toVehicleEntry(region: _selectedRegion),
      childrenCount: _has3Children ? 3 : 0,
      lbcMarketPrice: lbcMarketPrice,
    );

    final profitEU = res.profitEUMarket;
    final marginEU = res.marginEUMarket;
    final riskColorEU = _getRiskColor(marginEU);

    final profitLBC = res.profitFRMarket;
    final marginLBC = res.marginFRMarket;
    final riskColorLBC = _getRiskColor(marginLBC);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _openDetail(listing),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Image ---
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: listing.imageUrls.isNotEmpty
                    ? SizedBox(
                        height: 250,
                        child: PageView.builder(
                          itemCount: listing.imageUrls.length,
                          itemBuilder: (context, index) {
                            return Container(
                              color: AppColors.surfaceLight,
                              child: Image.network(
                                listing.imageUrls[index],
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _imagePlaceholder(),
                                loadingBuilder: (_, child, loading) {
                                  if (loading == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.accent),
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
                padding: const EdgeInsets.all(14),
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
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          listing.priceFormatted,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Specs row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (listing.year != null)
                          _specChip(Icons.calendar_today, '${listing.year}'),
                        if (listing.mileage != null)
                          _specChip(Icons.speed,
                              '${(listing.mileage! / 1000).toStringAsFixed(0)}k km'),
                        if (listing.powerPS != null)
                          _specChip(Icons.bolt, '${listing.powerPS} PS'),
                        if (listing.fuel != null)
                          _specChip(Icons.local_gas_station, listing.fuel!),
                        if (listing.transmission != null)
                          _specChip(Icons.settings, listing.transmission!),
                        if (_has3Children)
                          _specChip(Icons.family_restroom, '-60g CO2', color: AppColors.accentGreen),
                        if (DateTime.now().year - (listing.year ?? DateTime.now().year) > 0)
                          _specChip(Icons.trending_down, '-${(DateTime.now().year - (listing.year ?? DateTime.now().year)) * 10}% Vétusté', color: AppColors.accentCyan),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Profitability preview
                    Row(
                      children: [
                        Expanded(child: _buildMarginBlock('AutoScout (EU)', marginEU, profitEU, riskColorEU, true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMarginBlock('LeBonCoin (FR)', marginLBC, profitLBC, riskColorLBC, marginLBC > 0)),
                      ],
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

  Widget _buildMarginBlock(String source, double margin, double profit, Color riskColor, bool hasData) {
    if (!hasData) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Text('Revente $source', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 2),
            const Text('N/A', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
              const SizedBox(width: 4),
              Text(
                'Marge $source',
                style: TextStyle(color: riskColor, fontWeight: FontWeight.w600, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${profit >= 0 ? '+' : ''}${_fmt.format(profit)}',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: riskColor),
          ),
          Text(
            '${margin.toStringAsFixed(1)}%',
            style: TextStyle(color: riskColor.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold),
          )
        ],
      ),
    );
  }
  Color _getRiskColor(double margin) {
    if (margin < 0) return AppColors.accentRed;
    if (margin >= 25) return AppColors.accentGreen;
    if (margin >= 0) return AppColors.accentOrange;
    return AppColors.textMuted;
  }
  double _estimateCarteGrise(CarListing listing) {
    final calc = TaxCalculator();
    final co2 = listing.co2 ?? _estimateCO2(listing);
    final year = listing.year ?? DateTime.now().year;
    final y1 = calc.calcTaxeRegionale(
        _selectedRegion, listing.estimatedFiscalPower, year, fuelType: listing.fuel, model: listing.model);
    final y3 = calc.calcMalusCO2(co2, year, fuelType: listing.fuel, model: listing.model, childrenCount: _has3Children ? 3 : 0);
    final tmom = calc.calcMalusPoids(listing.estimatedWeightG1, fuelType: listing.fuel, model: listing.model);
    final malusCumule = (y3 + tmom) > 80000 ? 80000 : (y3 + tmom);
    return y1 + malusCumule + 11.0 + 2.76;
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 180,
      color: AppColors.surfaceLight,
      child: const Center(
        child: Icon(Icons.directions_car_rounded,
            size: 48, color: AppColors.textMuted),
      ),
    );
  }

  Widget _specChip(IconData icon, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColors.textSecondary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color ?? AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: color != null ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _actionChip(String text, IconData icon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppColors.accent : AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isActive ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(color: isActive ? AppColors.accent : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
