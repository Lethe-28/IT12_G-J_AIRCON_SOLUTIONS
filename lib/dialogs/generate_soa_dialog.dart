import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/pdf_generator.dart';

class GenerateSOADialog extends StatefulWidget {
  const GenerateSOADialog({super.key});

  @override
  State<GenerateSOADialog> createState() => _GenerateSOADialogState();
}

class _GenerateSOADialogState extends State<GenerateSOADialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Customer info
  final _customerNameController = TextEditingController();
  final _customerAddressController = TextEditingController();
  
  // SOA info
  final _soaNumberController = TextEditingController();
  DateTime _soaDate = DateTime.now();
  
  // Items
  final List<_ItemRow> _items = [];
  
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // Generate SOA number
    final now = DateTime.now();
    _soaNumberController.text = 'SOA-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';
    
    // Add one initial item row
    _addItem();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _soaNumberController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_ItemRow(
        clientController: TextEditingController(),
        workController: TextEditingController(),
        amountController: TextEditingController(),
      ));
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items[index].dispose();
        _items.removeAt(index);
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _soaDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _soaDate = date;
      });
    }
  }

  Future<void> _generatePDF() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // Build items list
      final items = _items.map((item) {
        return SOAItem(
          clientName: item.clientController.text.trim(),
          workDescription: item.workController.text.trim(),
          amount: double.tryParse(item.amountController.text.trim()) ?? 0,
        );
      }).toList();

      // Create SOA data
      final soaData = SOAData(
        customerName: _customerNameController.text.trim(),
        customerAddress: _customerAddressController.text.trim(),
        soaNumber: _soaNumberController.text.trim(),
        soaDate: _soaDate,
        items: items,
      );

      // Generate PDF
      final pdfBytes = await PDFGeneratorService.generateSOA(soaData);

      setState(() => _isGenerating = false);

      // Return PDF bytes to caller
      if (mounted) {
        Navigator.of(context).pop(pdfBytes);
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
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
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.picture_as_pdf, color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Generate Statement of Account',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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

          // Form
          Flexible(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Information
                    _buildSectionTitle('Customer Information'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerNameController,
                      decoration: _inputDecor('Customer Name *'),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customerAddressController,
                      decoration: _inputDecor('Address *'),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // SOA Details
                    _buildSectionTitle('SOA Details'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _soaNumberController,
                            decoration: _inputDecor('Reference Number *'),
                            validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: _inputDecor('Date *'),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16),
                                  const SizedBox(width: 8),
                                  Text(DateFormat('MMMM dd, yyyy').format(_soaDate)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Items
                    Row(
                      children: [
                        _buildSectionTitle('Items'),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildItemRow(item, index),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          // Actions Footer
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
                    onPressed: _isGenerating ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generatePDF,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.picture_as_pdf, size: 20),
                    label: Text(_isGenerating ? 'Generating...' : 'Generate PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildItemRow(_ItemRow item, int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: item.clientController,
                      decoration: _inputDecor('Client *', dense: true),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: item.workController,
                      decoration: _inputDecor('Work Description *', dense: true),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: item.amountController,
                            decoration: _inputDecor('Amount *', dense: true),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                            validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _items.length > 1 ? () => _removeItem(index) : null,
                          icon: Icon(
                            Icons.delete_outline,
                            color: _items.length > 1 ? Colors.red : Colors.grey,
                          ),
                          tooltip: 'Remove item',
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: item.clientController,
                        decoration: _inputDecor('Client *', dense: true),
                        validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: item.workController,
                        decoration: _inputDecor('Work Description *', dense: true),
                        validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: item.amountController,
                        decoration: _inputDecor('Amount *', dense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _items.length > 1 ? () => _removeItem(index) : null,
                      icon: Icon(
                        Icons.delete_outline,
                        color: _items.length > 1 ? Colors.red : Colors.grey,
                      ),
                      tooltip: 'Remove item',
                    ),
                  ],
                ),
        );
      },
    );
  }

  InputDecoration _inputDecor(String label, {bool dense = false}) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: dense ? 8 : 12,
      ),
      isDense: dense,
    );
  }
}

class _ItemRow {
  final TextEditingController clientController;
  final TextEditingController workController;
  final TextEditingController amountController;

  _ItemRow({
    required this.clientController,
    required this.workController,
    required this.amountController,
  });

  void dispose() {
    clientController.dispose();
    workController.dispose();
    amountController.dispose();
  }
}
