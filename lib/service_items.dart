import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart' show AnimatedCard, HoverCard, AnimatedButton, EmptyState, isMobile;

class ServiceItemsScreen extends StatefulWidget {
  const ServiceItemsScreen({super.key});

  @override
  State<ServiceItemsScreen> createState() => _ServiceItemsScreenState();
}

class _ServiceItemsScreenState extends State<ServiceItemsScreen> {
  final List<ServiceItemData> _serviceItems = [];
  String _searchQuery = '';
  String _filterType = 'All';

  bool get _isAdmin => AppState.currentRole == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    _serviceItems.addAll([
      const ServiceItemData(
        id: 1,
        itemName: 'AC Installation',
        itemType: 'Service',
        price: 5000.0,
      ),
      const ServiceItemData(
        id: 2,
        itemName: 'Preventive Maintenance',
        itemType: 'Service',
        price: 1500.0,
      ),
      const ServiceItemData(
        id: 3,
        itemName: 'Freon Refill',
        itemType: 'Material',
        price: 2500.0,
      ),
      const ServiceItemData(
        id: 4,
        itemName: 'AC Cleaning',
        itemType: 'Service',
        price: 800.0,
      ),
      const ServiceItemData(
        id: 5,
        itemName: 'Compressor Replacement',
        itemType: 'Material',
        price: 12000.0,
      ),
    ]);
  }

  List<ServiceItemData> get _filteredItems {
    var filtered = _serviceItems;

    if (_filterType != 'All') {
      filtered = filtered.where((i) => i.itemType == _filterType).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (i) =>
                i.itemName.toLowerCase().contains(q) ||
                i.itemType.toLowerCase().contains(q),
          )
          .toList();
    }

    return filtered;
  }

  Future<void> _onAddOrEdit({ServiceItemData? existing}) async {
    final ServiceItemData? result = await showModalBottomSheet<ServiceItemData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ServiceItemDialog(item: existing),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        final newId = _serviceItems.isNotEmpty ? _serviceItems.last.id + 1 : 1;
        _serviceItems.add(
          ServiceItemData(
            id: newId,
            itemName: result.itemName,
            itemType: result.itemType,
            price: result.price,
          ),
        );
      } else {
        final index = _serviceItems.indexWhere((i) => i.id == existing.id);
        if (index != -1) {
          _serviceItems[index] = result;
        }
      }
    });
  }

  void _onDelete(ServiceItemData item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service Item'),
        content: Text('Are you sure you want to delete "${item.itemName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _serviceItems.removeWhere((i) => i.id == item.id);
    });
  }

  String _formatPrice(double price) => '₱${price.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    final fontSize = _isAdmin ? 14.0 : 16.0;

    // FIX: Detect mobile layout
    final isMobileView = MediaQuery.of(context).size.width < 600;

    return AppShell(
      selectedIndex: 8,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(_isAdmin ? 20 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FIX: Responsive Header
                  if (isMobileView) ...[
                    const Text(
                      'Service Items & Catalog',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isAdmin)
                      SizedBox(
                        width: double.infinity,
                        child: AnimatedButton(
                          onPressed: () => _onAddOrEdit(),
                          icon: Icons.add,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          child: const Text('Add Service Item'),
                        ),
                      ),
                  ] else ...[
                    Row(
                      children: [
                        Text(
                          'Service Items & Catalog',
                          style: TextStyle(
                            fontSize: _isAdmin ? 24 : 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (_isAdmin)
                          AnimatedButton(
                            onPressed: () => _onAddOrEdit(),
                            icon: Icons.add,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            child: const Text('Add Service Item'),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // FIX: Responsive Filters
                  if (isMobileView) ...[
                    AnimatedCard(
                      delay: const Duration(milliseconds: 200),
                      child: HoverCard(
                        padding: EdgeInsets.zero,
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: TextStyle(fontSize: fontSize),
                          decoration: InputDecoration(
                            hintText: 'Search by name or type...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedCard(
                      delay: const Duration(milliseconds: 250),
                      child: HoverCard(
                        padding: EdgeInsets.zero,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _filterType,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'All',
                                  child: Text('All Types'),
                                ),
                                DropdownMenuItem(
                                  value: 'Service',
                                  child: Text('Service'),
                                ),
                                DropdownMenuItem(
                                  value: 'Material',
                                  child: Text('Material'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _filterType = v ?? 'All'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    AnimatedCard(
                      delay: const Duration(milliseconds: 200),
                      child: HoverCard(
                        padding: EdgeInsets.zero,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (v) => setState(() => _searchQuery = v),
                                style: TextStyle(fontSize: fontSize),
                                decoration: InputDecoration(
                              hintText: 'Search by name or type...',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButton<String>(
                            value: _filterType,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(
                                value: 'All',
                                child: Text('All Types'),
                              ),
                              DropdownMenuItem(
                                value: 'Service',
                                child: Text('Service'),
                              ),
                              DropdownMenuItem(
                                value: 'Material',
                                child: Text('Material'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _filterType = v ?? 'All'),
                          ),
                        ),
                      ],
                    ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 16),

                  // FIX: Mobile Cards vs Desktop Table
                  if (isMobileView)
                    ...items.asMap().entries.map((e) => AnimatedCard(
                      delay: Duration(milliseconds: 300 + (e.key * 50)),
                      child: _buildMobileCard(e.value),
                    ))
                  else
                    AnimatedCard(
                      delay: const Duration(milliseconds: 300),
                      child: HoverCard(
                        padding: EdgeInsets.zero,
                        child: Container(
                      decoration: _cardDeco(),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 800),
                          child: DataTable(
                            columns: [
                              DataColumn(
                                label: Text(
                                  'ITEM NAME',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'TYPE',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'PRICE',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'ACTIONS',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            rows: items.map((i) => _dataRow(i)).toList(),
                          ),
                        ),
                      ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New Mobile Card Widget
  Widget _buildMobileCard(ServiceItemData i) {
    final typeColor = i.itemType == 'Service' ? Colors.blue : Colors.purple;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  i.itemName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatPrice(i.price),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              i.itemType,
              style: TextStyle(
                fontSize: 12,
                color: typeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _onAddOrEdit(existing: i),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _onDelete(i),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  DataRow _dataRow(ServiceItemData i) {
    final fontSize = _isAdmin ? 14.0 : 16.0;
    final typeColor = i.itemType == 'Service' ? Colors.blue : Colors.purple;

    return DataRow(
      cells: [
        DataCell(
          Text(
            i.itemName,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              i.itemType,
              style: TextStyle(
                fontSize: fontSize - 2,
                color: typeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            _formatPrice(i.price),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ),
        DataCell(
          _isAdmin
              ? Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.black87,
                      ),
                      onPressed: () => _onAddOrEdit(existing: i),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                      onPressed: () => _onDelete(i),
                    ),
                  ],
                )
              : const Text(
                  'View only',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
        ),
      ],
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFE2E8F0)),
  );
}

class _ServiceItemDialog extends StatefulWidget {
  final ServiceItemData? item;
  const _ServiceItemDialog({this.item});

  @override
  State<_ServiceItemDialog> createState() => _ServiceItemDialogState();
}

class _ServiceItemDialogState extends State<_ServiceItemDialog> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  String _itemType = 'Service';

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _nameController = TextEditingController(text: i?.itemName ?? '');
    _priceController = TextEditingController(
      text: i != null ? i.price.toStringAsFixed(2) : '',
    );
    _itemType = i?.itemType ?? 'Service';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item name and price are required')),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    final item = ServiceItemData(
      id: widget.item?.id ?? 0,
      itemName: _nameController.text.trim(),
      itemType: _itemType,
      price: price,
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with drag handle
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.build,
                        color: Colors.teal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.item == null
                            ? 'Add Service Item'
                            : 'Edit Service Item',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Item Name *'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _itemType,
                    decoration: const InputDecoration(labelText: 'Item Type *'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Service',
                        child: Text('Service'),
                      ),
                      DropdownMenuItem(
                        value: 'Material',
                        child: Text('Material'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _itemType = v ?? 'Service'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Price (₱) *'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save Service Item'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
