import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'SR Foods'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Smart Food Manufacturing & Export ERP'**
  String get tagline;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @production.
  ///
  /// In en, this message translates to:
  /// **'Production'**
  String get production;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @billing.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billing;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @aiAdvisor.
  ///
  /// In en, this message translates to:
  /// **'AI Advisor'**
  String get aiAdvisor;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @rawMaterials.
  ///
  /// In en, this message translates to:
  /// **'Raw Materials'**
  String get rawMaterials;

  /// No description provided for @hygieneCompliance.
  ///
  /// In en, this message translates to:
  /// **'Hygiene Compliance'**
  String get hygieneCompliance;

  /// No description provided for @driverRoute.
  ///
  /// In en, this message translates to:
  /// **'Driver Delivery Route'**
  String get driverRoute;

  /// No description provided for @distributors.
  ///
  /// In en, this message translates to:
  /// **'Distributors'**
  String get distributors;

  /// No description provided for @compliance.
  ///
  /// In en, this message translates to:
  /// **'Compliance'**
  String get compliance;

  /// No description provided for @createOrder.
  ///
  /// In en, this message translates to:
  /// **'Create Order'**
  String get createOrder;

  /// No description provided for @startBatch.
  ///
  /// In en, this message translates to:
  /// **'Start Production Batch'**
  String get startBatch;

  /// No description provided for @quantumAnneal.
  ///
  /// In en, this message translates to:
  /// **'Quantum Anneal Route'**
  String get quantumAnneal;

  /// No description provided for @quantumScheduler.
  ///
  /// In en, this message translates to:
  /// **'Quantum Multi-Machine Scheduler'**
  String get quantumScheduler;

  /// No description provided for @exportOrders.
  ///
  /// In en, this message translates to:
  /// **'Export Orders'**
  String get exportOrders;

  /// No description provided for @nutritionFacts.
  ///
  /// In en, this message translates to:
  /// **'Nutrition Facts'**
  String get nutritionFacts;

  /// No description provided for @fssaiLicense.
  ///
  /// In en, this message translates to:
  /// **'FSSAI License'**
  String get fssaiLicense;

  /// No description provided for @fdaRegistration.
  ///
  /// In en, this message translates to:
  /// **'FDA Facility Registration'**
  String get fdaRegistration;

  /// No description provided for @halalCertification.
  ///
  /// In en, this message translates to:
  /// **'GSO Halal Compliance'**
  String get halalCertification;

  /// No description provided for @cfiaCompliance.
  ///
  /// In en, this message translates to:
  /// **'CFIA SFCR Compliance'**
  String get cfiaCompliance;

  /// No description provided for @fsanzCompliance.
  ///
  /// In en, this message translates to:
  /// **'FSANZ Food Standards'**
  String get fsanzCompliance;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @unitSystem.
  ///
  /// In en, this message translates to:
  /// **'Unit System'**
  String get unitSystem;

  /// No description provided for @metric.
  ///
  /// In en, this message translates to:
  /// **'Metric (kg, L, °C)'**
  String get metric;

  /// No description provided for @imperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial (lb, gal, °F)'**
  String get imperial;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get timezone;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @inTransit.
  ///
  /// In en, this message translates to:
  /// **'In Transit'**
  String get inTransit;

  /// No description provided for @booked.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get booked;

  /// No description provided for @customs.
  ///
  /// In en, this message translates to:
  /// **'Customs Cleared'**
  String get customs;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax / Duty'**
  String get tax;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @grandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand Total'**
  String get grandTotal;

  /// No description provided for @amountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount Paid'**
  String get amountPaid;

  /// No description provided for @balanceDue.
  ///
  /// In en, this message translates to:
  /// **'Balance Due'**
  String get balanceDue;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @upi.
  ///
  /// In en, this message translates to:
  /// **'UPI / QR'**
  String get upi;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer / Wire (TT)'**
  String get bankTransfer;

  /// No description provided for @credit.
  ///
  /// In en, this message translates to:
  /// **'Credit (Net Terms)'**
  String get credit;

  /// No description provided for @letterOfCredit.
  ///
  /// In en, this message translates to:
  /// **'Letter of Credit (LC)'**
  String get letterOfCredit;

  /// No description provided for @kg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get kg;

  /// No description provided for @grams.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get grams;

  /// No description provided for @lbs.
  ///
  /// In en, this message translates to:
  /// **'lbs'**
  String get lbs;

  /// No description provided for @oz.
  ///
  /// In en, this message translates to:
  /// **'oz'**
  String get oz;

  /// No description provided for @liters.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get liters;

  /// No description provided for @ml.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get ml;

  /// No description provided for @gallons.
  ///
  /// In en, this message translates to:
  /// **'gal'**
  String get gallons;

  /// No description provided for @packs.
  ///
  /// In en, this message translates to:
  /// **'packs'**
  String get packs;

  /// No description provided for @pieces.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get pieces;

  /// No description provided for @cartons.
  ///
  /// In en, this message translates to:
  /// **'cartons'**
  String get cartons;

  /// No description provided for @parota.
  ///
  /// In en, this message translates to:
  /// **'Half Boiled Parota'**
  String get parota;

  /// No description provided for @chapathi.
  ///
  /// In en, this message translates to:
  /// **'Triangular Chapathi'**
  String get chapathi;

  /// No description provided for @pulka.
  ///
  /// In en, this message translates to:
  /// **'Pulka'**
  String get pulka;

  /// No description provided for @puri.
  ///
  /// In en, this message translates to:
  /// **'Puri'**
  String get puri;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @stockLevel.
  ///
  /// In en, this message translates to:
  /// **'Stock Level'**
  String get stockLevel;

  /// No description provided for @criticalLow.
  ///
  /// In en, this message translates to:
  /// **'Critical Low Stock'**
  String get criticalLow;

  /// No description provided for @fresh.
  ///
  /// In en, this message translates to:
  /// **'Fresh Batch'**
  String get fresh;

  /// No description provided for @expiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring Soon'**
  String get expiringSoon;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired Batch'**
  String get expired;

  /// No description provided for @landedCost.
  ///
  /// In en, this message translates to:
  /// **'Landed Cost'**
  String get landedCost;

  /// No description provided for @fobPrice.
  ///
  /// In en, this message translates to:
  /// **'FOB Value'**
  String get fobPrice;

  /// No description provided for @freight.
  ///
  /// In en, this message translates to:
  /// **'Freight & Insurance'**
  String get freight;

  /// No description provided for @duty.
  ///
  /// In en, this message translates to:
  /// **'Customs Duty'**
  String get duty;

  /// No description provided for @vatGst.
  ///
  /// In en, this message translates to:
  /// **'Destination VAT/GST'**
  String get vatGst;

  /// No description provided for @offlineReady.
  ///
  /// In en, this message translates to:
  /// **'Offline Ready — 100% Local'**
  String get offlineReady;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'es', 'fr', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
