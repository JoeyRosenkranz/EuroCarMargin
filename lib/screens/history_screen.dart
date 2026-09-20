import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/vehicle_model.dart';
import '../services/database_helper.dart';
import '../services/tax_calculator.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _searches = [];
  bool _loading = true;
  late final _fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
  late final _dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _loadSearches();
  }

  Future<void> _loadSearches() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await DatabaseHelper.instance.getAllSearches();
      if (!mounted) return;
      setState(() {
        _searches = data;
        _loading = false;
      });
    } catch (_) {
      // SQLite may be temporarily unavailable during platform startup.
      // Keep the rest of the application usable and show an empty history.
      if (!mounted) return;
      setState(() {
        _searches = [];
        _loading = false;
      });
    }
  }

  Future<void> _deleteSearch(int id) async {
    await DatabaseHelper.instance.deleteSearch(id);
    _loadSearches();
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer tout l\'historique ?'),
        content: Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: context.appColors.accentRed),
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteAllSearches();
      _loadSearches();
    }
  }

  void _openDetail(Map<String, dynamic> m) {
    final vehicle = VehicleEntry.fromMap(m);
    final children = ((m['family_co2_deduction'] as num?)?.toInt() ?? 0) ~/ 20;
    final result = TaxCalculator().calculate(
      vehicle,
      childrenCount: children,
      lbcMarketPrice: (m['resale_fr_market'] as num?)?.toDouble(),
      lbcQuickPrice: (m['resale_fr_quick'] as num?)?.toDouble(),
      comparableCount: (m['comparable_count'] as num?)?.toInt() ?? 0,
      proCosts: (m['pro_costs'] as num?)?.toDouble() ?? 1500,
      vatOnMargin: ((m['vat_on_margin'] as num?)?.toInt() ?? 1) == 1,
    );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DashboardScreen(result: result)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique', style: GoogleFonts.outfit()),
        actions: [
          if (_searches.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete_sweep_rounded,
                color: context.appColors.accentRed,
              ),
              onPressed: _deleteAll,
              tooltip: 'Tout supprimer',
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _searches.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _loadSearches,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _searches.length,
                itemBuilder: (context, i) => _buildSearchCard(_searches[i], i),
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 64, color: context.appColors.textMuted),
          SizedBox(height: 16),
          Text(
            'Aucune recherche sauvegardée',
            style: GoogleFonts.outfit(
              fontSize: 18,
              color: context.appColors.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Vos calculs apparaîtront ici',
            style: TextStyle(color: context.appColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(Map<String, dynamic> m, int index) {
    final brand = m['brand'] as String? ?? '';
    final model = m['model'] as String? ?? '';
    final year = m['year'] as int? ?? 0;
    final profitMarket = (m['profit_market'] as num?)?.toDouble() ?? 0;
    final riskLevel = m['risk_level'] as String? ?? 'red';
    final createdAt = m['created_at'] as String? ?? '';
    final totalInvested = (m['total_invested'] as num?)?.toDouble() ?? 0;

    final riskColor = context.appColors.riskColor(riskLevel);
    DateTime? date;
    try {
      date = DateTime.parse(createdAt);
    } catch (_) {}

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(m['id']),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _deleteSearch(m['id'] as int),
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: context.appColors.accentRed.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.delete_forever_rounded,
            color: context.appColors.accentRed,
            size: 28,
          ),
        ),
        child: GestureDetector(
          onTap: () => _openDetail(m),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300 + index * 50),
            curve: Curves.easeOut,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Risk indicator
                Container(
                  width: 4,
                  height: 52,
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$brand $model',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$year • Investi: ${_fmt.format(totalInvested)}',
                        style: TextStyle(
                          color: context.appColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (date != null)
                        Text(
                          _dateFmt.format(date),
                          style: TextStyle(
                            color: context.appColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                // Profit
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${profitMarket >= 0 ? '+' : ''}${_fmt.format(profitMarket)}',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: riskColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        riskLevel == 'green'
                            ? 'Rentable'
                            : riskLevel == 'orange'
                            ? 'Modéré'
                            : 'Risqué',
                        style: TextStyle(
                          color: riskColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.appColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
