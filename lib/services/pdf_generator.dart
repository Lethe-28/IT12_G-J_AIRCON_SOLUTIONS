import 'dart:typed_data';
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

class PDFGeneratorService {
  static final dateFormat = DateFormat('MMMM dd, yyyy');
  
  static String formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '₱ ${formatter.format(amount)}';
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
                  pw.Text('Address:', style: const pw.TextStyle(fontSize: 10)),
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
