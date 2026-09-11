import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';

final invoiceDetailProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, id) async {
  final db = ref.watch(databaseProvider);
  
  // 1. Get Invoice
  final invoice = await (db.select(db.invoices)..where((i) => i.id.equals(id))).getSingleOrNull();
  if (invoice == null) return null;
  
  // 2. Get Customer
  final customer = await (db.select(db.customers)..where((c) => c.id.equals(invoice.customerId))).getSingleOrNull();
  
  // 3. Get Order Items
  final orderItems = await (db.select(db.orderItems)..where((oi) => oi.orderId.equals(invoice.orderId))).get();
  
  return {
    'invoice': invoice,
    'customer': customer,
    'items': orderItems,
  };
});

class InvoiceDetailScreen extends ConsumerWidget {
  final int id;
  const InvoiceDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invoiceDetailProvider(id));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e,_) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (data) {
        if (data == null) return const Scaffold(body: Center(child: Text('Invoice not found')));
        final Invoice invoice = data['invoice'] as Invoice;
        final Customer? customer = data['customer'] as Customer?;
        final List<OrderItem> items = (data['items'] as List).cast<OrderItem>();

        return Scaffold(
          appBar: AppBar(title: Text(invoice.invoiceNumber), actions: [
            IconButton(icon: const Icon(Icons.print_outlined), onPressed: () => _printPdf(invoice, customer, items)),
            IconButton(icon: const Icon(Icons.share_outlined), onPressed: () => _sharePdf(invoice, customer, items)),
          ]),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)), child: Column(children: [
                Text(invoice.invoiceNumber, style: AppTextStyles.titleMedium.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                const SizedBox(height: 8),
                Text(CurrencyFormatter.format(invoice.grandTotal), style: AppTextStyles.displaySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(DateFormatter.toInvoiceDate(invoice.invoiceDate), style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.8))),
              ])),
              const SizedBox(height: 16),
              Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Invoice Details', style: AppTextStyles.titleSmall),
                const SizedBox(height: 12),
                if (customer != null) _row('Customer', customer.shopName, bold: true),
                if (customer != null) const SizedBox(height: 8),
                _row('Subtotal', CurrencyFormatter.format(invoice.subtotal)),
                _row('Discount', CurrencyFormatter.format(invoice.discount)),
                _row('Tax', CurrencyFormatter.format(invoice.tax)),
                const Divider(height: 16),
                _row('Grand Total', CurrencyFormatter.format(invoice.grandTotal), bold: true),
                _row('Paid', CurrencyFormatter.format(invoice.paidAmount)),
                _row('Pending', CurrencyFormatter.format(invoice.pendingAmount), color: AppColors.error),
              ])),
            ]),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
      Expanded(child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))),
      Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
    ]));
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format, Invoice invoice, Customer? customer, List<OrderItem> items) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SR FOODS', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Smart Food Distribution'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.Text(invoice.invoiceNumber),
                      pw.Text(DateFormatter.toInvoiceDate(invoice.invoiceDate)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              if (customer != null) ...[
                pw.Text('Billed To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(customer.shopName),
                pw.Text(customer.phone),
                if (customer.address != null) pw.Text(customer.address!),
                pw.SizedBox(height: 20),
              ],
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                data: [
                  ['Item', 'Qty', 'Price', 'Total'],
                  ...items.map((i) => [
                    i.productName,
                    i.quantity.toString(),
                    CurrencyFormatter.format(i.price),
                    CurrencyFormatter.format(i.total),
                  ]),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Subtotal: ${CurrencyFormatter.format(invoice.subtotal)}'),
                      pw.Text('Discount: ${CurrencyFormatter.format(invoice.discount)}'),
                      pw.Text('Tax: ${CurrencyFormatter.format(invoice.tax)}'),
                      pw.Divider(),
                      pw.Text('Grand Total: ${CurrencyFormatter.format(invoice.grandTotal)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Amount Paid: ${CurrencyFormatter.format(invoice.paidAmount)}'),
                      pw.Text('Balance Due: ${CurrencyFormatter.format(invoice.pendingAmount)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Center(child: pw.Text('Thank you for your business!', style: const pw.TextStyle(fontSize: 12))),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _printPdf(Invoice invoice, Customer? customer, List<OrderItem> items) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => _generatePdf(format, invoice, customer, items),
      name: 'Invoice_${invoice.invoiceNumber}',
    );
  }

  Future<void> _sharePdf(Invoice invoice, Customer? customer, List<OrderItem> items) async {
    await Printing.sharePdf(
      bytes: await _generatePdf(PdfPageFormat.a4, invoice, customer, items),
      filename: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }
}
