import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/car_brands_data.dart';
import '../theme/app_theme.dart';
import '../services/autoscout_service.dart';
import '../widgets/brand_header.dart';
import 'results_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  bool _loading = false;

  String? _selectedBrand;
  String? _selectedModel;
  bool _isCustomModel = false;
  final _customModelCtrl = TextEditingController();
  final _transportCtrl = TextEditingController(text: '800');
  final _prepCtrl = TextEditingController(text: '500');
  final _proCostsCtrl = TextEditingController(text: '1500');
  bool _vatOnMargin = true;
  RangeValues _priceRange = const RangeValues(500, 35000);
  late RangeValues _yearRange;
  double _kmMax = 150000;

  static const double _minimumYear = 1990;
  double get _currentYear => DateTime.now().year.toDouble();

  List<String> get _availableModels {
    if (_selectedBrand == null) return [];
    return getModelsForBrand(_selectedBrand!);
  }

  String get _effectiveModel {
    if (_isCustomModel) return _customModelCtrl.text.trim();
    return _selectedModel ?? '';
  }

  @override
  void initState() {
    super.initState();
    _yearRange = RangeValues(_minimumYear, _currentYear);
    _animCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _customModelCtrl.dispose();
    _transportCtrl.dispose();
    _prepCtrl.dispose();
    _proCostsCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_selectedBrand == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner une marque')),
      );
      return;
    }
    final transportCost = double.tryParse(_transportCtrl.text) ?? 0;
    final prepCost = double.tryParse(_prepCtrl.text) ?? 0;
    final proCosts = double.tryParse(_proCostsCtrl.text) ?? 0;
    if (transportCost <= 0 || prepCost < 0 || proCosts < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vérifiez les hypothèses de coûts avant la recherche.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final service = AutoScoutService();
      final modelQuery = _effectiveModel.isNotEmpty ? _effectiveModel : null;
      final listings = await service.searchListings(
        brand: _selectedBrand!,
        model: modelQuery,
        priceFrom: _priceRange.start.toInt(),
        priceTo: _priceRange.end.toInt(),
        yearFrom: _yearRange.start.toInt(),
        yearTo: _yearRange.end.toInt(),
        kmTo: _kmMax.toInt(),
      );

      if (!mounted) return;

      if (listings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Aucune annonce trouvée. Essayez d\'élargir vos critères.',
            ),
          ),
        );
        setState(() => _loading = false);
        return;
      }

      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => ResultsScreen(
            listings: listings,
            brand: _selectedBrand!,
            model: _effectiveModel,
            transportCost: transportCost,
            prepCost: prepCost,
            proCosts: proCosts,
            vatOnMargin: _vatOnMargin,
          ),
          transitionsBuilder: (_, anim, _, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: Offset(1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                  ),
              child: child,
            );
          },
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Recherche AutoScout24 impossible: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Aucune annonce trouvée. Modifiez les filtres puis réessayez.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
        child: CustomScrollView(
          slivers: [
            const BrandSliverHeader(),
            SliverPadding(
              padding: EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchIntro(),
                    SizedBox(height: 24),
                    // --- Marque ---
                    _sectionLabel('Marque'),
                    SizedBox(height: 8),
                    _glassCard(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedBrand,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.directions_car),
                          border: InputBorder.none,
                          hintText: 'Choisir une marque',
                          filled: false,
                        ),
                        dropdownColor: context.appColors.surfaceLight,
                        isExpanded: true,
                        isDense: true,
                        icon: Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                        menuMaxHeight: 400,
                        selectedItemBuilder: (context) => sortedBrands
                            .map((brand) => compactDropdownText(context, brand))
                            .toList(),
                        items: sortedBrands
                            .map(
                              (b) => DropdownMenuItem(
                                value: b,
                                child: compactDropdownText(context, b),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedBrand = v;
                            _selectedModel = null;
                            _isCustomModel = false;
                            _customModelCtrl.clear();
                          });
                        },
                      ),
                    ),

                    SizedBox(height: 16),

                    // --- Modèle ---
                    _sectionLabel('Modèle'),
                    SizedBox(height: 8),
                    _glassCard(
                      child: _isCustomModel
                          ? TextFormField(
                              controller: _customModelCtrl,
                              decoration: InputDecoration(
                                hintText: 'Saisir le modèle...',
                                prefixIcon: Icon(Icons.edit),
                                border: InputBorder.none,
                                suffixIcon: _availableModels.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.list, size: 20),
                                        tooltip: 'Revenir à la liste',
                                        onPressed: () => setState(() {
                                          _isCustomModel = false;
                                          _customModelCtrl.clear();
                                        }),
                                      )
                                    : null,
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              initialValue: _selectedModel,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.model_training),
                                border: InputBorder.none,
                                hintText: 'Choisir un modèle',
                                filled: false,
                              ),
                              dropdownColor: context.appColors.surfaceLight,
                              isExpanded: true,
                              isDense: true,
                              icon: Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.keyboard_arrow_down_rounded),
                              ),
                              menuMaxHeight: 400,
                              selectedItemBuilder: (context) => [
                                ..._availableModels.map(
                                  (model) =>
                                      compactDropdownText(context, model),
                                ),
                                compactDropdownText(
                                  context,
                                  'Autre modèle',
                                  fontStyle: FontStyle.italic,
                                ),
                              ],
                              items: [
                                ..._availableModels.map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: compactDropdownText(context, m),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: '__custom__',
                                  child: compactDropdownText(
                                    context,
                                    'Autre modèle…',
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              onChanged: _selectedBrand == null
                                  ? null
                                  : (v) {
                                      if (v == '__custom__') {
                                        setState(() => _isCustomModel = true);
                                      } else {
                                        setState(() => _selectedModel = v);
                                      }
                                    },
                            ),
                    ),

                    SizedBox(height: 24),

                    // --- Plage de prix ---
                    _sliderSection(
                      icon: Icons.euro,
                      label: 'Prix min. — max.',
                      value: '${_formatNumber(_priceRange.start)} — '
                          '${_formatNumber(_priceRange.end)} €',
                      slider: RangeSlider(
                        values: _priceRange,
                        min: 500,
                        max: 150000,
                        divisions: 299,
                        labels: RangeLabels(
                          '${_formatNumber(_priceRange.start)} €',
                          '${_formatNumber(_priceRange.end)} €',
                        ),
                        activeColor: context.appColors.accent,
                        inactiveColor: context.appColors.cardBorder,
                        onChanged: (v) => setState(() => _priceRange = v),
                      ),
                    ),

                    SizedBox(height: 12),

                    // --- Plage d'années ---
                    _sliderSection(
                      icon: Icons.calendar_today,
                      label: 'Année min. — max.',
                      value: '${_yearRange.start.toInt()} — '
                          '${_yearRange.end.toInt()}',
                      slider: RangeSlider(
                        values: _yearRange,
                        min: _minimumYear,
                        max: _currentYear,
                        divisions: (_currentYear - _minimumYear).toInt(),
                        labels: RangeLabels(
                          _yearRange.start.toInt().toString(),
                          _yearRange.end.toInt().toString(),
                        ),
                        activeColor: context.appColors.accentPurple,
                        inactiveColor: context.appColors.cardBorder,
                        onChanged: (v) => setState(() => _yearRange = v),
                      ),
                    ),

                    SizedBox(height: 12),

                    // --- Km Max ---
                    _sliderSection(
                      icon: Icons.speed,
                      label: 'Kilométrage max',
                      value:
                          '${_kmMax.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} km',
                      slider: Slider(
                        value: _kmMax,
                        min: 10000,
                        max: 300000,
                        divisions: 29,
                        activeColor: context.appColors.accentOrange,
                        inactiveColor: context.appColors.cardBorder,
                        onChanged: (v) => setState(() => _kmMax = v),
                      ),
                    ),

                    SizedBox(height: 24),
                    _sectionLabel('Hypothèses de rentabilité'),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.appColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.appColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          _responsivePair(
                            _costField(
                              'Transport',
                              _transportCtrl,
                              Icons.local_shipping_outlined,
                            ),
                            _costField(
                              'Préparation',
                              _prepCtrl,
                              Icons.build_outlined,
                            ),
                          ),
                          SizedBox(height: 10),
                          _costField(
                            'Frais professionnels / véhicule',
                            _proCostsCtrl,
                            Icons.business_center_outlined,
                          ),
                          Material(
                            color: Colors.transparent,
                            child: SwitchListTile.adaptive(
                              value: _vatOnMargin,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (value) =>
                                  setState(() => _vatOnMargin = value),
                              title: Text('TVA sur marge'),
                              subtitle: Text(
                                'Hypothèse prudente, à confirmer selon la facture du vendeur.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    // --- Search Button ---
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [context.appColors.gradientStart, context.appColors.accent],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.appColors.accent.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _search,
                          icon: _loading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(Icons.search_rounded, size: 24),
                          label: Text(
                            _loading
                                ? 'Recherche en cours...'
                                : 'Rechercher sur AutoScout24',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // --- Info Card ---
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.appColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.appColors.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: context.appColors.accent,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Analyse croisée Allemagne / France. La marge n’est affichée qu’avec '
                              'au moins 3 annonces comparables et les données fiscales vérifiées '
                              '(P.6, V.7 et masse G).',
                              style: TextStyle(
                                color: context.appColors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchIntro() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.appColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: -14,
            child: Icon(
              Icons.speed_rounded,
              size: 88,
              color: context.appColors.accent.withValues(alpha: .08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: context.appColors.accentOrange.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'MARCHÉ ALLEMAND',
                  style: GoogleFonts.outfit(
                    color: context.appColors.accentOrange,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Repérez les véhicules\nrentables en France.',
                style: GoogleFonts.outfit(
                  color: context.appColors.textPrimary,
                  fontSize: 25,
                  height: 1.08,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Prix réel, fiscalité et marché français dans une seule analyse.',
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _introChip(Icons.euro_rounded, 'Coût net'),
                  _introChip(Icons.verified_outlined, 'Données vérifiées'),
                  _introChip(Icons.compare_arrows_rounded, 'DE → FR'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _introChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: context.appColors.surfaceLight,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: context.appColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.appColors.accent),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.appColors.textSecondary,
      ),
    );
  }

  String _formatNumber(double value) => value
      .round()
      .toString()
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]} ',
      );

  Widget _costField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixText: '€',
      ),
    );
  }

  Widget _responsivePair(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            children: [first, SizedBox(height: 10), second],
          );
        }
        return Row(
          children: [
            Expanded(child: first),
            SizedBox(width: 10),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.cardBorder),
      ),
      child: child,
    );
  }

  Widget _sliderSection({
    required IconData icon,
    required String label,
    required String value,
    required Widget slider,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .07),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.appColors.accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: context.appColors.accent, size: 17),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.textPrimary,
                ),
              ),
            ],
          ),
          slider,
        ],
      ),
    );
  }
}
