import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../../models/transaction_model.dart';

class ReceiptGenerator {
  static Future<void> generateAndShare(
    BuildContext context,
    Transaction transaction,
  ) async {
    final options = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Download PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () => Navigator.pop(context, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Print'),
              onTap: () => Navigator.pop(context, 'print'),
            ),
          ],
        ),
      ),
    );

    if (options == null) return;

    final pdf = await _generatePDF(transaction);

    switch (options) {
      case 'pdf':
        await _savePDF(pdf, transaction);
        break;
      case 'share':
        await _sharePDF(pdf, transaction);
        break;
      case 'print':
        await _printPDF(pdf);
        break;
    }
  }

  static Future<pw.Document> _generatePDF(Transaction transaction) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#2196F3'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'VTU APP',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Transaction Receipt',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Status Badge
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: _getStatusColor(transaction.status),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Text(
                  _getStatusLabel(transaction.status),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

              // Transaction Details
              _buildSection('Transaction Information', [
                _buildRow('Type', _getTypeLabel(transaction.type)),
                _buildRow('Network/Provider', transaction.network),
                _buildRow(
                  'Amount',
                  '₦${NumberFormat('#,##0.00').format(transaction.amount)}',
                ),
                _buildRow('Reference', transaction.reference ?? 'N/A'),
                _buildRow(
                  'Date & Time',
                  DateFormat(
                    'MMM dd, yyyy • hh:mm:ss a',
                  ).format(transaction.createdAt),
                ),
                if (transaction.beneficiary != null)
                  _buildRow('Beneficiary', transaction.beneficiary!),
              ]),
              pw.SizedBox(height: 16),

              // Balance Info
              _buildSection('Balance Information', [
                _buildRow(
                  'Balance Before',
                  '₦${NumberFormat('#,##0.00').format(transaction.balanceBefore)}',
                ),
                _buildRow(
                  'Balance After',
                  '₦${NumberFormat('#,##0.00').format(transaction.balanceAfter)}',
                ),
              ]),
              pw.SizedBox(height: 16),

              // Electricity Token
              if (transaction.type == TransactionType.electricity &&
                  transaction.metadata?['token'] != null)
                _buildTokenSection(transaction.metadata!),

              // Exam Pins / Data Cards
              if ((transaction.type == TransactionType.examPin ||
                      transaction.type == TransactionType.dataCard) &&
                  transaction.metadata?['pins'] != null)
                _buildPinsSection(transaction.metadata!),

              pw.Spacer(),

              // Footer
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for using VTU App',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Support: support@vtuapp.com | Call: +234 800 000 0000',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildSection(String title, List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTokenSection(Map<String, dynamic> metadata) {
    final token = metadata['token'] ?? '';
    final units = metadata['units'] ?? '0';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF3E0'),
        border: pw.Border.all(color: PdfColor.fromHex('#FFB74D')),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ELECTRICITY TOKEN',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            token,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Units: $units', style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  static pw.Widget _buildPinsSection(Map<String, dynamic> metadata) {
    final pinsData = metadata['pins'];
    if (pinsData is! List) return pw.SizedBox();

    final pins = List<Map<String, dynamic>>.from(pinsData);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PINS',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          ...pins.asMap().entries.map((entry) {
            final index = entry.key;
            final pin = entry.value;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PIN ${index + 1}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Serial: ${pin['serial']}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'PIN: ${pin['pin']}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static Future<void> _savePDF(pw.Document pdf, Transaction transaction) async {
    final bytes = await pdf.save();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/receipt_${transaction.reference}.pdf');
    await file.writeAsBytes(bytes);

    // Show success message
    debugPrint('Receipt saved to: ${file.path}');
  }

  static Future<void> _sharePDF(
    pw.Document pdf,
    Transaction transaction,
  ) async {
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'receipt_${transaction.reference}.pdf',
    );
  }

  static Future<void> _printPDF(pw.Document pdf) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  static PdfColor _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.success:
        return PdfColor.fromHex('#4CAF50');
      case TransactionStatus.pending:
        return PdfColor.fromHex('#FF9800');
      case TransactionStatus.failed:
        return PdfColor.fromHex('#F44336');
    }
  }

  static String _getStatusLabel(TransactionStatus status) {
    return status.name[0].toUpperCase() + status.name.substring(1);
  }

  static String _getTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.airtime:
        return 'Airtime Purchase';
      case TransactionType.data:
        return 'Data Purchase';
      case TransactionType.cable:
        return 'Cable TV Subscription';
      case TransactionType.electricity:
        return 'Electricity Payment';
      case TransactionType.examPin:
        return 'Exam Pin Purchase';
      case TransactionType.dataCard:
        return 'Data Card Purchase';
      case TransactionType.walletFunding:
        return 'Wallet Funding';
      case TransactionType.atc:
        return 'Airtime to Cash';
      case TransactionType.referralBonus:
        return 'Referral Bonus';
      case TransactionType.referralWithdrawal:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
}
