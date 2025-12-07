import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class SOAData {
  final String customerName;
  final String customerAddress;
  final String soaNumber;
  final DateTime soaDate;
  final List<SOAItem> items;

  SOAData({
    required this.customerName,
    required this.customerAddress,
    required this.soaNumber,
    required this.soaDate,
    required this.items,
  });

  double get total => items.fold(0, (sum, item) => sum + item.total);
}

class SOAItem {
  final String clientName;
  final String workDescription;
  final double amount;

  SOAItem({
    required this.clientName,
    required this.workDescription,
    required this.amount,
  });

  double get total => amount;
}

class DefermentFormData {
  final String customer;
  final DateTime dateFillOut;
  final String branchName;
  final String branchAddress;
  final String branchCode;
  final String msrNo;
  final DateTime msrDateTime;
  
  // Category (true if selected)
  final bool isResponseTime;
  final bool isResolutionTime;
  
  // Trade (true if selected)
  final bool isGenset;
  final bool isElectrical;
  final bool isUps;
  final bool isAcu;
  final bool isVoiceData;
  
  final DateTime durationFrom;
  final DateTime durationTo;
  final String remarks;
  
  final String authorizedRep;
  final String preparedBy;

  DefermentFormData({
    required this.customer,
    required this.dateFillOut,
    required this.branchName,
    required this.branchAddress,
    required this.branchCode,
    required this.msrNo,
    required this.msrDateTime,
    required this.isResponseTime,
    required this.isResolutionTime,
    required this.isGenset,
    required this.isElectrical,
    required this.isUps,
    required this.isAcu,
    required this.isVoiceData,
    required this.durationFrom,
    required this.durationTo,
    required this.remarks,
    required this.authorizedRep,
    required this.preparedBy,
  });
}

class PDFGeneratorService {
  static final dateFormat = DateFormat('MMMM dd, yyyy');
  static final dateTimeFormat = DateFormat('MMMM dd, yyyy HH:mm');
  
  static String formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return 'PHP ${formatter.format(amount)}';
  }

  static Future<Uint8List> generateSOA(SOAData data) async {
    final pdf = pw.Document();

    // Load logo
    final logoData = await rootBundle.load('lib/image/logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with company info
              _buildHeader(logoImage),
              pw.SizedBox(height: 20),

              // SOA Title
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Statement of Accounts',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Reference: ${data.soaNumber}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Bill To section
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Bill to:', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 3),
                  pw.Text(data.customerName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text('Address:', style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 3),
                  pw.Text(data.customerAddress, style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
              pw.SizedBox(height: 20),
              // Date aligned right
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Date: ${dateFormat.format(data.soaDate)}', style: const pw.TextStyle(fontSize: 10)),
              ),
              pw.SizedBox(height: 15),

              // Items Table
              _buildItemsTable(data.items),

              // Totals (no gap)
              _buildTotalsSection(data),
              pw.SizedBox(height: 25),

              // Payment Instructions
              pw.Text(
                'Please send payment of the total amount to the bank account below:',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              pw.Text('Bank: Bank of the Philippine Islands (BPI)', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Account Number: 2149-7202-41', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Account Name: Jemima Obsequio', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 30),

              // Prepared by section
              pw.Text('Prepared by:', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 8),
              pw.Text(
                'Ms. Kharis Obsequio',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Admin | G&J Aircon Solutions',
                style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
              ),
              pw.Text(
                'gandjairconsolutions@gmail.com',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue700),
              ),
              pw.Text('(+63) 985 171 4321', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('(082) 272 8134', style: const pw.TextStyle(fontSize: 9)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateDefermentFormV5(DefermentFormData data) async {
    final pdf = pw.Document();

    final logoData = await rootBundle.load('lib/image/FMIDC Logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Logo centered at top
              pw.Center(
                child: pw.Container(
                  width: 150,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              ),
              pw.SizedBox(height: 15),
              
              // Header addresses
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Left address
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FMIDC Building, 837 Ma. Clara St', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Brgy. Plainview, Mandaluyong City', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Trunk line: 635-5041 / Fax no. 635-5027', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Email: mail@fmidc.com-www.fmidc.com', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  // Right address
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Sucat office:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Km.18 East Service Rd.', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('South Super Hi-way, Taguig, Metro Manila', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Tel No. 519-8851', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              
              // Title
              pw.Center(
                child: pw.Text(
                  'DEFERMENT FORM',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
                ),
              ),
              pw.SizedBox(height: 25),
              
              // Customer and Date Fill out row
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Customer: ', style: const pw.TextStyle(fontSize: 10)),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(data.customer, style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Text('Date Fill out: ', style: const pw.TextStyle(fontSize: 10)),
                  pw.Expanded(
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(dateFormat.format(data.dateFillOut), style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              
              // Branch Name
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Branch Name: ', style: const pw.TextStyle(fontSize: 10)),
                  pw.Expanded(
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(data.branchName, style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              
              // Branch Address
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Branch Address: ', style: const pw.TextStyle(fontSize: 10)),
                  pw.Expanded(
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(data.branchAddress, style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              
              // Branch Code
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Branch Code: ', style: const pw.TextStyle(fontSize: 10)),
                  pw.Expanded(
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(data.branchCode, style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              
              // MSR No and Date/Time
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('MSR No.: ', style: const pw.TextStyle(fontSize: 10)),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(data.msrNo, style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Text('Date/Time: ', style: const pw.TextStyle(fontSize: 10)),
                  pw.Expanded(
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(dateTimeFormat.format(data.msrDateTime), style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 25),
              
              // CATEGORY
              pw.Center(
                child: pw.Text(
                  'CATEGORY',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildCheckbox('Response Time', data.isResponseTime, fontSize: 11),
                  _buildCheckbox('Resolution Time', data.isResolutionTime, fontSize: 11),
                ],
              ),
              pw.SizedBox(height: 25),
              
              // TRADE
              pw.Center(
                child: pw.Text(
                  'TRADE',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildCheckbox('Genset', data.isGenset, fontSize: 10),
                  _buildCheckbox('Electrical', data.isElectrical, fontSize: 10),
                  _buildCheckbox('UPS', data.isUps, fontSize: 10),
                  _buildCheckbox('ACU', data.isAcu, fontSize: 10),
                  _buildCheckbox('Voice and Data', data.isVoiceData, fontSize: 10),
                ],
              ),
              pw.SizedBox(height: 25),
              
              // Deferment Duration
              pw.Text('Deferment Duration', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('From (Date/Time): ', style: const pw.TextStyle(fontSize: 10)),
                  pw.Expanded(
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(dateTimeFormat.format(data.durationFrom), style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('To (Date/Time): ', style: const pw.TextStyle(fontSize: 10)),
                  pw.Expanded(
                    child: pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(dateTimeFormat.format(data.durationTo), style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              
              // Remarks
              pw.Text('Reason/s for Deferment / Remarks:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Container(
                height: 90,
                child: pw.Stack(
                  children: [
                    // Lines
                    pw.Positioned.fill(
                      child: pw.CustomPaint(
                        painter: (canvas, size) {
                          const double topOffset = 10.0;
                          const double spacing = 16.0;
                          for (int i = 0; i < 5; i++) {
                            canvas.drawLine(
                              0,
                              topOffset + (i * spacing),
                              size.x,
                              topOffset + (i * spacing),
                            );
                          }
                        },
                      ),
                    ),
                    // Text
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 0),
                      child: pw.Text(data.remarks, style: const pw.TextStyle(fontSize: 10)),
                    ),
                    // Text
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(data.remarks, style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 50), // Increased spacing after remarks
              
              // Authorized Representative
              pw.Container(
                width: 200, // Shorter line, about 40% width
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.0))),
                      height: 1,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('Authorized Representative (Position) / Branch Manager', style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 1),
                    pw.Text('Signature over printed name and contact details', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.SizedBox(height: 40), // Increased spacing between signature sections
              
              // Prepared by
              pw.Container(
                width: 200, // Shorter line, about 40% width
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.0))),
                      height: 1,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('Prepared by: Signature over printed name', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
  
  static pw.Widget _buildCheckbox(String label, bool value, {double fontSize = 10}) {
     return pw.Row(
       mainAxisSize: pw.MainAxisSize.min,
       children: [
         pw.Container(
           width: 20,
           height: 12,
           decoration: pw.BoxDecoration(
             border: pw.Border.all(color: PdfColors.black, width: 0.8),
           ),
           child: value ? pw.Center(child: pw.Text('x', style: pw.TextStyle(fontSize: fontSize))) : null,
         ),
         pw.SizedBox(width: 8),
         pw.Text(label, style: pw.TextStyle(fontSize: fontSize)),
       ],
     );
  }

  static pw.Widget _buildHeader(pw.MemoryImage logo) {
    return pw.Center(
      child: pw.Column(
        children: [
          // Logo
          pw.Image(logo, width: 80, height: 80),
          pw.SizedBox(height: 8),
          // Company address
          pw.Text(
            "G AND J Aircon Solutions, Door 9, Teresita's Promenade, De Guzman St.,",
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'Toril Proper, Davao City, 8000',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Text('$label ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(List<SOAItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey800, width: 1),
      children: [
        // Header
        pw.TableRow(
          children: [
            _buildTableHeader('CLIENT'),
            _buildTableHeader('WORK'),
            _buildTableHeader('AMOUNT', align: pw.TextAlign.right),
          ],
        ),
        // Items
        ...items.map((item) => pw.TableRow(
          children: [
            _buildTableCell(item.clientName),
            _buildTableCell(item.workDescription),
            _buildTableCell(formatCurrency(item.amount), align: pw.TextAlign.right),
          ],
        )),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10), textAlign: align),
    );
  }

  static pw.Widget _buildTotalsSection(SOAData data) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey800, width: 1),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              alignment: pw.Alignment.centerRight,
              child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ),
          ),
          pw.Container(
            width: 150,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: PdfColors.grey800, width: 1)),
            ),
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              formatCurrency(data.total),
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalRow(String label, String value, {bool isBold = false, double fontSize = 10}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
