import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/dunning_and_lockout_service.dart';

void main() {
  group('Phase 9 — Standing Orders, Credit Lockout, Dunning & BRS Tests', () {
    final customer = Customer(
      id: 1,
      code: 'CUST-001',
      shopName: 'Mayabazar Restaurant',
      ownerName: 'Subba Rao',
      phone: '9849012345',
      creditLimit: 10000.0,
      openingBalance: 0.0,
      currentBalance: 12500.0, // Exceeds limit by 25% (> 20% threshold)
      isActive: true,
      isFavorite: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('Step 9.1: Hard Credit Lockout blocks dispatch when balance breaches limit > 20%', () {
      final isLocked = DunningAndLockoutService.instance.isDispatchLockedOut(
        customer: customer,
        overdueBalance: 4000.0,
      );

      expect(isLocked, isTrue);

      // Supervisor override unblocks dispatch
      final overrideUnlocked = DunningAndLockoutService.instance.isDispatchLockedOut(
        customer: customer,
        overdueBalance: 4000.0,
        supervisorOverride: true,
      );

      expect(overrideUnlocked, isFalse);
    });

    test('Step 9.2: Three-Stage Dunning Workflow generates appropriate level notices', () {
      // Stage 1: Gentle reminder (7 days overdue)
      final stage1 = DunningAndLockoutService.instance.generateDunningNotice(
        customer: customer.copyWith(currentBalance: 5000.0),
        overdueBalance: 3000.0,
        maxDaysOverdue: 7,
      );
      expect(stage1.stage, DunningStage.gentleReminder);
      expect(stage1.isDeliveryLocked, isFalse);
      expect(stage1.suggestedWhatsAppMessage, contains('friendly reminder'));

      // Stage 2: Formal demand (20 days overdue)
      final stage2 = DunningAndLockoutService.instance.generateDunningNotice(
        customer: customer.copyWith(currentBalance: 8000.0),
        overdueBalance: 5000.0,
        maxDaysOverdue: 20,
      );
      expect(stage2.stage, DunningStage.formalDemand);
      expect(stage2.isDeliveryLocked, isFalse);
      expect(stage2.suggestedWhatsAppMessage, contains('URGENT'));

      // Stage 3: Dispatch lockout (> 30 days overdue)
      final stage3 = DunningAndLockoutService.instance.generateDunningNotice(
        customer: customer,
        overdueBalance: 12500.0,
        maxDaysOverdue: 35,
      );
      expect(stage3.stage, DunningStage.dispatchLockout);
      expect(stage3.isDeliveryLocked, isTrue);
      expect(stage3.suggestedWhatsAppMessage, contains('FINAL NOTICE'));
    });

    test('Step 9.3: Bank Reconciliation matches UPI/NEFT statement lines against ERP invoices', () {
      final now = DateTime(2026, 11, 14);
      final pendingInvoices = [
        Invoice(
          id: 101,
          invoiceNumber: 'INV-2026-101',
          orderId: 1,
          customerId: 1,
          status: 'unpaid',
          subtotal: 4500.0,
          discount: 0.0,
          tax: 0.0,
          grandTotal: 4500.0,
          paidAmount: 0.0,
          pendingAmount: 4500.0,
          isPrinted: false,
          invoiceDate: now.subtract(const Duration(days: 5)),
          createdAt: now.subtract(const Duration(days: 5)),
        ),
      ];

      final bankRows = [
        // Exact invoice match in narration
        {
          'txId': 'UPI-REF-992014',
          'date': now,
          'amount': 4500.0,
          'narration': 'UPI/CR/992014/Mayabazar/INV-2026-101',
          'mode': 'UPI',
        },
        // Unmatched credit
        {
          'txId': 'NEFT-883910',
          'date': now,
          'amount': 12000.0,
          'narration': 'NEFT-UNKNOWN-TRANSFER',
          'mode': 'NEFT',
        },
      ];

      final matches = DunningAndLockoutService.instance.reconcileBankStatement(
        bankRows: bankRows,
        pendingInvoices: pendingInvoices,
        customers: [customer],
      );

      expect(matches.length, 2);

      // First entry matched
      expect(matches[0].isMatched, isTrue);
      expect(matches[0].matchedInvoiceId, 101);
      expect(matches[0].status, 'RECONCILED');

      // Second entry unmatched
      expect(matches[1].isMatched, isFalse);
      expect(matches[1].status, 'UNMATCHED_CREDIT');
    });
  });
}
