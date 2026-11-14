import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../database/app_database.dart';

class FssaiLicenseStatus {
  final String licenseNumber;
  final DateTime validTill;
  final int daysRemaining;
  final bool isExpiringSoon; // <= 30 days
  final bool isExpired;

  const FssaiLicenseStatus({
    required this.licenseNumber,
    required this.validTill,
    required this.daysRemaining,
    required this.isExpiringSoon,
    required this.isExpired,
  });
}

class FssaiHygieneService {
  FssaiHygieneService._();
  static final FssaiHygieneService instance = FssaiHygieneService._();

  /// Check FSSAI license validity and expiration status
  Future<FssaiLicenseStatus> checkLicenseStatus(AppDatabase db) async {
    final licSetting = await (db.select(db.appSettings)
          ..where((s) => s.key.equals('fssai_license_number')))
        .getSingleOrNull();
    final validTillSetting = await (db.select(db.appSettings)
          ..where((s) => s.key.equals('fssai_license_valid_till')))
        .getSingleOrNull();

    final licenseNumber = licSetting?.value ?? '10123999000123';
    DateTime validTill = DateTime.now().add(const Duration(days: 365));
    if (validTillSetting != null && validTillSetting.value.isNotEmpty) {
      try {
        validTill = DateTime.parse(validTillSetting.value);
      } catch (_) {}
    }

    final diff = validTill.difference(DateTime.now()).inDays;
    return FssaiLicenseStatus(
      licenseNumber: licenseNumber,
      validTill: validTill,
      daysRemaining: diff,
      isExpiringSoon: diff <= 30 && diff > 0,
      isExpired: diff <= 0,
    );
  }

  /// Generates Schedule 4 FSSAI Compliant Food Safety Inspection Monthly Audit PDF
  Future<Uint8List> generateMonthlyHygieneReportPdf({
    required AppDatabase db,
    required DateTime month,
  }) async {
    final pdf = pw.Document();
    final logs = await db.getRecentHygieneLogs(limit: 60);

    // Filter for chosen month
    final filteredLogs = logs.where((l) =>
        l.inspectionDate.year == month.year && l.inspectionDate.month == month.month).toList();

    final lic = await checkLicenseStatus(db);
    final monthStr = DateFormat('MMMM yyyy').format(month);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SR FOODS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange800)),
                    pw.Text('Ready-to-Cook Flatbreads & Parota Manufacturing', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('FSSAI Reg. No: ${lic.licenseNumber}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('License Valid Till: ${DateFormat('dd-MMM-yyyy').format(lic.validTill)}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('FSSAI SCHEDULE 4 COMPLIANCE', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                    pw.Text('Monthly Facility Hygiene Log', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    pw.Text('Month: $monthStr', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 8),

            pw.Text(
              'Daily Food Safety, Cold Chain, and Surface Sanitization Verification Logbook',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 10),

            // Table of records
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Inspector',
                'Dough Chilling (°C)',
                'Sanitized',
                'Hygiene',
                'Pest Check',
                'Status',
              ],
              data: filteredLogs.map((l) {
                return [
                  DateFormat('dd/MM/yyyy').format(l.inspectionDate),
                  l.inspectorName,
                  '${l.doughChillingTemp.toStringAsFixed(1)}°C',
                  l.surfacesSanitized ? 'PASS' : 'FAIL',
                  l.personalHygienePassed ? 'PASS' : 'FAIL',
                  l.pestActivityDetected ? 'FLAGGED' : 'CLEAR',
                  l.status.toUpperCase(),
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.center,
            ),

            pw.SizedBox(height: 25),

            // Sign-off
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Prepared by / Shift Supervisor:', style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 25),
                    pw.Text('_________________________', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Signature & Date', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Verified by FSSAI Food Safety In-Charge:', style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 25),
                    pw.Text('_________________________', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Authorized Stamp & Date', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
