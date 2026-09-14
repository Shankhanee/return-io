import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/warehouse_transaction.dart';
import '../services/firestore_service.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final _formKey = GlobalKey<FormState>();
  final _productController = TextEditingController();
  final _companyController = TextEditingController();
  final _quantityController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _productController.dispose();
    _companyController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _recordMovement(bool isReturn) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await FirestoreService.instance.recordMovement(
        productName: _productController.text.trim(),
        companyName: _companyController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        isReturn: isReturn,
      );
      _productController.clear();
      _companyController.clear();
      _quantityController.clear();
      if (mounted) _showMessage(isReturn ? 'Return received successfully.' : 'Handover recorded successfully.');
    } catch (error) {
      if (mounted) _showMessage(error.toString().replaceFirst('Bad state: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isError ? Theme.of(context).colorScheme.error : null),
      );

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      if (mounted) _showMessage('Unable to sign out: $error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Return IO - Godown Floor', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _logout, tooltip: 'Logout', icon: const Icon(Icons.logout))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _movementForm(),
            const SizedBox(height: 24),
            Text('Recent activity', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            StreamBuilder<List<WarehouseTransaction>>(
              stream: FirestoreService.instance.transactionsStream(limit: 5),
              builder: (context, snapshot) {
                if (snapshot.hasError) return _emptyActivity('Unable to load activity.');
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.isEmpty) return _emptyActivity('No transactions yet.');
                return Card(child: Column(children: snapshot.data!.map(_activityTile).toList()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _movementForm() => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Record warehouse movement', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(controller: _productController, decoration: const InputDecoration(labelText: 'Product Name', prefixIcon: Icon(Icons.inventory_2_outlined)), validator: _required),
              const SizedBox(height: 12),
              TextFormField(controller: _companyController, decoration: const InputDecoration(labelText: 'Company / Brand', prefixIcon: Icon(Icons.business_outlined)), validator: _required),
              const SizedBox(height: 12),
              TextFormField(controller: _quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.numbers)), validator: (value) => int.tryParse(value ?? '')?.compareTo(0).isNegative == false ? null : 'Enter a positive whole number'),
              const SizedBox(height: 20),
              LayoutBuilder(builder: (context, constraints) {
                final buttons = [
                  FilledButton.icon(onPressed: _isSaving ? null : () => _recordMovement(true), icon: const Icon(Icons.south_west), label: const Text('Receive Return (In)')),
                  OutlinedButton.icon(onPressed: _isSaving ? null : () => _recordMovement(false), icon: const Icon(Icons.north_east), label: const Text('Handover (Out)')),
                ];
                return constraints.maxWidth < 480 ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [buttons[0], const SizedBox(height: 10), buttons[1]]) : Row(children: [Expanded(child: buttons[0]), const SizedBox(width: 12), Expanded(child: buttons[1])]);
              }),
            ]),
          ),
        ),
      );

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'This field is required' : null;

  Widget _emptyActivity(String message) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(message))));

  Widget _activityTile(WarehouseTransaction item) {
    final isReturn = item.type == 'RETURN_IN';
    return ListTile(
      leading: CircleAvatar(backgroundColor: (isReturn ? Colors.green : Colors.orange).withAlpha(24), child: Icon(isReturn ? Icons.south_west : Icons.north_east, color: isReturn ? Colors.green : Colors.orange)),
      title: Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${item.companyName}  •  ${item.quantity} units'),
      trailing: Text(isReturn ? 'IN' : 'OUT', style: TextStyle(fontWeight: FontWeight.bold, color: isReturn ? Colors.green : Colors.orange)),
    );
  }
}