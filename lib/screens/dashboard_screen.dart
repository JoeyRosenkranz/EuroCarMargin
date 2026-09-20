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
  bool _saving = false;
  bool _editingTechnical = false;
  final _fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

  LeBonCoinListing? _frenchAd;
  bool _loadingFrenchAd = true;

  late CalculationResult _res;
  late TextEditingController _cvController;
  late TextEditingController _co2Controller;
  late TextEditingController _weightController;
  late TextEditingController _transportController;
  late TextEditingController _prepController;
  late TextEditingController _marketController;
  late TextEditingController _proCostsController;

  CalculationResult get r => _res;

  @override
  void initState() {
    super.initState();
    _res = widget.result;

    _cvController = TextEditingController(
      text: _res.vehicle.powerFiscal.toString(),
    );
    _co2Controller = TextEditingController(
      text: _res.vehicle.co2WLTP.toString(),
    );
    _weightController = TextEditingController(
      text: _res.vehicle.weightG1.toString(),
    );
    _transportController = TextEditingController(
      text: _res.vehicle.transportCost.toStringAsFixed(0),
    );
    _prepController = TextEditingController(
      text: _res.vehicle.prepCost.toStringAsFixed(0),
    );
    _marketController = TextEditingController(
      text: _res.resaleFRMarket > 0
          ? _res.resaleFRMarket.toStringAsFixed(0)
          : '',
    );
    _proCostsController = TextEditingController(
      text: _res.proCosts.toStringAsFixed(0),
    );

    _animCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..forward();

    _fetchComparableFrenchAd();
  }

  void _recalculate() {
    final v = _res.vehicle;
    final newCV = int.tryParse(_cvController.text) ?? 0;
    final newCO2 = int.tryParse(_co2Controller.text) ?? 0;
    final newWeight = int.tryParse(_weightController.text) ?? 0;
    final newTransport = double.tryParse(_transportController.text) ?? 0;
    final newPrep = double.tryParse(_prepController.text) ?? 0;
    final newMarket = double.tryParse(_marketController.text) ?? 0;
    final newProCosts = double.tryParse(_proCostsController.text) ?? 0;

    // On ne change la source qu'en cas de modification réelle par rapport à l'annonce
    final updatedVehicle = v.copyWith(
      powerFiscal: newCV,
      co2WLTP: newCO2,
      weightG1: newWeight,
      transportCost: newTransport,
      prepCost: newPrep,
      sourceFiscal: (newCV != v.powerFiscal)
          ? 'Saisie manuelle'
          : (newCV == 0 ? 'Manquant' : v.sourceFiscal),
      sourceCO2: (newCO2 != v.co2WLTP)
          ? 'Saisie manuelle'
          : (newCO2 == 0 ? 'Manquant' : v.sourceCO2),
      sourceWeight: (newWeight != v.weightG1)
          ? 'Saisie manuelle'
          : (newWeight == 0 ? 'Manquant' : v.sourceWeight),
    );
    setState(() {
      _res = TaxCalculator().calculate(
        updatedVehicle,
        childrenCount: (_res.familyCO2Deduction > 0) ? 3 : 0,
        lbcMarketPrice: newMarket,
        lbcQuickPrice: newMarket > 0 ? newMarket * .95 : 0,
        comparableCount: newMarket > 0
            ? (_res.comparableCount >= 3 ? _res.comparableCount : 3)
            : 0,
        proCosts: newProCosts,
        vatOnMargin: _res.vatOnMargin,
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
    _transportController.dispose();
    _prepController.dispose();
    _marketController.dispose();
    _proCostsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    setState(() => _saving = true);
    try {
      final id = await DatabaseHelper.instance.insertSearch(r);
      if (!mounted) return;
      setState(() {
        _saved = id > 0;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Annonce enregistrée dans Dossiers'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enregistrement impossible : $error'),
          backgroundColor: context.appColors.accentRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${r.vehicle.brand} ${r.vehicle.model}'),
        actions: [
          IconButton(
            icon: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _saving || _saved ? null : _save,
            tooltip: _saved ? 'Enregistrée' : 'Enregistrer dans Dossiers',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, _) {
          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              Center(
                child: Image.asset(
                  'assets/logo2.png',
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => SizedBox(),
                ),
              ),
              SizedBox(height: 16),
              // --- Vehicle Image ---
              if (widget.imageUrl != null) _buildVehicleImage(),
              if (widget.imageUrl != null) SizedBox(height: 16),

              // --- Risk Badge ---
              _buildRiskBadge(),
              if (r.warnings.isNotEmpty) ...[
                SizedBox(height: 12),
                _buildWarningsCard(),
              ],
              SizedBox(height: 20),

              // --- Total Investi ---
              _buildTotalCard(),
              SizedBox(height: 16),

              // --- Carte Grise detail ---
              _buildCarteGriseCard(),
              SizedBox(height: 16),

              // --- Chart ---
              _buildCostChart(),
              SizedBox(height: 16),

              // --- Resale estimates ---
              _buildResaleSection(),
              SizedBox(height: 16),

              // --- Profit cards ---
              _buildProfitCards(),
              SizedBox(height: 24),

              // --- Comparable French Ad ---
              _buildFrenchAdSection(),
              SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRiskBadge() {
    final color = context.appColors.riskColor(r.riskLevel.name);
    return SlideTransition(
      position: Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _animCtrl,
              curve: Interval(0, 0.4, curve: Curves.easeOutCubic),
            ),
          ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(0, 0.4),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
                padding: EdgeInsets.all(12),
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
              SizedBox(width: 16),
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
                    SizedBox(height: 2),
                    Text(
                      r.calculationReliable
                          ? 'Marge nette France : ${r.marginFRMarket.toStringAsFixed(1)} %'
                          : 'Résultat à compléter avant décision',
                      style: TextStyle(
                        color: context.appColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                r.calculationReliable ? _fmt.format(r.profitFRMarket) : '—',
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

  Widget _buildWarningsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.accentOrange.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.appColors.accentOrange.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                size: 20,
                color: context.appColors.accentOrange,
              ),
              SizedBox(width: 8),
              Text(
                'Points à vérifier',
                style: TextStyle(
                  color: context.appColors.accentOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...r.warnings.map(
            (warning) => Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '• $warning',
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return _animatedCard(
      interval: Interval(0.1, 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coût économique final',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.appColors.textSecondary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            _fmt.format(r.totalInvested),
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: context.appColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          _detailRow('Achat Allemagne', r.vehicle.purchasePrice),
          _detailRow('Carte grise après remboursement', r.totalCarteGrise),
          _detailRow('Transport', r.vehicle.transportCost),
          _detailRow('Préparation', r.vehicle.prepCost),
          if (r.familyRefund > 0) ...[
            Divider(height: 20),
            _detailRow('Cash à avancer', r.cashRequired),
            _detailRow('Remboursement famille (à déduire)', r.familyRefund),
          ],
        ],
      ),
    );
  }

  Widget _buildCarteGriseCard() {
    final fuel = (r.vehicle.fuelType ?? '').toLowerCase();
    final model = r.vehicle.model.toLowerCase();
    final isEV =
        model.contains('e-tron') ||
        model.contains('tesla') ||
        (fuel.contains('elektro') && !fuel.contains('hybrid'));

    return _animatedCard(
      interval: Interval(0.15, 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: context.appColors.accent,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Détail Carte Grise',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textPrimary,
                ),
              ),
              Spacer(),
              Text(
                _fmt.format(r.cashCarteGrise),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.accent,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _detailRow('Taxe régionale (Y1)', r.taxeRegionale),
          if (!isEV)
            _detailRow(
              'Malus CO₂ après décote${r.ageReductionPct > 0 ? ' (−${r.ageReductionPct} %)' : ''}',
              r.malusCO2,
            ),
          if (!isEV && r.malusCO2BeforeVetuste > r.malusCO2)
            Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text(
                'Malus brut: ${_fmt.format(r.malusCO2BeforeVetuste)}',
                style: TextStyle(
                  color: context.appColors.textMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (!isEV && r.familyCO2Deduction > 0)
            Padding(
              padding: EdgeInsets.only(left: 16, bottom: 4),
              child: Text(
                'Famille : −${r.familyCO2Deduction} g CO₂, remboursés après paiement',
                style: TextStyle(
                  color: context.appColors.accentGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (!isEV && r.ageReductionPct > 0)
            Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'Décote légale liée à l’âge : −${r.ageReductionPct} %',
                style: TextStyle(
                  color: context.appColors.accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (!isEV) _detailRow('Malus Poids (TMOM)', r.malusPoids),
          if (!isEV && r.familyWeightDeduction > 0)
            Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'Abattement poids famille : -${r.familyWeightDeduction}kg',
                style: TextStyle(
                  color: context.appColors.accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (isEV) _detailRow('Malus CO₂ et masse : exonération', 0),
          _detailRow('Taxe fixe (Y4)', r.taxeFixe),
          _detailRow('Acheminement (Y5)', r.redevance),
          if (r.familyRefund > 0) ...[
            Divider(height: 20),
            _detailRow('À payer à l’immatriculation', r.cashCarteGrise),
            _detailRow('Remboursement estimé (à déduire)', r.familyRefund),
            _detailRow('Coût final estimé', r.totalCarteGrise),
          ],
        ],
      ),
    );
  }

  Widget _buildCostChart() {
    final sections = <_ChartEntry>[
      _ChartEntry('Achat', r.vehicle.purchasePrice, context.appColors.accent),
      _ChartEntry('Carte Grise', r.totalCarteGrise, context.appColors.accentPurple),
      _ChartEntry('Transport', r.vehicle.transportCost, context.appColors.accentOrange),
      _ChartEntry('Préparation', r.vehicle.prepCost, context.appColors.accentCyan),
    ].where((e) => e.value > 0).toList();

    return _animatedCard(
      interval: Interval(0.2, 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Répartition des Coûts',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.appColors.textPrimary,
            ),
          ),
          SizedBox(height: 16),
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
                            color: context.appColors.textPrimary,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sections.map((s) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
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
                          SizedBox(width: 8),
                          Text(
                            s.label,
                            style: TextStyle(
                              color: context.appColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
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
      interval: Interval(0.3, 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.store_rounded,
                color: context.appColors.accentGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Revente en France',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (!r.calculationReliable)
            Text(
              'La marge reste masquée tant que les données fiscales et le panel de comparaison ne sont pas fiables.',
              style: TextStyle(color: context.appColors.textSecondary, height: 1.4),
            )
          else ...[
            _resaleRow(
              'Prix médian (${r.comparableCount} comparables)',
              r.resaleFRMarket,
              r.profitFRMarket,
              r.marginFRMarket,
              r.tvaMarginFRMarket,
            ),
            Divider(height: 28),
            _resaleRow(
              'Scénario vente rapide',
              r.resaleFRQuick,
              r.profitFRQuick,
              r.marginFRQuick,
              r.tvaMarginFRQuick,
            ),
            SizedBox(height: 18),
            _buildMarginExplanation(),
          ],
          SizedBox(height: 12),
          Text(
            r.vatOnMargin
                ? 'Hypothèse : régime de TVA sur marge éligible. À confirmer sur la facture d’achat.'
                : 'Hypothèse : TVA sur marge non appliquée.',
            style: TextStyle(color: context.appColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMarginExplanation() {
    final rawGap = r.resaleFRMarket - r.vehicle.purchasePrice;
    final profitColor = r.profitFRMarket >= 0
        ? context.appColors.accentGreen
        : context.appColors.accentRed;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Du prix affiché à la marge réelle',
            style: TextStyle(
              color: context.appColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          _signedRow('Écart France − achat Allemagne', rawGap),
          _signedRow('Carte grise et malus', -r.totalCarteGrise),
          _signedRow('Transport', -r.vehicle.transportCost),
          _signedRow('Préparation', -r.vehicle.prepCost),
          _signedRow('Frais professionnels', -r.proCosts),
          if (r.vatOnMargin)
            _signedRow('TVA sur marge', -r.tvaMarginFRMarket),
          Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bénéfice net estimé',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _fmt.format(r.profitFRMarket),
                style: TextStyle(
                  color: profitColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _signedRow(String label, double value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '${value > 0 ? '+' : ''}${_fmt.format(value)}',
            style: TextStyle(
              color: value >= 0
                  ? context.appColors.accentGreen
                  : context.appColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resaleRow(
    String label,
    double price,
    double profit,
    double margin,
    double tvaSurMarge,
  ) {
    final profitColor = profit >= 0
        ? context.appColors.accentGreen
        : context.appColors.accentRed;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _fmt.format(price),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              if (r.vatOnMargin && tvaSurMarge > 0)
                Text(
                  'TVA s/ Marge (Pro): -${_fmt.format(tvaSurMarge)}',
                  style: TextStyle(
                    color: context.appColors.accentRed,
                    fontSize: 11,
                  ),
                ),
              Text(
                'Frais de Structure Pro: -${_fmt.format(r.proCosts)}',
                style: TextStyle(
                  color: context.appColors.accentRed,
                  fontSize: 11,
                ),
              ),
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
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: profitColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${margin.toStringAsFixed(1)}% net',
                style: TextStyle(
                  color: profitColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfitCards() {
    final mileageLabel = r.vehicle.mileage == null
        ? 'km à vérifier'
        : '${r.vehicle.mileage} km';
    return _animatedCard(
      interval: Interval(0.4, 0.8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Données techniques automatiques',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => _editingTechnical = !_editingTechnical);
                  if (!_editingTechnical) _recalculate();
                },
                icon: Icon(
                  _editingTechnical ? Icons.check_rounded : Icons.edit_outlined,
                  size: 18,
                ),
                label: Text(_editingTechnical ? 'Valider' : 'Corriger'),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            '${r.vehicle.brand} ${r.vehicle.model} ${r.vehicle.trim}',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.appColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildEditableSpec(
                'CV',
                _cvController,
                r.vehicle.sourceFiscal,
                r.vehicle.powerFiscal,
                width: 60,
              ),
              _buildEditableSpec(
                'g/km',
                _co2Controller,
                r.vehicle.sourceCO2,
                r.vehicle.co2WLTP,
                width: 65,
              ),
              _buildEditableSpec(
                'kg',
                _weightController,
                r.vehicle.sourceWeight,
                r.vehicle.weightG1,
                width: 75,
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '${r.vehicle.firstRegistrationMonth.toString().padLeft(2, '0')}/${r.vehicle.year} • $mileageLabel • ${r.vehicle.region}',
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Divider(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Hypothèses modifiables',
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMoneyField('Transport', _transportController),
              _buildMoneyField('Préparation', _prepController),
              _buildMoneyField(
                'Marché FR vérifié',
                _marketController,
                width: 150,
              ),
              _buildMoneyField('Frais pro', _proCostsController),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyField(
    String label,
    TextEditingController controller, {
    double width = 120,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: (_) => _recalculate(),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: '€',
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildVehicleImage() {
    return _animatedCard(
      interval: Interval(0, 0.3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          widget.imageUrl!,
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          headers: {'Accept': 'image/webp,image/*'},
          errorBuilder: (_, _, _) => Container(
            height: 200,
            color: context.appColors.surfaceLight,
            child: Center(
              child: Icon(
                Icons.directions_car_rounded,
                size: 48,
                color: context.appColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrenchAdSection() {
    if (_loadingFrenchAd) {
      return Center(child: CircularProgressIndicator());
    }

    if (_frenchAd == null) {
      return Container(); // Invisible if no match found
    }

    return _animatedCard(
      interval: Interval(0.5, 0.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.compare_arrows_rounded,
                color: context.appColors.accentCyan,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Annonce similaire en France',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appColors.cardBorder),
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
                          color: context.appColors.surface,
                          child: Icon(
                            Icons.car_rental,
                            color: context.appColors.textMuted,
                          ),
                        ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _frenchAd!.title,
                        style: TextStyle(
                          color: context.appColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        _fmt.format(_frenchAd!.price),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.appColors.accent,
                        ),
                      ),
                      SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (_frenchAd!.year != null)
                            Text(
                              '📅 ${_frenchAd!.year}',
                              style: TextStyle(
                                color: context.appColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          if (_frenchAd!.mileage != null)
                            Text(
                              '🏃 ${_frenchAd!.mileage} km',
                              style: TextStyle(
                                color: context.appColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          if (_frenchAd!.fuel != null)
                            Text(
                              '⛽ ${_frenchAd!.fuel}',
                              style: TextStyle(
                                color: context.appColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          if (_frenchAd!.location != null)
                            Text(
                              '📍 ${_frenchAd!.location}',
                              style: TextStyle(
                                color: context.appColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable helpers ---

  Widget _animatedCard({required Interval interval, required Widget child}) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _animCtrl, curve: interval)),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _animCtrl, curve: interval),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: Offset(0, 4),
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
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value <= 0
                ? (label.contains('Y') ||
                          label.contains('Malus') ||
                          label.contains('Taxe')
                      ? '0 € (Exonéré)'
                      : '0 €')
                : _fmt.format(value),
            style: TextStyle(
              color: value <= 0 ? context.appColors.accentGreen : context.appColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableSpec(
    String suffix,
    TextEditingController controller,
    String source,
    int value, {
    double width = 45,
  }) {
    final bool isMissing = value <= 0;
    if (!_editingTechnical) {
      return Container(
        constraints: BoxConstraints(minWidth: 92),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isMissing
              ? context.appColors.accentRed.withValues(alpha: 0.08)
              : context.appColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMissing
                ? context.appColors.accentRed.withValues(alpha: 0.35)
                : context.appColors.cardBorder,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isMissing ? '—' : '$value $suffix',
              style: GoogleFonts.outfit(
                color: isMissing
                    ? context.appColors.accentRed
                    : context.appColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2),
            Text(
              source,
              style: TextStyle(
                color: context.appColors.textMuted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      );
    }
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
              color: isMissing ? Colors.red : context.appColors.accent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              suffixText: suffix.isEmpty ? null : ' $suffix',
              suffixStyle: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.normal,
              ),
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: isMissing ? Colors.red : context.appColors.accent,
                ),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: (isMissing ? Colors.red : context.appColors.accent).withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: isMissing ? Colors.red : context.appColors.accent,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 2),
        Text(
          source,
          style: TextStyle(
            color: source == 'Manquant'
                ? Colors.red.withValues(alpha: 0.7)
                : context.appColors.textSecondary.withValues(alpha: 0.5),
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
  _ChartEntry(this.label, this.value, this.color);
}
