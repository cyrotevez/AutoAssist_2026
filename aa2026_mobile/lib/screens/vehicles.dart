import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const vehicleTypes = ['Car', 'SUV', 'Pickup', 'Van', 'Truck', 'Motorcycle'];

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await app.api.get('/vehicles');
      if (!mounted) return;
      setState(() {
        _items = asList(data);
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

  Future<void> _add() async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _AddVehicleSheet(),
    );
    if (res == null) return;
    try {
      await app.api.post('/vehicles', body: res);
      if (mounted) showMsg(context, 'Vehicle added.');
      _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove vehicle?'),
        content: Text('${v['make']} ${v['model']} will be removed from your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await app.api.delete('/vehicles/${v['id']}');
      _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
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
              const Expanded(child: Text('My vehicles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
              Tappable(
                onTap: _add,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _error != null
                    ? EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load vehicles',
                        subtitle: _error!,
                        actionLabel: 'Try again',
                        onAction: _load,
                      )
                    : _items.isEmpty
                        ? EmptyState(
                            icon: Icons.directions_car_outlined,
                            title: 'No vehicles yet',
                            subtitle: 'Add your vehicle so mechanics know what they are working on.',
                            actionLabel: 'Add vehicle',
                            onAction: _add,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            itemCount: _items.length,
                            itemBuilder: (context, i) => _tile(_items[i]),
                          ),
          ),
        ]),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> v) {
    final plate = (v['plate'] as String?) ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(context, radius: 20),
      child: Row(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: context.field, shape: BoxShape.circle),
          child: Icon(Icons.directions_car_rounded, color: context.ink),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${v['make']} ${v['model']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 2),
            Text([v['year'].toString(), (v['vtype'] as String?) ?? '', plate].where((e) => e.isNotEmpty).join(' • '),
                style: TextStyle(color: context.muted, fontSize: 13)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
          onPressed: () => _delete(v),
        ),
      ]),
    );
  }
}

class _AddVehicleSheet extends StatefulWidget {
  const _AddVehicleSheet();
  @override
  State<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<_AddVehicleSheet> {
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _plate = TextEditingController();
  String _type = 'Car';

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _plate.dispose();
    super.dispose();
  }

  void _save() {
    final year = int.tryParse(_year.text.trim());
    String? problem;
    if (_make.text.trim().isEmpty || _model.text.trim().isEmpty) {
      problem = 'Enter the make and model.';
    } else if (year == null || year < 1950 || year > DateTime.now().year + 1) {
      problem = 'Enter a valid year, for example 2014.';
    }
    if (problem != null) {
      showMsg(context, problem, error: true);
      return;
    }
    Navigator.of(context).pop({
      'make': _make.text.trim(),
      'model': _model.text.trim(),
      'year': year,
      'plate': _plate.text.trim(),
      'vtype': _type,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Add a vehicle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        AppField(controller: _make, hint: 'Make (e.g. Toyota)', icon: Icons.directions_car_outlined),
        const SizedBox(height: 12),
        AppField(controller: _model, hint: 'Model (e.g. Premio)', icon: Icons.label_outline_rounded),
        const SizedBox(height: 12),
        AppField(controller: _year, hint: 'Year (e.g. 2014)', icon: Icons.calendar_today_outlined, keyboard: TextInputType.number),
        const SizedBox(height: 12),
        AppField(controller: _plate, hint: 'Registration number (e.g. UBA 123A)', icon: Icons.pin_outlined),
        const SizedBox(height: 16),
        const Text('Type', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ChipRow(items: vehicleTypes, selected: _type, padding: EdgeInsets.zero, onSelected: (t) => setState(() => _type = t)),
        const SizedBox(height: 22),
        PillButton(label: 'Save vehicle', onTap: _save),
      ]),
    );
  }
}
