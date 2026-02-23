import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/transaction_model.dart';
import '../../config/app_constants.dart';

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

    // Load logo from assets
    final logoBytes = await rootBundle.load('images/logo.jpg');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with logo centered at top
              pw.Center(
                child: pw.Column(
                  children: [
                    // Round logo
                    pw.Container(
                      width: 80,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(
                          color: PdfColor.fromHex('#2196F3'),
                          width: 2,
                        ),
                      ),
                      child: pw.ClipOval(
                        child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      AppConstants.appName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#2196F3'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Transaction Receipt',
                      style: const pw.TextStyle(
                        fontSize: 13,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Divider
              pw.Divider(color: PdfColor.fromHex('#2196F3'), thickness: 1.5),
              pw.SizedBox(height: 16),

              // Status Badge centered
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
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
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),

              // Amount centered
              pw.Center(
                child: pw.Text(
                  'N${NumberFormat('#,##0.00').format(transaction.amount)}',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#212121'),
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Transaction Details
              _buildSection('Transaction Information', [
                _buildRow('Type', _getTypeLabel(transaction.type)),
                _buildRow('Network/Provider', transaction.network),
                _buildRow(
                  'Amount',
                  'N${NumberFormat('#,##0.00').format(transaction.amount)}',
                ),
                if (transaction.reference != null &&
                    transaction.reference!.isNotEmpty)
                  _buildRow('Reference', transaction.reference!),
                _buildRow(
                  'Date & Time',
                  DateFormat(
                    'MMM dd, yyyy | hh:mm a',
                  ).format(transaction.createdAt),
                ),
                if (transaction.beneficiary != null &&
                    transaction.beneficiary!.isNotEmpty)
                  _buildRow('Beneficiary', transaction.beneficiary!),
                if (transaction.metadata?['description'] != null)
                  _buildRow(
                    'Description',
                    transaction.metadata!['description'],
                  ),
              ]),
              pw.SizedBox(height: 16),

              // Balance Info
              _buildSection('Balance Information', [
                _buildRow(
                  'Balance Before',
                  transaction.balanceBefore != null
                      ? 'N${NumberFormat('#,##0.00').format(transaction.balanceBefore)}'
                      : 'N/A',
                ),
                _buildRow(
                  'Balance After',
                  transaction.balanceAfter != null
                      ? 'N${NumberFormat('#,##0.00').format(transaction.balanceAfter)}'
                      : 'N/A',
                ),
              ]),
              pw.SizedBox(height: 16),

              // Electricity Token
              if (transaction.type == TransactionType.electricity &&
                  transaction.metadata?['token'] != null &&
                  transaction.metadata!['token'].toString().isNotEmpty)
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
                      'Thank you for using ${AppConstants.appName}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Email: ${AppConstants.supportEmail}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Phone/WhatsApp: ${AppConstants.supportPhone}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'v${AppConstants.appVersion}',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey500,
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
          pw.Flexible(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              textAlign: pw.TextAlign.right,
            ),
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
                    'Serial: ${pin['serial'] ?? 'N/A'}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'PIN: ${pin['pin'] ?? 'N/A'}',
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
    try {
      final bytes = await pdf.save();
      final filename = 'receipt_${transaction.reference ?? transaction.id}.pdf';

      if (Platform.isAndroid) {
        // Request storage permission
        final status = await Permission.manageExternalStorage.request();

        // Try public Downloads folder
        Directory? downloadsDir;

        try {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            downloadsDir = await getExternalStorageDirectory();
          }
        } catch (_) {
          downloadsDir = await getApplicationDocumentsDirectory();
        }

        final file = File('${downloadsDir!.path}/$filename');
        await file.writeAsBytes(bytes);

        debugPrint('Receipt saved to: ${file.path}');
      } else if (Platform.isIOS) {
        // On iOS save to documents then share — iOS has no public Downloads
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);
        // Fall through to share on iOS
        await Printing.sharePdf(bytes: bytes, filename: filename);
        return;
      }
    } catch (e) {
      debugPrint('Failed to save receipt: $e');
      // Fallback to share if save fails
      final bytes = await pdf.save();
      final filename = 'receipt_${transaction.reference ?? transaction.id}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }
  }

  static Future<void> _sharePDF(
    pw.Document pdf,
    Transaction transaction,
  ) async {
    final bytes = await pdf.save();
    final filename = 'receipt_${transaction.reference ?? transaction.id}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: filename);
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
    switch (status) {
      case TransactionStatus.success:
        return 'Successful';
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
    }
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
        return 'Referral Withdrawal';
    }
  }
}
