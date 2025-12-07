import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class WeeklyReportData {
  final String item; // Can be auto-incremented or manually set
  final String bank;
  final String branch;
  final String branchCode;
  final String sr;
  final DateTime dateReported;
  final DateTime dateCompleted;
  final String description;
  final String status;
  final String trade;

  WeeklyReportData({
    required this.item,
    required this.bank,
    required this.branch,
    required this.branchCode,
    required this.sr,
    required this.dateReported,
    required this.dateCompleted,
    required this.description,
    required this.status,
    required this.trade,
  });
}

class ExcelGeneratorService {
  static const String _templatePath = 'lib/templatedocu/zWeekly Report - TEMPLATE.xlsx';

  static Future<Uint8List?> generateWeeklyReport(WeeklyReportData data) async {
    try {
      final ByteData templateData = await rootBundle.load(_templatePath);
      final List<int> bytes = templateData.buffer.asUint8List();
      final Excel excel = Excel.decodeBytes(bytes);

      // Access the first sheet (or specific sheet if known, usually 'Sheet1' or 'Template')
      // Since it's a template, we assume the first table/sheet is the target.
      // Based on screenshot, seems to be single sheet.
      final String sheetName = excel.tables.keys.first;
      final Sheet sheet = excel[sheetName];

      // Assuming row 1 (index 0) is header. We'll append to the end or insert at row 2 (index 1).
      // If we want to strictly follow the template which has headers in row 1.
      // We should check where the last data is.
      // For now, let's just append a new row.
      
      // Map data to list matching columns: Item, Bank, Branch, Branch Code, SR, Date Reported, Date Completed, Description, Status, Trade
      // Screenshot A-J columns:
      // A: ITEM
      // B: BANK
      // C: BRANCH
      // D: BRANCH CODE
      // E: SR
      // F: DATE REPORTED
      // G: DATE COMPLETED
      // H: DESCRIPTION
      // I: STATUS
      // J: TRADE
      
      final dateFormat = DateFormat('MM/dd/yyyy');
      
      final List<CellValue> rowData = [
        TextCellValue(data.item),
        TextCellValue(data.bank),
        TextCellValue(data.branch),
        TextCellValue(data.branchCode),
        TextCellValue(data.sr),
        TextCellValue(dateFormat.format(data.dateReported)),
        TextCellValue(dateFormat.format(data.dateCompleted)),
        TextCellValue(data.description),
        TextCellValue(data.status),
        TextCellValue(data.trade),
      ];

      sheet.appendRow(rowData);

      return Uint8List.fromList(excel.encode()!);
    } catch (e) {
      print('Error generating Excel: $e');
      return null;
    }
  }
}
