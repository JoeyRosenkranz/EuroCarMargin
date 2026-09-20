import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/calculation_result.dart';
import '../services/database_helper.dart';
import '../services/leboncoin_service.dart';
import '../services/tax_calculator.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final CalculationResult result;
  final String? imageUrl;
  final String? listingUrl;
  const DashboardScreen({
    super.key,
    required this.result,
    this.imageUrl,
    this.listingUrl,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animCtrl;
  bool _saved = false;
  final _fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
  
  LeBonCoinListing? _frenchAd;
  bool _loadingFrenchAd = true;

  late CalculationResult _res;
  late TextEditingController _cvController;
  late TextEditingController _co2Controller;
  late TextEditingController _weightController;

  CalculationResult get r => _res;

  @override
  void initState() {
    super.initState();
    _res = widget.result;
    
    _cvController = TextEditingController(text: _res.vehicle.powerFiscal.toString());
    _co2Controller = TextEditingController(text: _res.vehicle.co2WLTP.toString());
    _weightController = TextEditingController(text: _res.vehicle.weightG1.toString());

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    
    _fetchComparableFrenchAd();
  }

  void _recalculate() {
    final v = _res.vehicle;
    final newCV = int.tryParse(_cvController.text) ?? 0;
    final newCO2 = int.tryParse(_co2Controller.text) ?? 0;
    final newWeight = int.tryParse(_weightController.text) ?? 0;

    // On ne change la source qu'en cas de modification réelle par rapport à l'annonce
    final updatedVehicle = v.copyWith(
      powerFiscal: newCV,
      co2WLTP: newCO2,
      weightG1: newWeight,
      sourceFiscal: (newCV != v.powerFiscal) ? 'Saisie manuelle' : (newCV == 0 ? 'Manquant' : v.sourceFiscal),
      sourceCO2: (newCO2 != v.co2WLTP) ? 'Saisie manuelle' : (newCO2 == 0 ? 'Manquant' : v.sourceCO2),
      sourceWeight: (newWeight != v.weightG1) ? 'Saisie manuelle' : (newWeight == 0 ? 'Manquant' : v.sourceWeight),
    );
    setState(() {
      _res = TaxCalculator().calculate(
        updatedVehicle,
        childrenCount: (_res.familyCO2Deduction > 0) ? 3 : 0,
        lbcMarketPrice: _res.resaleFRMarket,
        lbcQuickPrice: _res.resaleFRQuick,
      );
    });
  }

  void _scanListing() {
    final v = _res.vehicle;
    final fullText = '${v.brand} ${v.model} ${v.trim} ${v.rawDescription ?? ''}'.toLowerCase();
    
    int? extractedCV;
    int? extractedCO2;
    int? extractedWeight;

    final cvMatch = RegExp(r'(\d+)\s*cv').firstMatch(fullText);
    if (cvMatch != null) extractedCV = int.tryParse(cvMatch.group(1)!);

    final co2Match = RegExp(r'(\d+)\s*(g/km|g)').firstMatch(fullText);
    if (co2Match != null) extractedCO2 = int.tryParse(co2Match.group(1)!);

    final weightMatch = RegExp(r'(\d{4})\s*kg').firstMatch(fullText);
    if (weightMatch != null) extractedWeight = int.tryParse(weightMatch.group(1)!);

    if (extractedCV != null) _cvController.text = extractedCV.toString();
    if (extractedCO2 != null) _co2Controller.text = extractedCO2.toString();
    if (extractedWeight != null) _weightController.text = extractedWeight.toString();

    final updatedVehicle = v.copyWith(
      powerFiscal: extractedCV ?? v.powerFiscal,
      co2WLTP: extractedCO2 ?? v.co2WLTP,
      weightG1: extractedWeight ?? v.weightG1,
      sourceFiscal: extractedCV != null ? 'Annonce' : v.sourceFiscal,
      sourceCO2: extractedCO2 != null ? 'Annonce' : v.sourceCO2,
      sourceWeight: extractedWeight != null ? 'Annonce' : v.sourceWeight,
    );

    setState(() {
      _res = TaxCalculator().calculate(
        updatedVehicle,
        childrenCount: (_res.familyCO2Deduction > 0) ? 3 : 0,
        lbcMarketPrice: _res.resaleFRMarket,
        lbcQuickPrice: _res.resaleFRQuick,
      );
    });
  }

  Future<void> _fetchComparableFrenchAd() async {
    try {
      final service = LeBonCoinService();
      final result = await service.fetchPrices(
        brand: r.vehicle.brand,
        model: r.vehicle.model,
        yearFrom: r.vehicle.year,
        yearTo: r.vehicle.year, // Try matching exact year first
      );
      if (mounted) {
        setState(() {
          if (result.listings.isNotEmpty) {
            _frenchAd = result.listings.first;
          }
          _loadingFrenchAd = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFrenchAd = false);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _cvController.dispose();
    _co2Controller.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await DatabaseHelper.instance.insertSearch(r);
    setState(() => _saved = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Recherche sauvegardée'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fuel = (r.vehicle.fuelType ?? '').toLowerCase();
    final model = r.vehicle.model.toLowerCase();
    final isEV = model.contains('e-tron') || model.contains('tesla') || 
                 (fuel.contains('elektro') && !fuel.contains('hybrid'));

    return Scaffold(
      appBar: AppBar(
        title: Text('${r.vehicle.brand} ${r.vehicle.model}'),
        actions: [
          IconButton(
            icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _saved ? null : _save,
            tooltip: 'Sauvegarder',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Image.asset('assets/logo2.png', height: 60, fit: BoxFit.contain, errorBuilder: (ctx, err, stack) => const SizedBox()),
              ),
              const SizedBox(height: 16),
              // --- Vehicle Image ---
              if (widget.imageUrl != null) _buildVehicleImage(),
              if (widget.imageUrl != null) const SizedBox(height: 16),

              // --- Risk Badge ---
              _buildRiskBadge(),
              const SizedBox(height: 20),



              // --- Total Investi ---
              _buildTotalCard(),
              const SizedBox(height: 16),

              // --- Carte Grise detail ---
              _buildCarteGriseCard(),
              const SizedBox(height: 16),

              // --- Chart ---
              _buildCostChart(),
              const SizedBox(height: 16),

              // --- Resale estimates ---
              _buildResaleSection(),
              const SizedBox(height: 16),

              // --- Profit cards ---
              _buildProfitCards(),
              const SizedBox(height: 24),
              
              // --- Comparable French Ad ---
              _buildFrenchAdSection(),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildEVErrorBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentRed, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.accentRed, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ERREUR : Détection de Malus CO2 sur véhicule électrique impossible',
                  style: const TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Une taxe de ${_fmt.format(r.totalCarteGrise)} est détectée sur ce véhicule électrique. L\'affichage ne bloque plus la vue, mais vérifiez manuellement la configuration.',
            style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.8), fontSize: 13),
          )
        ],
      ),
    );
  }

  Widget _buildCriticalErrorBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentRed, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.accentRed, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ERREUR DE DONNÉES - VÉRIFICATION MANUELLE REQUISE',
                  style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bénéfice calculé irréaliste (<0% ou >25%). Les marges indiquées importées sont potentiellement hors marché pour cette configuration précise.',
                  style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.8), fontSize: 13),
                )
              ],
            ),
          )
        ],
      )
    );
  }

  Widget _buildRiskBadge() {
    final color = AppColors.riskColor(r.riskLevel.name);
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0, 0.4, curve: Curves.easeOutCubic),
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animCtrl,
          curve: const Interval(0, 0.4),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  r.riskLevel == RiskLevel.green
                      ? Icons.trending_up_rounded
                      : r.riskLevel == RiskLevel.orange
                          ? Icons.trending_flat_rounded
                          : Icons.trending_down_rounded,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.riskLevel.label,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Marge réelle France (LBC): ${r.marginFRMarket.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Text(
                _fmt.format(r.profitFRMarket > 0 ? r.profitFRMarket : r.profitEUMarket),
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    return _animatedCard(
      interval: const Interval(0.1, 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Investi',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              )),
          const SizedBox(height: 4),
          Text(
            _fmt.format(r.totalInvested),
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _detailRow('Achat Allemagne', r.vehicle.purchasePrice),
          _detailRow('Carte Grise', r.totalCarteGrise),
          _detailRow('Transport', r.vehicle.transportCost),
          _detailRow('Préparation', r.vehicle.prepCost),
        ],
      ),
    );
  }

  Widget _buildCarteGriseCard() {
    final fuel = (r.vehicle.fuelType ?? '').toLowerCase();
    final model = r.vehicle.model.toLowerCase();
    final isEV = model.contains('e-tron') || model.contains('tesla') || 
                 (fuel.contains('elektro') && !fuel.contains('hybrid'));

    return _animatedCard(
      interval: const Interval(0.15, 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined,
                  color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text('Détail Carte Grise',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
              const Spacer(),
              Text(
                _fmt.format(r.totalCarteGrise),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isEV) _detailRow('Taxe Régionale (Y1)', r.taxeRegionale),
          if (!isEV)
            _detailRow(
              'Malus CO₂ (Y3)${r.vetustYears > 0 ? ' — vétusté ${r.vetustYears} ans (−${r.vetustYears * 10}%)' : ''}',
              r.malusCO2,
            ),
          if (!isEV && r.malusCO2BeforeVetuste > r.malusCO2)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'Malus brut: ${_fmt.format(r.malusCO2BeforeVetuste)}',
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic),
              ),
            ),
          if (!isEV && r.familyCO2Deduction > 0)
             Padding(
               padding: const EdgeInsets.only(left: 16, bottom: 4),
               child: Text(
                 'Abattement Famille: -${r.familyCO2Deduction}g CO2',
                 style: const TextStyle(color: AppColors.accentGreen, fontSize: 12, fontWeight: FontWeight.w600),
               ),
             ),
          if (!isEV && r.ageReductionPct > 0)
             Padding(
               padding: const EdgeInsets.only(left: 16, bottom: 8),
               child: Text(
                 'Réduction vétusté appliquée: -${r.ageReductionPct}%',
                 style: const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w600),
               ),
             ),
          if (!isEV) _detailRow('Malus Poids (TMOM)', r.malusPoids),
          if (!isEV && r.familyWeightDeduction > 0)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'Abattement poids famille : -${r.familyWeightDeduction}kg',
                style: const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          if (isEV)
            _detailRow('Exonération Fiscale (Y1, Y3, TMOM)', 0),
          _detailRow('Taxe fixe (Y4)', r.taxeFixe),
          _detailRow('Acheminement (Y5)', r.redevance),
        ],
      ),
    );
  }

  Widget _buildCostChart() {
    final sections = <_ChartEntry>[
      _ChartEntry('Achat', r.vehicle.purchasePrice, AppColors.accent),
      _ChartEntry('Carte Grise', r.totalCarteGrise, AppColors.accentPurple),
      _ChartEntry('Transport', r.vehicle.transportCost, AppColors.accentOrange),
      _ChartEntry('Préparation', r.vehicle.prepCost, AppColors.accentCyan),
    ].where((e) => e.value > 0).toList();

    return _animatedCard(
      interval: const Interval(0.2, 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Répartition des Coûts',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: sections.map((s) {
                        final pct = s.value / r.totalInvested * 100;
                        return PieChartSectionData(
                          color: s.color,
                          value: s.value,
                          radius: 60,
                          title: '${pct.toStringAsFixed(0)}%',
                          titleStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sections.map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: s.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(s.label,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResaleSection() {
    return _animatedCard(
      interval: const Interval(0.3, 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.store_rounded,
                  color: AppColors.accentGreen, size: 20),
              const SizedBox(width: 8),
              Text('Estimations de Revente',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
               0: FlexColumnWidth(2),
               1: FlexColumnWidth(1.5),
               2: FlexColumnWidth(1.5),
            },
            children: [
               TableRow(
                 children: [
                   const Text('SOURCE', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                   const Text('PRIX MARCHÉ', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                   const Text('PRIX RAPIDE', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                 ]
               ),
               const TableRow(children: [SizedBox(height: 12), SizedBox(height: 12), SizedBox(height: 12)]),
               TableRow(
                 children: [
                   const Text('🇪🇺 AutoScout24', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                   Text(_fmt.format(r.resaleEUMarket), style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
                   Text(_fmt.format(r.resaleEUQuick), style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
                 ]
               ),
               const TableRow(children: [SizedBox(height: 12), SizedBox(height: 12), SizedBox(height: 12)]),
               TableRow(
                 children: [
                   const Text('🇫🇷 LeBonCoin PRO', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                   Text(r.resaleFRMarket > 0 ? _fmt.format(r.resaleFRMarket) : 'N/A', style: GoogleFonts.outfit(color: AppColors.accentCyan, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
                   Text(r.resaleFRQuick > 0 ? _fmt.format(r.resaleFRQuick) : 'N/A', style: GoogleFonts.outfit(color: AppColors.accentCyan, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
                 ]
               ),
            ]
          )
        ],
      ),
    );
  }

  Widget _resaleRow(
      String label, double price, double profit, double margin, double tvaSurMarge) {
    final profitColor = profit >= 0 ? AppColors.accentGreen : AppColors.accentRed;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              Text(_fmt.format(price),
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 4),
              if (profit > 0)
                 Text('TVA s/ Marge (Pro): -${_fmt.format(tvaSurMarge)}', 
                    style: const TextStyle(color: AppColors.accentRed, fontSize: 11)),
              Text('Frais de Structure Pro: -${_fmt.format(r.proCosts)}', 
                    style: const TextStyle(color: AppColors.accentRed, fontSize: 11)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${profit >= 0 ? '+' : ''}${_fmt.format(profit)}',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: profitColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: profitColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4)
              ),
              child: Text(
                '${margin.toStringAsFixed(1)}% net',
                style: TextStyle(color: profitColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildProfitCards() {
    return _animatedCard(
      interval: const Interval(0.4, 0.8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 32), // Spacer
              Text('Véhicule',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  )),
              IconButton(
                icon: const Icon(Icons.document_scanner_outlined, color: AppColors.accent, size: 20),
                onPressed: _scanListing,
                tooltip: 'LIRE L\'ANNONCE',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${r.vehicle.brand} ${r.vehicle.model} ${r.vehicle.trim}',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildEditableSpec('CV', _cvController, r.vehicle.sourceFiscal, r.vehicle.powerFiscal, width: 60),
              _buildEditableSpec('g/km', _co2Controller, r.vehicle.sourceCO2, r.vehicle.co2WLTP, width: 65),
              _buildEditableSpec('kg', _weightController, r.vehicle.sourceWeight, r.vehicle.weightG1, width: 75),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${r.vehicle.year} • ${r.vehicle.powerDIN} ch DIN • ${r.vehicle.region}',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleImage() {
    return _animatedCard(
      interval: const Interval(0, 0.3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          widget.imageUrl!,
          height: 250,
          width: double.infinity,
          fit: BoxFit.contain, // Fit to prevent cropping
          errorBuilder: (_, __, ___) => Container(
            height: 200,
            color: AppColors.surfaceLight,
            child: const Center(
              child: Icon(Icons.directions_car_rounded,
                  size: 48, color: AppColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFrenchAdSection() {
    if (_loadingFrenchAd) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_frenchAd == null) {
      return Container(); // Invisible if no match found
    }
    
    return _animatedCard(
      interval: const Interval(0.5, 0.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded, color: AppColors.accentCyan, size: 20),
              const SizedBox(width: 8),
              Text('Annonce similaire en France',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _frenchAd!.imageUrl != null
                      ? Image.network(
                          _frenchAd!.imageUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: AppColors.surface,
                          child: const Icon(Icons.car_rental, color: AppColors.textMuted),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _frenchAd!.title,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fmt.format(_frenchAd!.price),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (_frenchAd!.year != null)
                             Text('📅 ${_frenchAd!.year}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          if (_frenchAd!.mileage != null)
                             Text('🏃 ${_frenchAd!.mileage} km', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          if (_frenchAd!.fuel != null)
                             Text('⛽ ${_frenchAd!.fuel}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (_frenchAd!.location != null)
                             Text('📍 ${_frenchAd!.location}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            )
          )
        ],
      ),
    );
  }

  // --- Reusable helpers ---

  Widget _animatedCard(
      {required Interval interval, required Widget child}) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _animCtrl, curve: interval)),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _animCtrl, curve: interval),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _detailRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ),
          Text(value <= 0 ? (label.contains('Y') || label.contains('Malus') || label.contains('Taxe') ? '0 € (Exonéré)' : '0 €') : _fmt.format(value),
              style: TextStyle(
                  color: value <= 0 ? AppColors.accentGreen : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEditableSpec(String suffix, TextEditingController controller, String source, int value, {double width = 45}) {
    final bool isMissing = value <= 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            onChanged: (_) => _recalculate(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isMissing ? Colors.red : AppColors.accent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              suffixText: suffix.isEmpty ? null : ' $suffix',
              suffixStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.normal),
              border: UnderlineInputBorder(borderSide: BorderSide(color: isMissing ? Colors.red : AppColors.accent)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: (isMissing ? Colors.red : AppColors.accent).withValues(alpha: 0.3))),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: isMissing ? Colors.red : AppColors.accent, width: 2)),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          source,
          style: TextStyle(
            color: source == 'Manquant' ? Colors.red.withValues(alpha: 0.7) : AppColors.textSecondary.withValues(alpha: 0.5),
            fontSize: 9,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _ChartEntry {
  final String label;
  final double value;
  final Color color;
  const _ChartEntry(this.label, this.value, this.color);
}
