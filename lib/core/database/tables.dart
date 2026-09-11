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
