import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../utils/communication_utils.dart';
import '../utils/formatters.dart';

/// Service dedicated to 1-tap WhatsApp business communications.
/// 100% Free - uses official wa.me direct links without any API or SMS fees.
class WhatsAppService {
  WhatsAppService._();

  /// Share an itemized invoice directly to customer's WhatsApp
  static Future<void> shareInvoice({
    required BuildContext context,
    required Invoice invoice,
    required Customer? customer,
    required List<OrderItem> items,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('🧾 *SR FOODS - INVOICE*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('*Invoice No:* ${invoice.invoiceNumber}');
    buffer.writeln('*Date:* ${DateFormatter.toInvoiceDate(invoice.invoiceDate)}');
    if (customer != null) {
      buffer.writeln('*Billed To:* ${customer.shopName}');
      if (customer.ownerName.isNotEmpty && customer.ownerName != customer.shopName) {
        buffer.writeln('*Contact Person:* ${customer.ownerName}');
      }
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📦 *Items Ordered:*');

    for (final item in items) {
      final unitStr = item.quantity.toString();
      final totalStr = CurrencyFormatter.format(item.total);
      final priceStr = CurrencyFormatter.format(item.price);
      buffer.writeln('• ${item.productName} ($unitStr @ $priceStr) = $totalStr');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('*Subtotal:* ${CurrencyFormatter.format(invoice.subtotal)}');
    if (invoice.discount > 0) {
      buffer.writeln('*Discount:* -${CurrencyFormatter.format(invoice.discount)}');
    }
    if (invoice.tax > 0) {
      buffer.writeln('*Tax:* ${CurrencyFormatter.format(invoice.tax)}');
    }
    buffer.writeln('*Grand Total:* ${CurrencyFormatter.format(invoice.grandTotal)}');
    buffer.writeln('*Amount Paid:* ${CurrencyFormatter.format(invoice.paidAmount)}');
    buffer.writeln('*Balance Due:* ${CurrencyFormatter.format(invoice.pendingAmount)}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🙏 *Thank you for your business!*');
    buffer.writeln('SR Foods - Quality You Can Trust');

    final phone = customer?.phone ?? '';
    await CommunicationUtils.launchWhatsApp(context, phone, message: buffer.toString());
  }

  /// Send a polite Khata balance / payment reminder to the customer
  static Future<void> sharePaymentReminder({
    required BuildContext context,
    required Customer customer,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('Namaste *${customer.shopName}* 🙏,');
    buffer.writeln('');
    buffer.writeln('This is a gentle reminder from *SR Foods*.');
    buffer.writeln('Your current outstanding balance is *${CurrencyFormatter.format(customer.currentBalance)}*.');
    buffer.writeln('');
    buffer.writeln('Kindly arrange to clear the pending dues at your earliest convenience.');
    buffer.writeln('For any queries or fresh orders, reply directly to this message.');
    buffer.writeln('');
    buffer.writeln('Thank you for your continued partnership! 🤝');
    buffer.writeln('*SR Foods*');

    await CommunicationUtils.launchWhatsApp(context, customer.phone, message: buffer.toString());
  }

  /// Broadcast the current food product price list to customers or groups
  static Future<void> shareProductCatalog({
    required BuildContext context,
    required List<Product> products,
    String? recipientPhone,
  }) async {
    final activeProducts = products.where((p) => p.isActive).toList();
    if (activeProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active products to share')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('🌟 *SR FOODS - FRESH PRODUCT & PRICE LIST* 🌟');
    buffer.writeln('High Quality & Hygienic Food Products');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');

    for (int i = 0; i < activeProducts.length; i++) {
      final p = activeProducts[i];
      final priceStr = CurrencyFormatter.format(p.price);
      final unitStr = p.unit.isNotEmpty ? '/${p.unit}' : '';
      buffer.writeln('${i + 1}. *${p.name}* - $priceStr $unitStr');
      if (p.description != null && p.description!.isNotEmpty) {
        buffer.writeln('   _${p.description}_');
      }
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📲 *To place an order:*');
    buffer.writeln('Reply directly to this WhatsApp message or call us!');
    buffer.writeln('⚡ Fast Delivery & Best Wholesale Rates guaranteed.');

    await CommunicationUtils.launchWhatsApp(context, recipientPhone ?? '', message: buffer.toString());
  }

  /// Format customer order message from web catalog to send to manager's WhatsApp
  static Future<void> sendOrderToManager({
    required BuildContext context,
    required String managerPhone,
    required String customerName,
    required String customerPhone,
    required String addressOrNotes,
    required List<Map<String, dynamic>> cartItems, // {name, quantity, price, total}
    required double grandTotal,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('🛍️ *NEW ORDER - SR FOODS*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('*Customer/Shop:* $customerName');
    buffer.writeln('*Contact Phone:* $customerPhone');
    if (addressOrNotes.isNotEmpty) {
      buffer.writeln('*Delivery Notes:* $addressOrNotes');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📦 *Order Details:*');

    for (final item in cartItems) {
      final name = item['name'];
      final qty = item['quantity'];
      final price = CurrencyFormatter.format((item['price'] as num).toDouble());
      final total = CurrencyFormatter.format((item['total'] as num).toDouble());
      buffer.writeln('• $name (x$qty @ $price) = $total');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('*Total Order Value:* ${CurrencyFormatter.format(grandTotal)}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Please confirm this order and dispatch time. Thank you!');

    await CommunicationUtils.launchWhatsApp(context, managerPhone, message: buffer.toString());
  }
}
