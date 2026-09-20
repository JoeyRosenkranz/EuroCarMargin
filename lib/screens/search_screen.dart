import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/car_brands_data.dart';
import '../theme/app_theme.dart';
import '../services/autoscout_service.dart';
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
  double _priceMax = 35000;
  double _yearMin = 2018;
  double _kmMax = 150000;

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
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _customModelCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_selectedBrand == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une marque')),
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
        priceTo: _priceMax.toInt(),
        yearFrom: _yearMin.toInt(),
        kmTo: _kmMax.toInt(),
      );

      if (!mounted) return;

      if (listings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune annonce trouvée. Essayez d\'élargir vos critères.'),
          ),
        );
        setState(() => _loading = false);
        return;
      }

      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ResultsScreen(
            listings: listings,
            brand: _selectedBrand!,
            model: _effectiveModel,
          ),
          transitionsBuilder: (_, anim, __, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
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
            SliverAppBar(
              expandedHeight: 140,
              floating: true,
              pinned: true,
              backgroundColor: AppColors.surface,
              flexibleSpace: FlexibleSpaceBar(
                title: Text('EuroCar Margin',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    )),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1a237e),
                        AppColors.surface,
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 50, right: 20),
                      child: Image.asset('assets/logo2.png', height: 48, fit: BoxFit.contain, errorBuilder: (ctx, err, stack) => const Text('🇩🇪 → 🇫🇷', style: TextStyle(fontSize: 32))),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Marque ---
                    _sectionLabel('Marque'),
                    const SizedBox(height: 8),
                    _glassCard(
                      child: DropdownButtonFormField<String>(
                        value: _selectedBrand,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.directions_car),
                          border: InputBorder.none,
                          hintText: 'Choisir une marque',
                        ),
                        dropdownColor: AppColors.surfaceLight,
                        isExpanded: true,
                        menuMaxHeight: 400,
                        items: sortedBrands
                            .map((b) => DropdownMenuItem(
                                  value: b,
                                  child: Text(b),
                                ))
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

                    const SizedBox(height: 16),

                    // --- Modèle ---
                    _sectionLabel('Modèle'),
                    const SizedBox(height: 8),
                    _glassCard(
                      child: _isCustomModel
                          ? TextFormField(
                              controller: _customModelCtrl,
                              decoration: InputDecoration(
                                hintText: 'Saisir le modèle...',
                                prefixIcon: const Icon(Icons.edit),
                                border: InputBorder.none,
                                suffixIcon: _availableModels.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.list, size: 20),
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
                              value: _selectedModel,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.model_training),
                                border: InputBorder.none,
                                hintText: 'Choisir un modèle',
                              ),
                              dropdownColor: AppColors.surfaceLight,
                              isExpanded: true,
                              menuMaxHeight: 400,
                              items: [
                                ..._availableModels.map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    )),
                                const DropdownMenuItem(
                                  value: '__custom__',
                                  child: Text('✏️ Autre modèle...',
                                      style: TextStyle(fontStyle: FontStyle.italic)),
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

                    const SizedBox(height: 24),

                    // --- Prix Max ---
                    _sliderSection(
                      icon: Icons.euro,
                      label: 'Prix max',
                      value: '${_priceMax.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €',
                      slider: Slider(
                        value: _priceMax,
                        min: 3000,
                        max: 100000,
                        divisions: 97,
                        activeColor: AppColors.accent,
                        inactiveColor: AppColors.cardBorder,
                        onChanged: (v) =>
                            setState(() => _priceMax = v),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // --- Année min ---
                    _sliderSection(
                      icon: Icons.calendar_today,
                      label: 'Année min',
                      value: _yearMin.toInt().toString(),
                      slider: Slider(
                        value: _yearMin,
                        min: 2005,
                        max: 2026,
                        divisions: 21,
                        activeColor: AppColors.accentPurple,
                        inactiveColor: AppColors.cardBorder,
                        onChanged: (v) =>
                            setState(() => _yearMin = v),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // --- Km Max ---
                    _sliderSection(
                      icon: Icons.speed,
                      label: 'Kilométrage max',
                      value: '${_kmMax.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} km',
                      slider: Slider(
                        value: _kmMax,
                        min: 10000,
                        max: 300000,
                        divisions: 29,
                        activeColor: AppColors.accentOrange,
                        inactiveColor: AppColors.cardBorder,
                        onChanged: (v) =>
                            setState(() => _kmMax = v),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // --- Search Button ---
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1a237e), AppColors.accent],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _search,
                          icon: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.search_rounded, size: 24),
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

                    const SizedBox(height: 24),

                    // --- Info Card ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppColors.accent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Les annonces sont récupérées en temps réel depuis AutoScout24.de. '
                              'La rentabilité est calculée automatiquement.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14)),
              const Spacer(),
              Text(value,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
            ],
          ),
          slider,
        ],
      ),
    );
  }
}
