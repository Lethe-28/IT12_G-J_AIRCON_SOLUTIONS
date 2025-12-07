import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/excel_generator.dart';

class GenerateWeeklyReportDialog extends StatefulWidget {
  const GenerateWeeklyReportDialog({super.key});

  @override
  State<GenerateWeeklyReportDialog> createState() => _GenerateWeeklyReportDialogState();
}

class _GenerateWeeklyReportDialogState extends State<GenerateWeeklyReportDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _itemController = TextEditingController();
  final _bankController = TextEditingController();
  final _branchController = TextEditingController();
  final _branchCodeController = TextEditingController();
  final _srController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _statusController = TextEditingController();
  final _tradeController = TextEditingController();
  
  DateTime _dateReported = DateTime.now();
  DateTime _dateCompleted = DateTime.now();

  bool _isGenerating = false;

  @override
  void dispose() {
    _itemController.dispose();
    _bankController.dispose();
    _branchController.dispose();
    _branchCodeController.dispose();
    _srController.dispose();
    _descriptionController.dispose();
    _statusController.dispose();
    _tradeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isReported) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isReported ? _dateReported : _dateCompleted,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isReported) {
          _dateReported = picked;
        } else {
          _dateCompleted = picked;
        }
      });
    }
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isGenerating = true);

    try {
      final data = WeeklyReportData(
        item: _itemController.text,
        bank: _bankController.text,
        branch: _branchController.text,
        branchCode: _branchCodeController.text,
        sr: _srController.text,
        dateReported: _dateReported,
        dateCompleted: _dateCompleted,
        description: _descriptionController.text,
        status: _statusController.text,
        trade: _tradeController.text,
      );

      final bytes = await ExcelGeneratorService.generateWeeklyReport(data);
      
      if (mounted) {
        Navigator.pop(context, bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.table_chart, color: Color(0xFF2563EB)),
                const SizedBox(width: 12),
                const Text(
                  'Weekly Report',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Report Details'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Item No.', _itemController)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('SR No.', _srController)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Bank', _bankController)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('Branch Code', _branchCodeController)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Branch Name', _branchController),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('Dates'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker('Date Reported', _dateReported, () => _selectDate(context, true))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDatePicker('Date Completed', _dateCompleted, () => _selectDate(context, false))),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _buildSectionTitle('Work Details'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Status', _statusController)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('Trade', _tradeController)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Description', _descriptionController, maxLines: 3),
                  ],
                ),
              ),
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isGenerating 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Generate Excel Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
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
        fontWeight: FontWeight.bold,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDatePicker(String label, DateTime date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MM/dd/yyyy').format(date),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
