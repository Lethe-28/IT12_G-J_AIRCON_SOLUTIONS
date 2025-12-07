import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/pdf_generator.dart';

class GenerateDefermentDialog extends StatefulWidget {
  const GenerateDefermentDialog({super.key});

  @override
  State<GenerateDefermentDialog> createState() => _GenerateDefermentDialogState();
}

class _GenerateDefermentDialogState extends State<GenerateDefermentDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _customerController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _branchAddressController = TextEditingController();
  final _branchCodeController = TextEditingController();
  final _msrNoController = TextEditingController();
  final _remarksController = TextEditingController();
  final _authorizedRepController = TextEditingController();
  final _preparedByController = TextEditingController();
  
  // Dates
  DateTime _dateFillOut = DateTime.now();
  DateTime _msrDateTime = DateTime.now();
  DateTime _durationFrom = DateTime.now();
  DateTime _durationTo = DateTime.now().add(const Duration(hours: 1));
  
  // Checkboxes
  bool _isResponseTime = false;
  bool _isResolutionTime = false;
  
  bool _isGenset = false;
  bool _isElectrical = false;
  bool _isUps = false;
  bool _isAcu = false;
  bool _isVoiceData = false;
  
  bool _isGenerating = false;

  @override
  void dispose() {
    _customerController.dispose();
    _branchNameController.dispose();
    _branchAddressController.dispose();
    _branchCodeController.dispose();
    _msrNoController.dispose();
    _remarksController.dispose();
    _authorizedRepController.dispose();
    _preparedByController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(Function(DateTime) onPicked, {bool withTime = false}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      if (withTime) {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time != null) {
          onPicked(DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ));
        }
      } else {
        onPicked(date);
      }
      setState(() {});
    }
  }

  Future<void> _generatePDF() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isGenerating = true);

    try {
      final data = DefermentFormData(
        customer: _customerController.text.trim(),
        dateFillOut: _dateFillOut,
        branchName: _branchNameController.text.trim(),
        branchAddress: _branchAddressController.text.trim(),
        branchCode: _branchCodeController.text.trim(),
        msrNo: _msrNoController.text.trim(),
        msrDateTime: _msrDateTime,
        isResponseTime: _isResponseTime,
        isResolutionTime: _isResolutionTime,
        isGenset: _isGenset,
        isElectrical: _isElectrical,
        isUps: _isUps,
        isAcu: _isAcu,
        isVoiceData: _isVoiceData,
        durationFrom: _durationFrom,
        durationTo: _durationTo,
        remarks: _remarksController.text.trim(),
        authorizedRep: _authorizedRepController.text.trim(),
        preparedBy: _preparedByController.text.trim(),
      );

      final pdfBytes = await PDFGeneratorService.generateDefermentFormV5(data);

      setState(() => _isGenerating = false);

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
          // Header
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
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_outlined, color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Generate Deferment Form',
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
                    _buildSectionTitle('Customer & Branch Details'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _customerController,
                            decoration: _inputDecor('Customer *'),
                            validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate((d) => _dateFillOut = d),
                            child: InputDecorator(
                              decoration: _inputDecor('Date Fill Out'),
                              child: Text(DateFormat('MM/dd/yyyy').format(_dateFillOut)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _branchNameController,
                      decoration: _inputDecor('Branch Name *'),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _branchAddressController,
                      decoration: _inputDecor('Branch Address *'),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _branchCodeController,
                            decoration: _inputDecor('Branch Code'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _msrNoController,
                            decoration: _inputDecor('MSR No.'),
                          ),
                        ),
                      ],
                    ),
                     const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _pickDate((d) => _msrDateTime = d, withTime: true),
                      child: InputDecorator(
                        decoration: _inputDecor('MSR Date/Time'),
                        child: Text(DateFormat('MM/dd/yyyy HH:mm').format(_msrDateTime)),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('Category'),
                    CheckboxListTile(
                      title: const Text('Response Time'),
                      value: _isResponseTime,
                      onChanged: (v) => setState(() => _isResponseTime = v!),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text('Resolution Time'),
                      value: _isResolutionTime,
                      onChanged: (v) => setState(() => _isResolutionTime = v!),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('Trade'),
                    Wrap(
                      spacing: 0,
                      runSpacing: 0,
                      children: [
                        _buildCheckbox('Genset', _isGenset, (v) => _isGenset = v),
                        _buildCheckbox('Electrical', _isElectrical, (v) => _isElectrical = v),
                        _buildCheckbox('UPS', _isUps, (v) => _isUps = v),
                        _buildCheckbox('ACU', _isAcu, (v) => _isAcu = v),
                        _buildCheckbox('Voice and Data', _isVoiceData, (v) => _isVoiceData = v),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('Deferment Duration'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate((d) => _durationFrom = d, withTime: true),
                            child: InputDecorator(
                              decoration: _inputDecor('From'),
                              child: Text(DateFormat('MM/dd HH:mm').format(_durationFrom)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate((d) => _durationTo = d, withTime: true),
                            child: InputDecorator(
                              decoration: _inputDecor('To'),
                              child: Text(DateFormat('MM/dd HH:mm').format(_durationTo)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('Remarks'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _remarksController,
                      decoration: _inputDecor('Reason for Deferment / Remarks'),
                      maxLines: 4,
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionTitle('Signatures'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _authorizedRepController,
                      decoration: _inputDecor('Authorized Representative / Branch Manager'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _preparedByController,
                      decoration: _inputDecor('Prepared by'),
                    ),
                  ],
                ),
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

  Widget _buildCheckbox(String title, bool value, Function(bool) onChanged) {
    return SizedBox(
      width: 150, // Fixed width for alignment
      child: CheckboxListTile(
        title: Text(title, style: const TextStyle(fontSize: 13)),
        value: value,
        onChanged: (v) => setState(() => onChanged(v!)),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  InputDecoration _inputDecor(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
