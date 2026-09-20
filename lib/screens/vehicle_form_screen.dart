import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/tax_data.dart';
import '../data/car_brands_data.dart';
import '../models/vehicle_model.dart';
import '../models/car_listing.dart';
import '../services/autoscout_service.dart';
import '../services/tax_calculator.dart';
import '../services/vehicle_specs_resolver.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class VehicleFormScreen extends StatefulWidget {
  VehicleFormScreen({super.key});

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
  final _monthCtrl = TextEditingController(text: '1');
  final _mileageCtrl = TextEditingController();
  final _powerDINCtrl = TextEditingController();
  final _powerFiscalCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _co2Ctrl = TextEditingController();
  final _seatsCtrl = TextEditingController(text: '5');
  final _electricRangeCtrl = TextEditingController();
  String _fuelType = 'Essence';
  bool _familyBenefit = false;
  bool _loadingTechnical = false;
  String _technicalSource = 'Saisie manuelle';

  // Financial fields
  final _priceCtrl = TextEditingController();
  final _transportCtrl = TextEditingController(text: '500');
  final _prepCtrl = TextEditingController(text: '0');
  final _resaleCtrl = TextEditingController();
  final _proCostsCtrl = TextEditingController(text: '1500');
  bool _vatOnMargin = true;

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
      duration: Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    for (final c in [
      _customBrandCtrl,
      _customModelCtrl,
      _trimCtrl,
      _yearCtrl,
      _monthCtrl,
      _mileageCtrl,
      _powerDINCtrl,
      _powerFiscalCtrl,
      _weightCtrl,
      _co2Ctrl,
      _seatsCtrl,
      _electricRangeCtrl,
      _priceCtrl,
      _transportCtrl,
      _prepCtrl,
      _resaleCtrl,
      _proCostsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    final month = int.parse(_monthCtrl.text.trim());
    if (month < 1 || month > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Le mois doit être compris entre 1 et 12.'),
        ),
      );
      return;
    }

    final brand = _isCustomBrand
        ? _customBrandCtrl.text.trim()
        : (_selectedBrand ?? '');
    final model = _isCustomModel
        ? _customModelCtrl.text.trim()
        : (_selectedModel ?? '');

    if (brand.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez sélectionner une marque')),
      );
      return;
    }

    final vehicle = VehicleEntry(
      brand: brand,
      model: model,
      trim: _trimCtrl.text.trim(),
      year: int.parse(_yearCtrl.text.trim()),
      firstRegistrationMonth: month,
      mileage: int.tryParse(_mileageCtrl.text.trim()),
      powerDIN: int.parse(_powerDINCtrl.text.trim()),
      powerFiscal: int.parse(_powerFiscalCtrl.text.trim()),
      weightG1: int.parse(_weightCtrl.text.trim()),
      co2WLTP: int.parse(_co2Ctrl.text.trim()),
      fuelType: _fuelType,
      seats: int.parse(_seatsCtrl.text.trim()),
      electricRangeKm: int.tryParse(_electricRangeCtrl.text.trim()),
      purchasePrice: double.parse(_priceCtrl.text.trim()),
      transportCost: double.tryParse(_transportCtrl.text.trim()) ?? 0,
      prepCost: double.tryParse(_prepCtrl.text.trim()) ?? 0,
      region: _selectedRegion,
      sourceFiscal: _technicalSource,
      sourceCO2: _technicalSource,
      sourceWeight: _technicalSource,
      createdAt: DateTime.now(),
    );

    final resalePrice = double.tryParse(_resaleCtrl.text.trim());
    final result = TaxCalculator().calculate(
      vehicle,
      childrenCount: _familyBenefit ? 3 : 0,
      lbcMarketPrice: resalePrice,
      lbcQuickPrice: resalePrice == null ? null : resalePrice * .95,
      comparableCount: resalePrice == null ? 0 : 3,
      proCosts: double.tryParse(_proCostsCtrl.text.trim()) ?? 0,
      vatOnMargin: _vatOnMargin,
    );

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            DashboardScreen(result: result),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _autoFillTechnicalData() async {
    final brand = _isCustomBrand
        ? _customBrandCtrl.text.trim()
        : (_selectedBrand ?? '');
    final model = _isCustomModel
        ? _customModelCtrl.text.trim()
        : (_selectedModel ?? '');
    final year = int.tryParse(_yearCtrl.text.trim());
    if (brand.isEmpty || model.isEmpty || year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renseignez marque, modèle et année d’abord.')),
      );
      return;
    }

    setState(() => _loadingTechnical = true);
    final service = AutoScoutService();
    try {
      final listings = await service.searchListings(
        brand: brand,
        model: model,
        yearFrom: year,
        yearTo: year,
      );
      if (!mounted) return;
      if (listings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aucune motorisation correspondante trouvée.')),
        );
        return;
      }

      final selected = await showModalBottomSheet<CarListing>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .72,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    children: [
                      Text(
                        'Choisissez la motorisation exacte',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'La puissance et l’énergie doivent correspondre au véhicule visé.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: listings.length > 20 ? 20 : listings.length,
                    separatorBuilder: (_, _) => Divider(height: 1),
                    itemBuilder: (_, index) {
                      final listing = listings[index];
                      final power = listing.powerKW == null
                          ? 'puissance à lire'
                          : '${listing.powerKW} kW / ${listing.powerPS ?? (listing.powerKW! * 1.36).round()} ch';
                      return ListTile(
                        title: Text(
                          listing.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('$power · ${listing.fuel ?? 'énergie inconnue'}'),
                        trailing: Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(sheetContext, listing),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (selected == null || !mounted) return;

      final enriched = await service.enrichListing(selected);
      if (!mounted) return;
      final resolved = VehicleSpecsResolver().resolve(enriched, listings);
      setState(() {
        if (resolved.powerPS != null || resolved.powerKW != null) {
          _powerDINCtrl.text = (resolved.powerPS ??
                  (resolved.powerKW! * 1.35962).round())
              .toString();
        }
        if (resolved.estimatedFiscalPower > 0) {
          _powerFiscalCtrl.text = resolved.estimatedFiscalPower.toString();
        }
        if (resolved.weightG1 != null) {
          _weightCtrl.text = resolved.weightG1.toString();
        }
        if (resolved.co2 != null) _co2Ctrl.text = resolved.co2.toString();
        if (resolved.seats != null) _seatsCtrl.text = resolved.seats.toString();
        if (resolved.electricRangeKm != null) {
          _electricRangeCtrl.text = resolved.electricRangeKm.toString();
        }
        _fuelType = _mapFuel(resolved.fuel);
        _technicalSource = resolved.technicalSource;
      });

      final complete = resolved.hasRequiredTechnicalData;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            complete
                ? 'Données techniques récupérées et prêtes à vérifier.'
                : 'Données partielles : les champs manquants restent à vérifier sur le COC ou la carte grise.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recherche technique impossible : $error')),
      );
    } finally {
      service.dispose();
      if (mounted) setState(() => _loadingTechnical = false);
    }
  }

  String _mapFuel(String? value) {
    final fuel = (value ?? '').toLowerCase();
    if (fuel.contains('plug') || fuel.contains('phev')) {
      return 'Hybride rechargeable (PHEV)';
    }
    if (fuel.contains('hybrid')) return 'Hybride';
    if (fuel.contains('diesel')) return 'Diesel';
    if (fuel.contains('elektro') || fuel.contains('electric')) {
      return 'Électrique';
    }
    if (fuel.contains('e85')) return 'E85';
    return 'Essence';
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
              backgroundColor: context.appColors.surface,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Nouvelle Recherche',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [context.appColors.gradientStart, context.appColors.surface],
                    ),
                  ),
                ),
              ),
            ),

            // --- Body
            SliverPadding(
              padding: EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // === SECTION: Véhicule ===
                      _sectionHeader(
                        Icons.directions_car_rounded,
                        'Infos Véhicule',
                      ),
                      SizedBox(height: 12),
                      _glassCard(
                        child: Column(
                          children: [
                            // --- Marque dropdown ---
                            _isCustomBrand
                                ? TextFormField(
                                    controller: _customBrandCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Marque (personnalisée)',
                                      prefixIcon: Icon(
                                        Icons.directions_car,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(Icons.list, size: 20),
                                        tooltip: 'Revenir à la liste',
                                        onPressed: () => setState(() {
                                          _isCustomBrand = false;
                                          _customBrandCtrl.clear();
                                        }),
                                      ),
                                    ),
                                    textCapitalization:
                                        TextCapitalization.words,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Requis'
                                        : null,
                                  )
                                : DropdownButtonFormField<String>(
                                    initialValue: _selectedBrand,
                                    decoration: InputDecoration(
                                      labelText: 'Marque',
                                      prefixIcon: Icon(Icons.directions_car),
                                    ),
                                    dropdownColor: context.appColors.surfaceLight,
                                    isExpanded: true,
                                    menuMaxHeight: 400,
                                    items: [
                                      ...sortedBrands.map(
                                        (b) => DropdownMenuItem(
                                          value: b,
                                          child: Text(
                                            b,
                                            style: TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: '__custom__',
                                        child: Text(
                                          '✏️ Autre marque...',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
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
                                    validator: (v) =>
                                        v == null ? 'Requis' : null,
                                  ),
                            SizedBox(height: 12),
                            // --- Modèle dropdown ---
                            (_isCustomBrand || _isCustomModel)
                                ? TextFormField(
                                    controller: _customModelCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Modèle (personnalisé)',
                                      prefixIcon: Icon(
                                        Icons.model_training,
                                      ),
                                      suffixIcon:
                                          (!_isCustomBrand &&
                                              _availableModels.isNotEmpty)
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.list,
                                                size: 20,
                                              ),
                                              tooltip: 'Revenir à la liste',
                                              onPressed: () => setState(() {
                                                _isCustomModel = false;
                                                _customModelCtrl.clear();
                                              }),
                                            )
                                          : null,
                                    ),
                                    textCapitalization:
                                        TextCapitalization.words,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Requis'
                                        : null,
                                  )
                                : DropdownButtonFormField<String>(
                                    initialValue: _selectedModel,
                                    decoration: InputDecoration(
                                      labelText: 'Modèle',
                                      prefixIcon: Icon(Icons.model_training),
                                    ),
                                    dropdownColor: context.appColors.surfaceLight,
                                    isExpanded: true,
                                    menuMaxHeight: 400,
                                    items: [
                                      ..._availableModels.map(
                                        (m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(
                                            m,
                                            style: TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: '__custom__',
                                        child: Text(
                                          '✏️ Autre modèle...',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: _selectedBrand == null
                                        ? null
                                        : (v) {
                                            if (v == '__custom__') {
                                              setState(
                                                () => _isCustomModel = true,
                                              );
                                            } else {
                                              setState(
                                                () => _selectedModel = v,
                                              );
                                            }
                                          },
                                    validator: (v) {
                                      if (_selectedBrand != null && v == null) {
                                        return 'Requis';
                                      }
                                      return null;
                                    },
                                  ),
                            SizedBox(height: 12),
                            _buildRow([
                              _field(
                                'Finition',
                                _trimCtrl,
                                Icons.star_outline,
                                required: false,
                              ),
                              _fieldInt(
                                'Année 1ère immat',
                                _yearCtrl,
                                Icons.calendar_today,
                                hint: 'ex: 2021',
                              ),
                            ]),
                            SizedBox(height: 12),
                            _buildRow([
                              _fieldInt(
                                'Mois (1–12)',
                                _monthCtrl,
                                Icons.event_outlined,
                                hint: 'ex: 6',
                              ),
                              _fieldInt(
                                'Kilométrage',
                                _mileageCtrl,
                                Icons.speed_outlined,
                                hint: 'ex: 65000',
                                required: false,
                              ),
                            ]),
                            SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _fuelType,
                              decoration: InputDecoration(
                                labelText: 'Énergie',
                                prefixIcon: Icon(
                                  Icons.local_gas_station_outlined,
                                ),
                              ),
                              dropdownColor: context.appColors.surfaceLight,
                              items:
                                  [
                                        'Essence',
                                        'Diesel',
                                        'Hybride',
                                        'Hybride rechargeable (PHEV)',
                                        'E85',
                                        'Électrique',
                                        'Hydrogène',
                                      ]
                                      .map(
                                        (fuel) => DropdownMenuItem(
                                          value: fuel,
                                          child: Text(fuel),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) =>
                                  setState(() => _fuelType = value!),
                            ),
                            SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _loadingTechnical
                                    ? null
                                    : _autoFillTechnicalData,
                                icon: _loadingTechnical
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(Icons.auto_fix_high_rounded),
                                label: Text(
                                  _loadingTechnical
                                      ? 'Recherche de la fiche…'
                                      : 'Auto-remplir depuis la motorisation',
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            _buildRow([
                              _fieldInt(
                                'Puiss. DIN (ch)',
                                _powerDINCtrl,
                                Icons.speed,
                                hint: 'ex: 190',
                              ),
                              _fieldInt(
                                'Puiss. Fiscale (CV)',
                                _powerFiscalCtrl,
                                Icons.account_balance,
                                hint: 'ex: 8',
                              ),
                            ]),
                            SizedBox(height: 12),
                            _buildRow([
                              _fieldInt(
                                'Masse G (kg)',
                                _weightCtrl,
                                Icons.fitness_center,
                                hint: 'ex: 1560',
                              ),
                              _fieldInt(
                                'CO₂ WLTP (g/km)',
                                _co2Ctrl,
                                Icons.co2,
                                hint: 'ex: 132',
                              ),
                            ]),
                            SizedBox(height: 12),
                            _buildRow([
                              _fieldInt(
                                'Nombre de places',
                                _seatsCtrl,
                                Icons.event_seat_outlined,
                                hint: '5',
                              ),
                              _fieldInt(
                                'Autonomie EV urbaine',
                                _electricRangeCtrl,
                                Icons.ev_station_outlined,
                                hint: 'km PHEV',
                                required: false,
                              ),
                            ]),
                            SizedBox(height: 8),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _familyBenefit,
                              onChanged: (value) =>
                                  setState(() => _familyBenefit = value),
                              title: Text(
                                'Famille avec 3 enfants à charge',
                              ),
                              subtitle: Text(
                                'Véhicule 5 places minimum · remboursement après paiement · 1 véhicule / 2 ans',
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // === SECTION: Finances ===
                      _sectionHeader(Icons.euro_rounded, 'Infos Financières'),
                      SizedBox(height: 12),
                      _glassCard(
                        child: Column(
                          children: [
                            _fieldDouble(
                              'Prix d\'achat Allemagne (€)',
                              _priceCtrl,
                              Icons.shopping_cart,
                              hint: 'ex: 25000',
                            ),
                            SizedBox(height: 12),
                            _buildRow([
                              _fieldDouble(
                                'Transport (€)',
                                _transportCtrl,
                                Icons.local_shipping,
                                required: false,
                                hint: '500',
                              ),
                              _fieldDouble(
                                'Préparation (€)',
                                _prepCtrl,
                                Icons.build_circle,
                                required: false,
                                hint: '0',
                              ),
                            ]),
                            SizedBox(height: 12),
                            _fieldDouble(
                              'Prix médian France vérifié (€)',
                              _resaleCtrl,
                              Icons.query_stats_rounded,
                              hint: 'même modèle · année ±1 · km proches',
                              required: false,
                            ),
                            SizedBox(height: 12),
                            _fieldDouble(
                              'Frais professionnels par véhicule (€)',
                              _proCostsCtrl,
                              Icons.business_center_outlined,
                              hint: '1500',
                            ),
                            SizedBox(height: 8),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _vatOnMargin,
                              onChanged: (value) =>
                                  setState(() => _vatOnMargin = value),
                              title: Text('Régime de TVA sur marge'),
                              subtitle: Text(
                                'À activer uniquement si la facture d’achat rend ce régime éligible.',
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // === SECTION: Région ===
                      _sectionHeader(Icons.map_rounded, 'Région'),
                      SizedBox(height: 12),
                      _glassCard(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedRegion,
                          decoration: InputDecoration(
                            labelText: 'Région d\'immatriculation',
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          dropdownColor: context.appColors.surfaceLight,
                          items: regionalTaxPerCV.keys.map((r) {
                            final price = regionalTaxPerCV[r]!;
                            return DropdownMenuItem(
                              value: r,
                              child: Text(
                                '$r — ${price.toStringAsFixed(2)} €/CV',
                                style: TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedRegion = v!),
                        ),
                      ),

                      SizedBox(height: 32),

                      // === BUTTON ===
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                context.appColors.gradientStart,
                                context.appColors.accent,
                              ],
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
                            onPressed: _calculate,
                            icon: Icon(Icons.calculate_rounded, size: 24),
                            label: Text(
                              'Calculer la Rentabilité',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
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
                      SizedBox(height: 40),
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
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.appColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: context.appColors.accent, size: 20),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.appColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            children: children
                .expand((child) => [child, SizedBox(height: 12)])
                .toList()
              ..removeLast(),
          );
        }
        return Row(
          children:
              children
                  .map((c) => Expanded(child: c))
                  .expand((w) => [w, SizedBox(width: 12)])
                  .toList()
                ..removeLast(),
        );
      },
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    bool required = true,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      textCapitalization: TextCapitalization.words,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null
          : null,
    );
  }

  Widget _fieldInt(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    String? hint,
    bool required = true,
  }) {
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
    String label,
    TextEditingController ctrl,
    IconData icon, {
    String? hint,
    bool required = true,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
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
