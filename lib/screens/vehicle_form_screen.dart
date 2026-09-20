import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/tax_data.dart';
import '../data/car_brands_data.dart';
import '../models/vehicle_model.dart';
import '../services/tax_calculator.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  // Brand / Model dropdowns
  String? _selectedBrand;
  String? _selectedModel;
  bool _isCustomBrand = false;
  bool _isCustomModel = false;
  final _customBrandCtrl = TextEditingController();
  final _customModelCtrl = TextEditingController();

  // Vehicle fields
  final _trimCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _powerDINCtrl = TextEditingController();
  final _powerFiscalCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _co2Ctrl = TextEditingController();

  // Financial fields
  final _priceCtrl = TextEditingController();
  final _transportCtrl = TextEditingController(text: '500');
  final _prepCtrl = TextEditingController(text: '0');

  String _selectedRegion = 'Grand Est';

  List<String> get _availableModels {
    if (_selectedBrand == null || _isCustomBrand) return [];
    return getModelsForBrand(_selectedBrand!);
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    for (final c in [
      _customBrandCtrl, _customModelCtrl, _trimCtrl, _yearCtrl,
      _powerDINCtrl, _powerFiscalCtrl, _weightCtrl, _co2Ctrl,
      _priceCtrl, _transportCtrl, _prepCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final brand = _isCustomBrand ? _customBrandCtrl.text.trim() : (_selectedBrand ?? '');
    final model = _isCustomModel ? _customModelCtrl.text.trim() : (_selectedModel ?? '');

    if (brand.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une marque')),
      );
      return;
    }

    final vehicle = VehicleEntry(
      brand: brand,
      model: model,
      trim: _trimCtrl.text.trim(),
      year: int.parse(_yearCtrl.text.trim()),
      powerDIN: int.parse(_powerDINCtrl.text.trim()),
      powerFiscal: int.parse(_powerFiscalCtrl.text.trim()),
      weightG1: int.parse(_weightCtrl.text.trim()),
      co2WLTP: int.parse(_co2Ctrl.text.trim()),
      purchasePrice: double.parse(_priceCtrl.text.trim()),
      transportCost: double.tryParse(_transportCtrl.text.trim()) ?? 0,
      prepCost: double.tryParse(_prepCtrl.text.trim()) ?? 0,
      region: _selectedRegion,
      createdAt: DateTime.now(),
    );

    final result = TaxCalculator().calculate(vehicle);

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            DashboardScreen(result: result),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // --- App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              pinned: true,
              backgroundColor: AppColors.surface,
              flexibleSpace: FlexibleSpaceBar(
                title: Text('Nouvelle Recherche',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    )),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.gradientStart,
                        AppColors.surface,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // --- Body
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // === SECTION: Véhicule ===
                      _sectionHeader(
                          Icons.directions_car_rounded, 'Infos Véhicule'),
                      const SizedBox(height: 12),
                      _glassCard(
                        child: Column(
                          children: [
                            // --- Marque dropdown ---
                            _isCustomBrand
                                ? TextFormField(
                                    controller: _customBrandCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Marque (personnalisée)',
                                      prefixIcon: const Icon(Icons.directions_car),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.list, size: 20),
                                        tooltip: 'Revenir à la liste',
                                        onPressed: () => setState(() {
                                          _isCustomBrand = false;
                                          _customBrandCtrl.clear();
                                        }),
                                      ),
                                    ),
                                    textCapitalization: TextCapitalization.words,
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                                  )
                                : DropdownButtonFormField<String>(
                                    value: _selectedBrand,
                                    decoration: const InputDecoration(
                                      labelText: 'Marque',
                                      prefixIcon: Icon(Icons.directions_car),
                                    ),
                                    dropdownColor: AppColors.surfaceLight,
                                    isExpanded: true,
                                    menuMaxHeight: 400,
                                    items: [
                                      ...sortedBrands.map((b) => DropdownMenuItem(
                                            value: b,
                                            child: Text(b, style: const TextStyle(fontSize: 14)),
                                          )),
                                      const DropdownMenuItem(
                                        value: '__custom__',
                                        child: Text('✏️ Autre marque...', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      if (v == '__custom__') {
                                        setState(() {
                                          _isCustomBrand = true;
                                          _selectedBrand = null;
                                          _selectedModel = null;
                                          _isCustomModel = true;
                                        });
                                      } else {
                                        setState(() {
                                          _selectedBrand = v;
                                          _selectedModel = null;
                                          _isCustomModel = false;
                                        });
                                      }
                                    },
                                    validator: (v) => v == null ? 'Requis' : null,
                                  ),
                            const SizedBox(height: 12),
                            // --- Modèle dropdown ---
                            (_isCustomBrand || _isCustomModel)
                                ? TextFormField(
                                    controller: _customModelCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Modèle (personnalisé)',
                                      prefixIcon: const Icon(Icons.model_training),
                                      suffixIcon: (!_isCustomBrand && _availableModels.isNotEmpty)
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
                                    textCapitalization: TextCapitalization.words,
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                                  )
                                : DropdownButtonFormField<String>(
                                    value: _selectedModel,
                                    decoration: const InputDecoration(
                                      labelText: 'Modèle',
                                      prefixIcon: Icon(Icons.model_training),
                                    ),
                                    dropdownColor: AppColors.surfaceLight,
                                    isExpanded: true,
                                    menuMaxHeight: 400,
                                    items: [
                                      ..._availableModels.map((m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(m, style: const TextStyle(fontSize: 14)),
                                          )),
                                      const DropdownMenuItem(
                                        value: '__custom__',
                                        child: Text('✏️ Autre modèle...', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
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
                                    validator: (v) {
                                      if (_selectedBrand != null && v == null) return 'Requis';
                                      return null;
                                    },
                                  ),
                            const SizedBox(height: 12),
                            _buildRow([
                              _field('Finition', _trimCtrl, Icons.star_outline,
                                  required: false),
                              _fieldInt('Année 1ère immat', _yearCtrl,
                                  Icons.calendar_today,
                                  hint: 'ex: 2021'),
                            ]),
                            const SizedBox(height: 12),
                            _buildRow([
                              _fieldInt('Puiss. DIN (ch)', _powerDINCtrl,
                                  Icons.speed,
                                  hint: 'ex: 190'),
                              _fieldInt('Puiss. Fiscale (CV)', _powerFiscalCtrl,
                                  Icons.account_balance,
                                  hint: 'ex: 8'),
                            ]),
                            const SizedBox(height: 12),
                            _buildRow([
                              _fieldInt('Poids G1 (kg)', _weightCtrl,
                                  Icons.fitness_center,
                                  hint: 'ex: 1560'),
                              _fieldInt('CO₂ WLTP (g/km)', _co2Ctrl,
                                  Icons.co2,
                                  hint: 'ex: 132'),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // === SECTION: Finances ===
                      _sectionHeader(Icons.euro_rounded, 'Infos Financières'),
                      const SizedBox(height: 12),
                      _glassCard(
                        child: Column(
                          children: [
                            _fieldDouble(
                                'Prix d\'achat Allemagne (€)',
                                _priceCtrl,
                                Icons.shopping_cart,
                                hint: 'ex: 25000'),
                            const SizedBox(height: 12),
                            _buildRow([
                              _fieldDouble('Transport (€)', _transportCtrl,
                                  Icons.local_shipping,
                                  required: false, hint: '500'),
                              _fieldDouble(
                                  'Préparation (€)',
                                  _prepCtrl,
                                  Icons.build_circle,
                                  required: false,
                                  hint: '0'),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // === SECTION: Région ===
                      _sectionHeader(Icons.map_rounded, 'Région'),
                      const SizedBox(height: 12),
                      _glassCard(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedRegion,
                          decoration: const InputDecoration(
                            labelText: 'Région d\'immatriculation',
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          dropdownColor: AppColors.surfaceLight,
                          items: regionalTaxPerCV.keys.map((r) {
                            final price = regionalTaxPerCV[r]!;
                            return DropdownMenuItem(
                              value: r,
                              child: Text(
                                '$r — ${price.toStringAsFixed(2)} €/CV',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedRegion = v!),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // === BUTTON ===
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.gradientStart,
                                AppColors.accent,
                              ],
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
                            onPressed: _calculate,
                            icon: const Icon(Icons.calculate_rounded, size: 24),
                            label: Text('Calculer la Rentabilité',
                                style: GoogleFonts.outfit(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper widgets ---

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            )),
      ],
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Row(
      children: children
          .map((c) => Expanded(child: c))
          .expand((w) => [w, const SizedBox(width: 12)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {bool required = true}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      textCapitalization: TextCapitalization.words,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null
          : null,
    );
  }

  Widget _fieldInt(String label, TextEditingController ctrl, IconData icon,
      {String? hint, bool required = true}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      keyboardType: TextInputType.number,
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) return 'Requis';
              if (int.tryParse(v.trim()) == null) return 'Nombre entier';
              return null;
            }
          : null,
    );
  }

  Widget _fieldDouble(
      String label, TextEditingController ctrl, IconData icon,
      {String? hint, bool required = true}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) return 'Requis';
              if (double.tryParse(v.trim()) == null) return 'Nombre valide';
              return null;
            }
          : null,
    );
  }
}
