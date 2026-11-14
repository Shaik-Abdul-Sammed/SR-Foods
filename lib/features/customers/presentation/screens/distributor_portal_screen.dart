import 'package:flutter/material.dart';
import '../../../../core/domain/money.dart';
import '../../../../core/i18n/locale_context.dart';
import '../../../orders/presentation/widgets/export_shipment_tracker_card.dart';

class ArAgingBuckets {
  final Money current;
  final Money days30;
  final Money days60;
  final Money days90Plus;

  const ArAgingBuckets({
    required this.current,
    required this.days30,
    required this.days60,
    required this.days90Plus,
  });

  Money get totalOutstanding => current + days30 + days60 + days90Plus;
}

class DistributorPriceOverride {
  final String sku;
  final String productName;
  final Money masterPrice;
  final Money contractPrice;

  const DistributorPriceOverride({
    required this.sku,
    required this.productName,
    required this.masterPrice,
    required this.contractPrice,
  });

  double get discountPercent {
    if (masterPrice.amountMinor <= 0) return 0.0;
    final diff = masterPrice.amountMinor - contractPrice.amountMinor;
    return (diff / masterPrice.amountMinor) * 100.0;
  }
}

class DistributorPortalScreen extends StatelessWidget {
  final String distributorName;
  final String countryCode;
  final Currency currency;
  final String taxId;
  final int creditDays;
  final String incotermsDefault;
  final Money creditLimit;
  final ArAgingBuckets arAging;
  final List<DistributorPriceOverride> priceOverrides;
  final String? activeContainerNumber;
  final String? activeSealNumber;
  final double? activeReeferTemp;
  final ExportMilestone? activeShipmentMilestone;

  const DistributorPortalScreen({
    super.key,
    required this.distributorName,
    required this.countryCode,
    required this.currency,
    required this.taxId,
    this.creditDays = 30,
    this.incotermsDefault = 'CIF',
    required this.creditLimit,
    required this.arAging,
    this.priceOverrides = const [],
    this.activeContainerNumber,
    this.activeSealNumber,
    this.activeReeferTemp,
    this.activeShipmentMilestone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableCredit = creditLimit - arAging.totalOutstanding;

    return Scaffold(
      appBar: AppBar(
        title: Text('$distributorName ($countryCode)'),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Distributor Profile Header Card
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          distributorName,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.indigo[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.indigo[200]!),
                          ),
                          child: Text(
                            '$countryCode • ${currency.code}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tax / TRN ID: $taxId | Terms: Net $creditDays Days ($incotermsDefault)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const Divider(height: 20),

                    // Credit Limit & Utilization Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            'CREDIT LIMIT',
                            creditLimit.formatted,
                            Colors.blue[900]!,
                          ),
                        ),
                        Expanded(
                          child: _buildMetricTile(
                            'OUTSTANDING',
                            arAging.totalOutstanding.formatted,
                            arAging.totalOutstanding > creditLimit ? Colors.red[800]! : Colors.orange[900]!,
                          ),
                        ),
                        Expanded(
                          child: _buildMetricTile(
                            'AVAILABLE CREDIT',
                            availableCredit.formatted,
                            availableCredit.isNegative ? Colors.red : Colors.teal[800]!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Accounts Receivable (AR) Aging Card
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ACCOUNTS RECEIVABLE (AR) AGING',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        Text(
                          currency.code,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Table(
                      border: TableBorder.all(color: Colors.grey[300]!, width: 0.8),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey[100]),
                          children: const [
                            _AgingHeaderCell('Current'),
                            _AgingHeaderCell('1-30 Days'),
                            _AgingHeaderCell('31-60 Days'),
                            _AgingHeaderCell('61-90+ Days'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _AgingValueCell(arAging.current.formatted, isOverdue: false),
                            _AgingValueCell(arAging.days30.formatted, isOverdue: false),
                            _AgingValueCell(arAging.days60.formatted, isOverdue: arAging.days60.isPositive),
                            _AgingValueCell(arAging.days90Plus.formatted, isOverdue: arAging.days90Plus.isPositive),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Active In-Transit Shipment Tracker Card
            if (activeContainerNumber != null && activeShipmentMilestone != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'ACTIVE EXPORT SHIPMENT TRACKING',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              ExportShipmentTrackerCard(
                orderNumber: 'EXP-ORD-${distributorName.substring(0, 3).toUpperCase()}',
                containerNumber: activeContainerNumber!,
                sealNumber: activeSealNumber ?? 'SEAL-INTACT',
                portOfLoading: 'Nhava Sheva (INNSA)',
                portOfDischarge: 'Jebel Ali (AEJEA)',
                actualTemperatureCelsius: activeReeferTemp ?? -18.2,
                currentMilestone: activeShipmentMilestone!,
              ),
            ],

            // Contract Price List Overrides
            if (priceOverrides.isNotEmpty) ...[
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONTRACT PRICE LIST & EXPORT DISCOUNTS',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      ...priceOverrides.map((po) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(po.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text('SKU: ${po.sku}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    po.contractPrice.formatted,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo[900]),
                                  ),
                                  Text(
                                    '${po.discountPercent.toStringAsFixed(1)}% off master (${po.masterPrice.formatted})',
                                    style: const TextStyle(fontSize: 10, color: Colors.teal),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _AgingHeaderCell extends StatelessWidget {
  final String text;
  const _AgingHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _AgingValueCell extends StatelessWidget {
  final String text;
  final bool isOverdue;
  const _AgingValueCell(this.text, {required this.isOverdue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isOverdue ? Colors.red[800] : Colors.black87,
        ),
      ),
    );
  }
}
