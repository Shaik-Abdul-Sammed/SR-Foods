import 'package:drift/drift.dart';

/// Products table
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sku => text().unique()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('General'))();
  RealColumn get price => real()();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  IntColumn get piecesPerPack => integer().withDefault(const Constant(1))();
  RealColumn get weightGrams => real().withDefault(const Constant(0.0))();
  TextColumn get unit => text().withDefault(const Constant('Pack'))();
  TextColumn get imagePath => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get qrCode => text().nullable()();
  IntColumn get currentStock => integer().withDefault(const Constant(0))();
  IntColumn get minStock => integer().withDefault(const Constant(10))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  TextColumn get taxCategory => text().withDefault(const Constant('NONE'))();
  TextColumn get storageType => text().withDefault(const Constant('chilled'))(); // ambient | chilled | frozen
  TextColumn get allergens => text().withDefault(const Constant(''))();
  TextColumn get hsnCode => text().withDefault(const Constant('1905'))();
  IntColumn get shelfLifeDays => integer().withDefault(const Constant(7))();
  IntColumn get unitsPerInnerPack => integer().withDefault(const Constant(1))();
  IntColumn get packsPerMasterCarton => integer().withDefault(const Constant(20))();
  TextColumn get gtin => text().nullable()();
  TextColumn get fssaiCategoryCode => text().nullable()();
  TextColumn get nutritionPer100gJson => text().nullable()();
  TextColumn get primaryMarkets => text().nullable()();
  TextColumn get priceBandCurrency => text().withDefault(const Constant('INR'))();
  RealColumn get fatPercentExpected => real().nullable()();
  RealColumn get snfPercentExpected => real().nullable()();
  TextColumn get milkType => text().nullable()();
  TextColumn get procurementSlot => text().nullable()();
  BoolColumn get isPasteurized => boolean().nullable()();
  BoolColumn get isCultured => boolean().nullable()();
  BoolColumn get bakeDateRequired => boolean().nullable()();
  IntColumn get proofingMinutes => integer().nullable()();
  TextColumn get ovenType => text().nullable()();
  IntColumn get freshnessWindowHours => integer().nullable()();
  RealColumn get dayOldDiscountPercent => real().nullable()();
  BoolColumn get isCustomOrder => boolean().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Customers table
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().unique()();
  TextColumn get shopName => text()();
  TextColumn get ownerName => text()();
  TextColumn get phone => text()();
  TextColumn get altPhone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get area => text().nullable()();
  TextColumn get route => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get pincode => text().nullable()();
  RealColumn get creditLimit => real().withDefault(const Constant(5000.0))();
  RealColumn get openingBalance => real().withDefault(const Constant(0.0))();
  RealColumn get currentBalance => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Orders table
class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get orderNumber => text().unique()();
  IntColumn get customerId => integer().references(Customers, #id)();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  // status: pending | processing | delivered | cancelled
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get tax => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real().withDefault(const Constant(0.0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get pendingAmount => real().withDefault(const Constant(0.0))();
  TextColumn get paymentStatus => text().withDefault(const Constant('unpaid'))();
  // paymentStatus: unpaid | partial | paid
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get deliveryAddress => text().nullable()();
  IntColumn get invoiceId => integer().nullable()();
  DateTimeColumn get orderDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deliveryDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Order Items table
class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get productName => text()();
  RealColumn get price => real()();
  IntColumn get quantity => integer()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real()();
  TextColumn get batchNumber => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Invoices table
class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().unique()();
  IntColumn get orderId => integer().references(Orders, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get tax => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get pendingAmount => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('unpaid'))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isPrinted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get invoiceDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Payments table
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get receiptNumber => text().unique()();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get invoiceId => integer().nullable().references(Invoices, #id)();
  IntColumn get orderId => integer().nullable().references(Orders, #id)();
  RealColumn get amount => real()();
  TextColumn get method => text()();
  // method: cash | upi | bank | credit
  TextColumn get upiTransactionId => text().nullable()();
  TextColumn get bankRefNumber => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get paymentDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Production Batches table
class ProductionBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get batchNumber => text().unique()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get operatorName => text()();
  IntColumn get quantityProduced => integer()();
  RealColumn get totalWeight => real().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  DateTimeColumn get manufacturingDate => dateTime()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  RealColumn get fatPercentActual => real().nullable()();
  RealColumn get snfPercentActual => real().nullable()();
  TextColumn get milkSupplierId => text().nullable()();
  TextColumn get chillingCenterId => text().nullable()();
  RealColumn get pasteurizationTempC => real().nullable()();
  IntColumn get pasteurizationDurationSec => integer().nullable()();
  DateTimeColumn get bakedAt => dateTime().nullable()();
  DateTimeColumn get proofedAt => dateTime().nullable()();
  TextColumn get ovenId => text().nullable()();
  DateTimeColumn get freshnessUntil => dateTime().nullable()();
  DateTimeColumn get dayOldAppliedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Inventory table
class Inventory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id).unique()();
  IntColumn get openingStock => integer().withDefault(const Constant(0))();
  IntColumn get currentStock => integer().withDefault(const Constant(0))();
  IntColumn get reservedStock => integer().withDefault(const Constant(0))();
  IntColumn get damagedStock => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAdjustedAt => dateTime().nullable()();
  TextColumn get lastAdjustmentReason => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Inventory Transactions table
class InventoryTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get transactionType => text()();
  // type: production | sale | adjustment | return | damage | opening
  IntColumn get quantity => integer()();
  IntColumn get balanceAfter => integer()();
  TextColumn get referenceType => text().nullable()();
  // referenceType: order | production | adjustment
  IntColumn get referenceId => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Expenses table
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()();
  // category: flour | oil | gas | electricity | salary | transport | packaging | maintenance | miscellaneous
  TextColumn get description => text()();
  RealColumn get amount => real()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get receiptPath => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get vendorName => text().nullable()();
  DateTimeColumn get expenseDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Users table (for multi-user future support)
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get role => text().withDefault(const Constant('staff'))();
  // role: owner | manager | staff | delivery
  TextColumn get phone => text().nullable()();
  TextColumn get pinHash => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get biometricEnabled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastLogin => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// App Settings table
class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
  TextColumn get type => text().withDefault(const Constant('string'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get activeVerticalsJson => text().nullable().withDefault(const Constant('["frozen"]'))();
  TextColumn get primaryVertical => text().nullable().withDefault(const Constant('frozen'))();
}

/// Notifications table
class AppNotifications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get type => text()();
  // type: low_stock | payment | production | backup | general
  TextColumn get data => text().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Backup History table
class BackupHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fileName => text()();
  TextColumn get filePath => text()();
  RealColumn get fileSizeKb => real()();
  TextColumn get status => text().withDefault(const Constant('success'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get backupDate => dateTime().withDefault(currentDateAndTime)();
}

/// Activity Logs table
class ActivityLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get action => text()();
  TextColumn get entityType => text().nullable()();
  IntColumn get entityId => integer().nullable()();
  TextColumn get details => text().nullable()();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Sync Queue table for offline-first resilient mutations and retries
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get action => text()(); // insert | update | delete
  TextColumn get entityType => text()(); // order | customer | payment | production
  TextColumn get payload => text()(); // JSON payload
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending | failed | completed
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Raw Materials table for BOM and factory stock tracking
class RawMaterials extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get category => text()(); // flour | oil | salt | packaging | additive
  RealColumn get currentStock => real().withDefault(const Constant(0.0))();
  TextColumn get unit => text().withDefault(const Constant('kg'))(); // kg | L | pcs
  RealColumn get minStock => real().withDefault(const Constant(50.0))();
  RealColumn get lastPurchasePrice => real().withDefault(const Constant(0.0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Hygiene & Food Safety compliance inspection logs (FSSAI Schedule 4)
class HygieneLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get inspectionDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get inspectorName => text()();
  RealColumn get doughChillingTemp => real()(); // Target: 2.0 to 4.0 °C
  BoolColumn get surfacesSanitized => boolean().withDefault(const Constant(true))();
  BoolColumn get personalHygienePassed => boolean().withDefault(const Constant(true))();
  BoolColumn get pestActivityDetected => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('pass'))(); // pass | flag | fail
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Legal entities for multi-company & international holding/export operations
class Entities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get countryCode => text()();
  TextColumn get taxId => text()();
  TextColumn get currency => text()();
  TextColumn get address => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Overseas distributors with foreign credit limits and Incoterms
class Distributors extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get countryCode => text()();
  TextColumn get currency => text()();
  IntColumn get creditLimitMinor => integer().withDefault(const Constant(0))();
  IntColumn get creditDays => integer().withDefault(const Constant(30))();
  TextColumn get taxId => text().nullable()();
  TextColumn get incotermsDefault => text().withDefault(const Constant('FOB'))();
  TextColumn get paymentTerms => text().withDefault(const Constant('Net 30'))();
  TextColumn get contactJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// International export orders with multi-currency & Incoterms 2020
class ExportOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get orderNumber => text().unique()();
  IntColumn get entityId => integer().references(Entities, #id)();
  IntColumn get distributorId => integer().references(Distributors, #id)();
  TextColumn get destinationCountry => text()();
  TextColumn get currency => text()();
  RealColumn get fxRateToInr => real().withDefault(const Constant(1.0))();
  TextColumn get incoterm => text()(); // FOB | CIF | DDP | EXW | CFR
  TextColumn get portOfLoading => text()();
  TextColumn get portOfDischarge => text()();
  TextColumn get status => text().withDefault(const Constant('draft'))(); // draft | confirmed | in_transit | cleared | delivered
  IntColumn get subtotalMinor => integer().withDefault(const Constant(0))();
  IntColumn get dutyMinor => integer().withDefault(const Constant(0))();
  IntColumn get freightMinor => integer().withDefault(const Constant(0))();
  IntColumn get insuranceMinor => integer().withDefault(const Constant(0))();
  IntColumn get totalMinor => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Itemized export line items tied to product SKU, batch, and HS code
class ExportLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exportOrderId => integer().references(ExportOrders, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get sku => text()();
  IntColumn get batchId => integer().nullable().references(ProductionBatches, #id)();
  TextColumn get hsCode => text()();
  RealColumn get quantityUnits => real()();
  TextColumn get unitType => text().withDefault(const Constant('cartons'))();
  IntColumn get unitPriceMinor => integer()();
  IntColumn get lineTotalMinor => integer()();
}

/// Ocean and air container freight shipments with reefer temperature monitoring
class ExportShipments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exportOrderId => integer().references(ExportOrders, #id)();
  TextColumn get containerNo => text()();
  TextColumn get sealNo => text()();
  TextColumn get blNumber => text().nullable()();
  TextColumn get vesselName => text().nullable()();
  TextColumn get voyageNo => text().nullable()();
  DateTimeColumn get eta => dateTime().nullable()();
  DateTimeColumn get etd => dateTime().nullable()();
  RealColumn get temperatureCelsiusTarget => real().withDefault(const Constant(-18.0))();
  TextColumn get temperatureLoggerId => text().nullable()();
}

/// Export destination food regulatory authority compliance profiles
class ComplianceProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get countryCode => text()();
  TextColumn get authority => text()(); // FDA | GSO_HALAL | CFIA | FSANZ | FSSAI
  TextColumn get rulesJson => text()();
  TextColumn get labelTemplateId => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Foreign exchange rates cache and contract overrides
class FxRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get baseCurrency => text()();
  TextColumn get targetCurrency => text()();
  RealColumn get rate => real()();
  DateTimeColumn get asOfDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get source => text().withDefault(const Constant('manual'))();
}

/// Harmonized System (HS) customs tariff classifications
class HsCodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().unique()();
  TextColumn get description => text()();
  TextColumn get chapter => text()();
  TextColumn get heading => text()();
  TextColumn get dutyRatesJson => text()();
}

/// Customer-specific contract price lists with validity dates
class CustomerPriceLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get customPriceMinor => integer()();
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();
  DateTimeColumn get effectiveFrom => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get effectiveTo => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Credit notes issued for damages, returns, price corrections
class CreditNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get noteNumber => text().unique()();
  IntColumn get originalInvoiceId => integer().references(Invoices, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  TextColumn get reasonCode => text()(); // damage | expiry | price_diff | short_supply | cheque_bounce
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();
  IntColumn get gstReversalMinor => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('issued'))(); // draft | issued | settled
  DateTimeColumn get issuedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get settledAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get linkedPaymentId => integer().nullable().references(Payments, #id)();
}

/// Debit notes issued for undercharges, demurrage, price revisions
class DebitNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get noteNumber => text().unique()();
  IntColumn get originalInvoiceId => integer().nullable().references(Invoices, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  TextColumn get reasonCode => text()(); // undercharge | additional_charge | late_fee
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();
  IntColumn get gstAmountMinor => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('issued'))(); // draft | issued | settled
  DateTimeColumn get issuedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get settledAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get linkedPaymentId => integer().nullable().references(Payments, #id)();
}

/// Recurring standing orders (hotel subscriptions) with auto-invoicing
class StandingOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  TextColumn get recurringDaysJson => text().withDefault(const Constant('[1,2,3,4,5,6,7]'))();
  TextColumn get defaultBasketJson => text()(); // [{"productId": 1, "quantity": 50}, ...]
  BoolColumn get autoInvoiceOnDelivery => boolean().withDefault(const Constant(true))();
  DateTimeColumn get activeFrom => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get activeTo => dateTime().nullable()();
  DateTimeColumn get lastGeneratedAt => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

/// Machine telemetry and maintenance logs for predictive maintenance
class MachineEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get machineId => text()(); // MIXER-01 | PRESS-01 | FREEZER-01
  TextColumn get machineName => text()();
  TextColumn get eventType => text()(); // maintenance | breakdown | cleaning | inspection | vibration_check
  TextColumn get severity => text().withDefault(const Constant('info'))(); // info | warning | critical
  RealColumn get vibrationMmS => real().nullable()();
  RealColumn get temperatureCelsius => real().nullable()();
  RealColumn get hoursRun => real().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Production and cold-chain wastage logs
class WastageLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get batchId => integer().nullable().references(ProductionBatches, #id)();
  IntColumn get productId => integer().nullable().references(Products, #id)();
  TextColumn get stage => text()(); // dough_mixing | pressing | baking | packing | cold_storage
  TextColumn get reason => text()(); // burnt | torn | undercooked | overcooked | contaminated | expired
  RealColumn get wastageKg => real()();
  IntColumn get costEstimatedMinor => integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();
  TextColumn get loggedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Delivery and quality customer return logs
class ReturnLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().nullable().references(Orders, #id)();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get quantity => integer()();
  TextColumn get reason => text()(); // spoiled | damaged_transit | packaging_defect | refused
  TextColumn get condition => text().withDefault(const Constant('discard'))(); // discard | salvage | restock
  TextColumn get actionTaken => text().withDefault(const Constant('credit_note'))();
  DateTimeColumn get reportedDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get resolvedDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
}

/// Customer complaints and support tickets
class Complaints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ticketNumber => text().unique()();
  IntColumn get customerId => integer().references(Customers, #id)();
  IntColumn get orderId => integer().nullable().references(Orders, #id)();
  IntColumn get productId => integer().nullable().references(Products, #id)();
  TextColumn get batchNumber => text().nullable()();
  TextColumn get category => text()(); // quality | delivery_delay | billing | driver_behavior | packaging
  TextColumn get severity => text().withDefault(const Constant('medium'))(); // low | medium | high | critical
  TextColumn get status => text().withDefault(const Constant('open'))(); // open | investigating | resolved | closed
  TextColumn get description => text()();
  TextColumn get resolutionNotes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
}

/// Dairy milk procurements from farmers and chilling centers
class MilkProcurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get supplierId => text()();
  DateTimeColumn get procurementDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get slot => text().withDefault(const Constant('morning'))(); // morning | evening
  RealColumn get quantityLiters => real()();
  RealColumn get fatPercent => real()();
  RealColumn get snfPercent => real()();
  IntColumn get ratePerLiterMinor => integer()();
  IntColumn get totalAmountMinor => integer()();
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();
  TextColumn get chillingCenterId => text().nullable()();
  IntColumn get batchId => integer().nullable().references(ProductionBatches, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Fat-based milk pricing rules
class FatPricingRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get baseRatePerLiterMinor => integer()();
  RealColumn get baseFatPercent => real()();
  RealColumn get fatSlabStep => real().withDefault(const Constant(0.1))();
  IntColumn get priceStepPerLiterMinor => integer().withDefault(const Constant(30))();
  DateTimeColumn get effectiveFrom => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get effectiveTo => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
