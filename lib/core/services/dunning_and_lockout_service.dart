import '../database/app_database.dart';

/// Dunning notice action level
enum DunningStage {
  gentleReminder(1, 'Gentle Restock Reminder', 0xFFF57F17),
  formalDemand(2, 'Formal Demand & Credit Review', 0xFFE65100),
  dispatchLockout(3, 'Final Legal Demand & Dispatch Lockout', 0xFFC62828);

  final int stageNumber;
  final String title;
  final int colorValue;
  const DunningStage(this.stageNumber, this.title, this.colorValue);
}

/// Dunning Notice Generation Output
class DunningNotice {
  final int customerId;
  final String customerName;
  final DunningStage stage;
  final double overdueAmount;
  final int daysOverdue;
  final String noticeText;
  final String suggestedWhatsAppMessage;
  final bool isDeliveryLocked;

  const DunningNotice({
    required this.customerId,
    required this.customerName,
    required this.stage,
    required this.overdueAmount,
    required this.daysOverdue,
    required this.noticeText,
    required this.suggestedWhatsAppMessage,
    required this.isDeliveryLocked,
  });
}

/// Bank Statement Reconciliation Match Result
class BankReconciliationMatch {
  final String bankTransactionId;
  final DateTime date;
  final double amount;
  final String mode; // 'UPI', 'NEFT', 'IMPS'
  final int? matchedInvoiceId;
  final String? matchedCustomerCode;
  final bool isMatched;
  final String status; // 'RECONCILED', 'UNMATCHED_CREDIT', 'AMOUNT_MISMATCH'

  const BankReconciliationMatch({
    required this.bankTransactionId,
    required this.date,
    required this.amount,
    required this.mode,
    this.matchedInvoiceId,
    this.matchedCustomerCode,
    required this.isMatched,
    required this.status,
  });
}

/// Service managing credit lockouts, dunning workflows, and bank reconciliation
class DunningAndLockoutService {
  DunningAndLockoutService._();
  static final DunningAndLockoutService instance = DunningAndLockoutService._();

  /// Checks if new orders/dispatches should be locked out for a customer
  bool isDispatchLockedOut({
    required Customer customer,
    required double overdueBalance,
    bool supervisorOverride = false,
  }) {
    if (supervisorOverride) return false;

    // Hard Lockout Rule 1: Outstanding balance exceeds credit limit by > 20%
    if (customer.creditLimit > 0 && customer.currentBalance > (customer.creditLimit * 1.20)) {
      return true;
    }

    // Hard Lockout Rule 2: Overdue balance exceeds customer credit limit
    if (customer.creditLimit > 0 && overdueBalance >= customer.creditLimit) {
      return true;
    }

    // Hard Lockout Rule 3: Customer inactive / deactivated
    if (!customer.isActive) {
      return true;
    }

    return false;
  }

  /// Evaluates and generates appropriate stage dunning notice
  DunningNotice generateDunningNotice({
    required Customer customer,
    required double overdueBalance,
    required int maxDaysOverdue,
  }) {
    DunningStage stage;
    bool lockDispatch = false;

    if (maxDaysOverdue > 30 || overdueBalance >= customer.creditLimit) {
      stage = DunningStage.dispatchLockout;
      lockDispatch = true;
    } else if (maxDaysOverdue >= 16) {
      stage = DunningStage.formalDemand;
      lockDispatch = false;
    } else {
      stage = DunningStage.gentleReminder;
      lockDispatch = false;
    }

    String noticeText;
    String waMessage;

    switch (stage) {
      case DunningStage.gentleReminder:
        noticeText = 'Gentle payment reminder for outstanding balance of Rs ${overdueBalance.toStringAsFixed(0)}.';
        waMessage = 'Namaste ${customer.ownerName} garu, friendly reminder from SR Foods: invoice payment of Rs ${overdueBalance.toStringAsFixed(0)} is due. Please clear via UPI (${customer.code}) at your earliest convenience. Thank you!';
        break;
      case DunningStage.formalDemand:
        noticeText = 'Formal Notice: Balance of Rs ${overdueBalance.toStringAsFixed(0)} is overdue by $maxDaysOverdue days. Immediate clearance required.';
        waMessage = 'URGENT - SR Foods: An overdue balance of Rs ${overdueBalance.toStringAsFixed(0)} is pending for $maxDaysOverdue days for ${customer.shopName}. Please arrange payment today to ensure uninterrupted morning bread delivery.';
        break;
      case DunningStage.dispatchLockout:
        noticeText = 'DISPATCH SUSPENSION NOTICE: Account on credit freeze due to Rs ${overdueBalance.toStringAsFixed(0)} overdue ($maxDaysOverdue days). Advance payment required for future drops.';
        waMessage = 'FINAL NOTICE - SR Foods Accounts: Dispatches have been placed on temporary hold for ${customer.shopName} due to Rs ${overdueBalance.toStringAsFixed(0)} overdue. Please call 9440067933 or clear outstanding balance to restore automated route drops.';
        break;
    }

    return DunningNotice(
      customerId: customer.id,
      customerName: customer.shopName,
      stage: stage,
      overdueAmount: overdueBalance,
      daysOverdue: maxDaysOverdue,
      noticeText: noticeText,
      suggestedWhatsAppMessage: waMessage,
      isDeliveryLocked: lockDispatch,
    );
  }

  /// Reconciles bank statement lines against pending ERP invoices
  List<BankReconciliationMatch> reconcileBankStatement({
    required List<Map<String, dynamic>> bankRows, // [{txId, date, amount, narration, mode}]
    required List<Invoice> pendingInvoices,
    required List<Customer> customers,
  }) {
    final results = <BankReconciliationMatch>[];
    final customerMap = {for (var c in customers) c.code.toLowerCase(): c};

    for (final row in bankRows) {
      final txId = row['txId'] as String;
      final date = row['date'] as DateTime;
      final amount = (row['amount'] as num).toDouble();
      final narration = (row['narration'] as String? ?? '').toLowerCase();
      final mode = row['mode'] as String? ?? 'UPI';

      // Look for exact invoice number match in narration
      Invoice? matchedInv;
      for (final inv in pendingInvoices) {
        if (narration.contains(inv.invoiceNumber.toLowerCase())) {
          matchedInv = inv;
          break;
        }
      }

      // If no invoice number found, look for customer code match
      String? matchedCustCode;
      if (matchedInv == null) {
        for (final entry in customerMap.entries) {
          if (narration.contains(entry.key)) {
            matchedCustCode = entry.value.code;
            // Find invoice with matching pending amount
            for (final inv in pendingInvoices) {
              if (inv.customerId == entry.value.id && (inv.pendingAmount - amount).abs() < 1.0) {
                matchedInv = inv;
                break;
              }
            }
            break;
          }
        }
      }

      if (matchedInv != null) {
        final isExact = (matchedInv.pendingAmount - amount).abs() < 1.0;
        results.add(BankReconciliationMatch(
          bankTransactionId: txId,
          date: date,
          amount: amount,
          mode: mode,
          matchedInvoiceId: matchedInv.id,
          matchedCustomerCode: matchedCustCode,
          isMatched: true,
          status: isExact ? 'RECONCILED' : 'AMOUNT_MISMATCH',
        ));
      } else {
        results.add(BankReconciliationMatch(
          bankTransactionId: txId,
          date: date,
          amount: amount,
          mode: mode,
          isMatched: false,
          status: 'UNMATCHED_CREDIT',
        ));
      }
    }

    return results;
  }
}
