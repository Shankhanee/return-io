import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/warehouse_transaction.dart';
import '../services/firestore_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.isDarkMode, required this.onThemeModeChanged});

  final bool isDarkMode;
  final ValueChanged<bool> onThemeModeChanged;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _searchController = TextEditingController();
  final _productController = TextEditingController();
  final _companyController = TextEditingController();
  final _quantityController = TextEditingController();
  String _searchTerm = '';
  bool _isSaving = false;
  DateTime _movementTime = DateTime.now();
  String _returnChartRange = 'Weekly';

  @override
  void dispose() {
    _searchController.dispose();
    _productController.dispose();
    _companyController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _recordMovement(bool isReturn) async {
    if (_productController.text.trim().isEmpty || _companyController.text.trim().isEmpty) {
      _message('Enter the product name and company.');
      return;
    }
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      _message('Enter a positive whole-number quantity.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirestoreService.instance.recordMovement(
        productName: _productController.text.trim(),
        companyName: _companyController.text.trim(),
        quantity: quantity,
        isReturn: isReturn,
        movementTime: _movementTime,
      );
      _productController.clear();
      _companyController.clear();
      _quantityController.clear();
      setState(() => _movementTime = DateTime.now());
      if (mounted) _message(isReturn ? 'Return received successfully.' : 'Handover recorded successfully.');
    } catch (error) {
      if (mounted) _message(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      if (mounted) _message('Unable to sign out: $error');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Return IO - Admin Console', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _openSettings, tooltip: 'Settings', icon: const Icon(Icons.settings_outlined)),
          IconButton(onPressed: _logout, tooltip: 'Logout', icon: const Icon(Icons.logout)),
        ],
      ),
      body: StreamBuilder<List<Product>>(
        stream: FirestoreService.instance.productsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Unable to load inventory data.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final products = snapshot.data!;
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 28 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _movementForm(),
                    const SizedBox(height: 20),
                    _kpis(products, wide),
                    const SizedBox(height: 20),
                    _analytics(products, wide),
                    const SizedBox(height: 20),
                    _returnChart(),
                    const SizedBox(height: 20),
                    _inventory(products),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
                  title: const Text('Dark mode'),
                  value: widget.isDarkMode,
                  onChanged: (value) {
                    widget.onThemeModeChanged(value);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.error),
                  title: const Text('Clear activity'),
                  subtitle: const Text('Permanently delete all return and handover logs'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmClearActivity();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClearActivity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all activity?'),
        content: const Text('This permanently deletes all return and handover activity logs. Product stock totals will remain unchanged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FirestoreService.instance.clearActivity();
      if (mounted) _message('Activity cleared permanently.');
    } catch (error) {
      if (mounted) _message('Unable to clear activity: $error');
    }
  }

  Widget _movementForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Record warehouse movement', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  TextField(controller: _productController, decoration: const InputDecoration(labelText: 'Product Name', prefixIcon: Icon(Icons.inventory_2_outlined))),
                  TextField(controller: _companyController, decoration: const InputDecoration(labelText: 'Company / Brand', prefixIcon: Icon(Icons.business_outlined))),
                  TextField(controller: _quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.numbers))),
                ];
                if (constraints.maxWidth < 700) {
                  return Column(children: [
                    fields[0],
                    const SizedBox(height: 12),
                    fields[1],
                    const SizedBox(height: 12),
                    fields[2],
                  ]);
                }
                return Row(children: [
                  Expanded(child: fields[0]),
                  const SizedBox(width: 12),
                  Expanded(child: fields[1]),
                  const SizedBox(width: 12),
                  SizedBox(width: 180, child: fields[2]),
                ]);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _chooseMovementDateTime,
              icon: const Icon(Icons.event_outlined),
              label: Text('Movement date: ${_formatDateTime(_movementTime)}'),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final receive = FilledButton.icon(
                  onPressed: _isSaving ? null : () => _recordMovement(true),
                  icon: const Icon(Icons.south_west),
                  label: const Text('Receive Return (In)'),
                );
                final handover = OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _recordMovement(false),
                  icon: const Icon(Icons.north_east),
                  label: const Text('Handover (Out)'),
                );
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [receive, const SizedBox(height: 10), handover],
                  );
                }
                return Row(children: [
                  Expanded(child: receive),
                  const SizedBox(width: 12),
                  Expanded(child: handover),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseMovementDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: _movementTime.isAfter(DateTime.now()) ? DateTime.now() : _movementTime,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_movementTime));
    if (time == null) return;
    setState(() {
      _movementTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day}/${value.month}/${value.year}  $hour:$minute $period';
  }

  Widget _kpis(List<Product> products, bool wide) {
    final cards = [
      _KpiCard(
        title: 'Current Godown Stock',
        value: _sum(products, (product) => product.currentWarehouseStock),
        icon: Icons.warehouse_outlined,
        color: Colors.blue,
        onTap: () => _showBreakdown('Current stock in godown', products, (product) => product.currentWarehouseStock),
      ),
      _KpiCard(
        title: 'Total Returned In',
        value: _sum(products, (product) => product.totalReturnedIn),
        icon: Icons.south_west,
        color: Colors.green,
        onTap: () => _showBreakdown('Total returns received', products, (product) => product.totalReturnedIn),
      ),
      _KpiCard(
        title: 'Total Handed Over',
        value: _sum(products, (product) => product.totalHandedOver),
        icon: Icons.north_east,
        color: Colors.orange,
        onTap: () => _showBreakdown('Total handed over', products, (product) => product.totalHandedOver),
      ),
      _KpiCard(title: 'Unique Product Types', value: products.length, icon: Icons.category_outlined, color: Colors.indigo),
    ];
    if (wide) {
      return Row(children: cards.map((card) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: card))).toList());
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      // The extra "View details" line needs a little more vertical room on phones.
      childAspectRatio: 1.35,
      children: cards,
    );
  }

  int _sum(List<Product> products, int Function(Product) selector) {
    return products.fold(0, (total, product) => total + selector(product));
  }

  void _showBreakdown(String title, List<Product> products, int Function(Product) selector) {
    final rows = products.where((product) => selector(product) > 0).toList()..sort((a, b) => selector(b).compareTo(selector(a)));
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 560,
            child: rows.isEmpty
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No data available.'))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = rows[index];
                      final amount = selector(product);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text('$amount'),
                        ),
                        title: Text(product.productName),
                        subtitle: Text(product.companyName),
                        trailing: Text('$amount units', style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
        );
      },
    );
  }

  Widget _analytics(List<Product> products, bool wide) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _brandChart(products)),
                  const SizedBox(width: 20),
                  Expanded(child: _transactionLog()),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _brandChart(products),
                  const SizedBox(height: 24),
                  _transactionLog(),
                ],
              ),
      ),
    );
  }

  Widget _returnChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<List<WarehouseTransaction>>(
          stream: FirestoreService.instance.transactionsStream(limit: 500),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('Unable to load return graph.');
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final chart = _buildReturnChart(snapshot.data!);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Return items graph', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    DropdownButton<String>(
                      value: _returnChartRange,
                      items: const ['Daily', 'Weekly', 'Monthly', 'Yearly'].map((range) => DropdownMenuItem(value: range, child: Text(range))).toList(),
                      onChanged: (value) => setState(() => _returnChartRange = value ?? _returnChartRange),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Return quantities grouped by $_returnChartRange period', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 20),
                if (chart.values.every((value) => value == 0))
                  const SizedBox(height: 220, child: Center(child: Text('No return data available for this period.')))
                else
                  SizedBox(
                    height: 260,
                    child: BarChart(
                      BarChartData(
                        minY: 0,
                        barTouchData: BarTouchData(enabled: true),
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= chart.labels.length) return const SizedBox.shrink();
                            return SideTitleWidget(meta: meta, child: Text(chart.labels[index], style: const TextStyle(fontSize: 10)));
                          })),
                        ),
                        barGroups: chart.values.asMap().entries.map((entry) => BarChartGroupData(x: entry.key, barRods: [BarChartRodData(toY: entry.value.toDouble(), color: Theme.of(context).colorScheme.primary, width: 12, borderRadius: BorderRadius.circular(3))])).toList(),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  _ReturnChartData _buildReturnChart(List<WarehouseTransaction> transactions) {
    final now = DateTime.now();
    final int bucketCount;
    late DateTime start;
    late Duration step;
    String Function(DateTime) label;
    if (_returnChartRange == 'Daily') {
      bucketCount = 24;
      start = DateTime(now.year, now.month, now.day, now.hour).subtract(const Duration(hours: 23));
      step = const Duration(hours: 1);
      label = (date) => '${date.hour}:00';
    } else if (_returnChartRange == 'Monthly') {
      bucketCount = 30;
      start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
      step = const Duration(days: 1);
      label = (date) => '${date.day}';
    } else if (_returnChartRange == 'Yearly') {
      bucketCount = 12;
      start = DateTime(now.year, now.month - 11, 1);
      step = const Duration(days: 1);
      label = (date) => '${date.month}/${date.year % 100}';
    } else {
      bucketCount = 7;
      start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      step = const Duration(days: 1);
      label = (date) => '${date.day}/${date.month}';
    }
    final values = List<int>.filled(bucketCount, 0);
    for (final transaction in transactions) {
      if (transaction.type != 'RETURN_IN' || transaction.timestamp == null) continue;
      final date = transaction.timestamp!.toLocal();
      final index = _returnChartRange == 'Yearly'
          ? (date.year - start.year) * 12 + date.month - start.month
          : date.difference(start).inHours ~/ step.inHours;
      if (index >= 0 && index < bucketCount) values[index] += transaction.quantity;
    }
    final labels = _returnChartRange == 'Yearly'
        ? List.generate(bucketCount, (index) {
            final month = DateTime(start.year, start.month + index, 1);
            return label(month);
          })
        : List.generate(bucketCount, (index) => label(start.add(step * index)));
    return _ReturnChartData(values: values, labels: labels);
  }

  Widget _brandChart(List<Product> products) {
    final byBrand = <String, int>{};
    for (final product in products) {
      byBrand[product.companyName] = (byBrand[product.companyName] ?? 0) + product.currentWarehouseStock;
    }
    if (byBrand.isEmpty) return const _SectionEmpty(title: 'Stock breakdown by brand', message: 'No data available');
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.indigo, Colors.teal, Colors.pink];
    final total = byBrand.values.fold<int>(0, (sum, value) => sum + value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Stock breakdown by brand', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        SizedBox(
          height: 210,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              sections: byBrand.entries.toList().asMap().entries.map((entry) {
                final percent = total == 0 ? 0 : entry.value.value / total * 100;
                return PieChartSectionData(
                  value: entry.value.value.toDouble(),
                  color: colors[entry.key % colors.length],
                  title: '${percent.toStringAsFixed(0)}%',
                  radius: 72,
                  titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: byBrand.entries.toList().asMap().entries.map((entry) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, color: colors[entry.key % colors.length]),
                const SizedBox(width: 5),
                Text(entry.value.key),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _transactionLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Latest activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 260,
          child: StreamBuilder<List<WarehouseTransaction>>(
            stream: FirestoreService.instance.transactionsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Unable to load logs.'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.isEmpty) return const Center(child: Text('No data available'));
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final item = snapshot.data![index];
                  final isReturn = item.type == 'RETURN_IN';
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(isReturn ? Icons.south_west : Icons.north_east, color: isReturn ? Colors.green : Colors.orange),
                    title: Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${item.companyName}  •  ${item.timestamp == null ? 'Time pending' : _formatDateTime(item.timestamp!.toLocal())}'),
                    trailing: Text('${item.quantity}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _inventory(List<Product> products) {
    final filtered = products.where((product) => product.productName.toLowerCase().contains(_searchTerm.toLowerCase())).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final search = TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchTerm = value),
                  decoration: const InputDecoration(isDense: true, hintText: 'Search product name', prefixIcon: Icon(Icons.search)),
                );
                if (constraints.maxWidth < 600) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Inventory', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      search,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: Text('Inventory', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                    SizedBox(width: 280, child: search),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Text('No data available', textAlign: TextAlign.center))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Product Name')),
                    DataColumn(label: Text('Company')),
                    DataColumn(label: Text('Godown Stock')),
                    DataColumn(label: Text('Returned In')),
                    DataColumn(label: Text('Handed Over')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: filtered.map((product) {
                    return DataRow(cells: [
                      DataCell(Text(product.productName)),
                      DataCell(Text(product.companyName)),
                      DataCell(Text('${product.currentWarehouseStock}')),
                      DataCell(Text('${product.totalReturnedIn}')),
                      DataCell(Text('${product.totalHandedOver}')),
                      DataCell(IconButton(tooltip: 'Delete product', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(product))),
                    ]);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Product product) async {
    try {
      await FirestoreService.instance.deleteProduct(product.id);
      if (mounted) _message('${product.productName} deleted.');
    } catch (error) {
      if (mounted) _message('Unable to delete product: $error');
    }
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.value, required this.icon, required this.color, this.onTap});

  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withAlpha(24), child: Icon(icon, color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    if (onTap != null) ...[
                      const SizedBox(height: 2),
                      Text('View details', style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 80),
        Center(child: Text(message)),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _ReturnChartData {
  const _ReturnChartData({required this.values, required this.labels});

  final List<int> values;
  final List<String> labels;
}
