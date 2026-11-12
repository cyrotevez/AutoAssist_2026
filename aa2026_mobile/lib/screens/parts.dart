import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const partCategories = ['Engine', 'Brakes', 'Suspension', 'Battery', 'Tyres', 'Electrical', 'Filters', 'Cooling'];

IconData partIcon(String c) {
  switch (c) {
    case 'Engine':
      return Icons.engineering_rounded;
    case 'Brakes':
      return Icons.car_repair_rounded;
    case 'Battery':
      return Icons.battery_charging_full_rounded;
    case 'Tyres':
      return Icons.tire_repair_rounded;
    case 'Electrical':
      return Icons.bolt_rounded;
    case 'Filters':
      return Icons.filter_alt_rounded;
    case 'Cooling':
      return Icons.ac_unit_rounded;
    default:
      return Icons.settings_rounded;
  }
}

class PartCard extends StatelessWidget {
  final Map<String, dynamic> p;
  final Widget? footer;
  const PartCard({super.key, required this.p, this.footer});

  @override
  Widget build(BuildContext context) {
    final inStock = p['in_stock'] == true;
    final compat = (p['compatible'] as String?) ?? '';
    final brand = (p['brand'] as String?) ?? '';
    final category = (p['category'] as String?) ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(context, radius: 20),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.accent.withAlpha(30), shape: BoxShape.circle),
            child: Icon(partIcon(category), color: AppColors.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((p['name'] as String?) ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text([brand, category].where((e) => e.isNotEmpty).join(' • '),
                  style: TextStyle(color: context.muted, fontSize: 12.5)),
              if (compat.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Fits: $compat', style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.3)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(ugx((p['price'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (inStock ? AppColors.ok : AppColors.danger).withAlpha(32),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(inStock ? 'In stock' : 'Out of stock',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: inStock ? AppColors.ok : AppColors.danger)),
            ),
          ]),
        ]),
        if (footer != null) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: context.line),
          const SizedBox(height: 10),
          footer!,
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------------ browse (drivers)
class PartsScreen extends StatefulWidget {
  const PartsScreen({super.key});

  @override
  State<PartsScreen> createState() => _PartsScreenState();
}

class _PartsScreenState extends State<PartsScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  String _category = 'All';
  List<Map<String, dynamic>> _parts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await app.api.get('/parts', query: {
        'q': _q.text.trim(),
        'category': _category == 'All' ? '' : _category,
      });
      if (!mounted) return;
      setState(() {
        _parts = asList(data);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: [
              const BackBtn(),
              const SizedBox(width: 14),
              const Text('Spare parts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppField(
              controller: _q,
              hint: 'Search e.g. brake pads, battery, Premio...',
              icon: Icons.search_rounded,
              action: TextInputAction.search,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 450), _load);
              },
              onSubmitted: (_) => _load(),
            ),
          ),
          const SizedBox(height: 12),
          ChipRow(
            items: ['All', ...partCategories],
            selected: _category,
            onSelected: (c) {
              setState(() => _category = c);
              _load();
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: const [
                      Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 96, radius: 20)),
                      Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 96, radius: 20)),
                      Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 96, radius: 20)),
                    ],
                  )
                : _error != null
                    ? EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load parts',
                        subtitle: _error!,
                        actionLabel: 'Try again',
                        onAction: _load,
                      )
                    : _parts.isEmpty
                        ? const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No parts found',
                            subtitle: 'Try a different search or category.',
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 20),
                            itemCount: _parts.length,
                            itemBuilder: (context, i) {
                              final p = _parts[i];
                              return PartCard(
                                p: p,
                                footer: Row(children: [
                                  Icon(Icons.storefront_outlined, size: 18, color: context.muted),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text((p['supplier_name'] as String?) ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text((p['location'] as String?) ?? '',
                                          style: TextStyle(color: context.muted, fontSize: 12)),
                                    ]),
                                  ),
                                  RoundIconButton(
                                    icon: Icons.phone_rounded,
                                    size: 40,
                                    bg: context.field,
                                    onTap: () => callNumber(context, p['supplier_phone'] as String?),
                                  ),
                                ]),
                              );
                            },
                          ),
          ),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ supplier home
class SupplierPartsScreen extends StatefulWidget {
  const SupplierPartsScreen({super.key});

  @override
  State<SupplierPartsScreen> createState() => _SupplierPartsScreenState();
}

class _SupplierPartsScreenState extends State<SupplierPartsScreen> {
  List<Map<String, dynamic>> _parts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await app.api.get('/parts/mine');
      if (!mounted) return;
      setState(() {
        _parts = asList(data);
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _AddPartSheet(),
    );
    if (res == null) return;
    try {
      await app.api.post('/parts', body: res);
      if (mounted) showMsg(context, 'Part added.');
      _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _stock(Map<String, dynamic> p, bool v) async {
    try {
      await app.api.patch('/parts/${p['id']}/stock', body: {'in_stock': v});
      _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this part?'),
        content: Text('${p['name']} will be removed from your list.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await app.api.delete('/parts/${p['id']}');
      _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return RefreshIndicator(
      color: AppColors.accent,
      edgeOffset: pad.top,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, pad.top + 14, 20, pad.bottom + 24),
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('My parts', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                Text(displayName(app.user ?? {}), style: TextStyle(color: context.muted)),
              ]),
            ),
            Tappable(
              onTap: _add,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Add part', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          if (_loading)
            const Column(children: [
              Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 96, radius: 20)),
              Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 96, radius: 20)),
            ])
          else if (_error != null)
            SizedBox(
              height: 300,
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load your parts',
                subtitle: _error!,
                actionLabel: 'Try again',
                onAction: _load,
              ),
            )
          else if (_parts.isEmpty)
            SizedBox(
              height: 300,
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No parts listed yet',
                subtitle: 'Add the spare parts you sell so drivers can find you.',
                actionLabel: 'Add a part',
                onAction: _add,
              ),
            )
          else
            for (final p in _parts)
              PartCard(
                p: p,
                footer: Row(children: [
                  Text('Available', style: TextStyle(color: context.muted, fontSize: 13)),
                  Switch(value: p['in_stock'] == true, activeTrackColor: AppColors.accent, onChanged: (v) => _stock(p, v)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    onPressed: () => _delete(p),
                  ),
                ]),
              ),
        ],
      ),
    );
  }
}

class _AddPartSheet extends StatefulWidget {
  const _AddPartSheet();
  @override
  State<_AddPartSheet> createState() => _AddPartSheetState();
}

class _AddPartSheetState extends State<_AddPartSheet> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _price = TextEditingController();
  final _compat = TextEditingController();
  String _category = 'Engine';

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _price.dispose();
    _compat.dispose();
    super.dispose();
  }

  void _save() {
    final price = int.tryParse(_price.text.replaceAll(',', '').trim());
    if (_name.text.trim().length < 2) {
      showMsg(context, 'Enter the part name.', error: true);
      return;
    }
    if (price == null || price < 0) {
      showMsg(context, 'Enter a valid price in UGX.', error: true);
      return;
    }
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'category': _category,
      'brand': _brand.text.trim(),
      'price': price,
      'compatible': _compat.text.trim(),
      'in_stock': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Add a spare part', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        AppField(controller: _name, hint: 'Part name (e.g. Front brake pads)', icon: Icons.build_rounded),
        const SizedBox(height: 12),
        AppField(controller: _brand, hint: 'Brand (optional)', icon: Icons.sell_outlined),
        const SizedBox(height: 12),
        AppField(controller: _price, hint: 'Price in UGX', icon: Icons.payments_outlined, keyboard: TextInputType.number),
        const SizedBox(height: 12),
        AppField(controller: _compat, hint: 'Fits vehicles (optional)', icon: Icons.directions_car_outlined),
        const SizedBox(height: 16),
        const Text('Category', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ChipRow(
          items: partCategories,
          selected: _category,
          padding: EdgeInsets.zero,
          onSelected: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 22),
        PillButton(label: 'Save part', onTap: _save),
      ]),
    );
  }
}
