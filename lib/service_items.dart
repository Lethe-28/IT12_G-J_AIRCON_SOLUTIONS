import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart';

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

  void _onAddOrEdit({ServiceItemData? existing}) async {
    final ServiceItemData? result = await showDialog<ServiceItemData>(
      context: context,
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
                        child: ElevatedButton.icon(
                          onPressed: () => _onAddOrEdit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Service Item'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
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
                          ElevatedButton.icon(
                            onPressed: () => _onAddOrEdit(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Service Item'),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // FIX: Responsive Filters
                  if (isMobileView) ...[
                    TextField(
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
                    const SizedBox(height: 12),
                    Container(
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
                  ] else ...[
                    Row(
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
                  ],

                  const SizedBox(height: 16),

                  // FIX: Mobile Cards vs Desktop Table
                  if (isMobileView)
                    ...items.map((i) => _buildMobileCard(i))
                  else
                    Container(
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
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item == null ? 'Add Service Item' : 'Edit Service Item',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _itemType,
                decoration: const InputDecoration(labelText: 'Item Type *'),
                items: const [
                  DropdownMenuItem(value: 'Service', child: Text('Service')),
                  DropdownMenuItem(value: 'Material', child: Text('Material')),
                ],
                onChanged: (v) => setState(() => _itemType = v ?? 'Service'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price (₱) *'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(onPressed: _submit, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
