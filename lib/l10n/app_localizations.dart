import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Stadia'**
  String get appTitle;

  /// No description provided for @loadingStadium.
  ///
  /// In en, this message translates to:
  /// **'Loading the stadium'**
  String get loadingStadium;

  /// No description provided for @preparingSeats.
  ///
  /// In en, this message translates to:
  /// **'Preparing stands, blocks and seats'**
  String get preparingSeats;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Stadium capacity. formatted is count with digit grouping.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 seat} other{{formatted} seats}}'**
  String seatCount(int count, String formatted);

  /// No description provided for @backToStadium.
  ///
  /// In en, this message translates to:
  /// **'Back to the stadium'**
  String get backToStadium;

  /// No description provided for @osmCredit.
  ///
  /// In en, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get osmCredit;

  /// No description provided for @osmCreditSemantics.
  ///
  /// In en, this message translates to:
  /// **'Map data © OpenStreetMap contributors'**
  String get osmCreditSemantics;

  /// No description provided for @upcomingMatches.
  ///
  /// In en, this message translates to:
  /// **'Upcoming matches'**
  String get upcomingMatches;

  /// No description provided for @priceFrom.
  ///
  /// In en, this message translates to:
  /// **'from'**
  String get priceFrom;

  /// No description provided for @chooseSeats.
  ///
  /// In en, this message translates to:
  /// **'Choose seats'**
  String get chooseSeats;

  /// No description provided for @matchTitle.
  ///
  /// In en, this message translates to:
  /// **'{home} vs {away}'**
  String matchTitle(String home, String away);

  /// No description provided for @stepStand.
  ///
  /// In en, this message translates to:
  /// **'Stand'**
  String get stepStand;

  /// No description provided for @stepBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get stepBlock;

  /// No description provided for @stepSeat.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get stepSeat;

  /// No description provided for @stepBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get stepBuy;

  /// No description provided for @stepProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}: {label}'**
  String stepProgress(int current, int total, String label);

  /// No description provided for @backToStep.
  ///
  /// In en, this message translates to:
  /// **'Back to {label}'**
  String backToStep(String label);

  /// No description provided for @standSoldOut.
  ///
  /// In en, this message translates to:
  /// **'This stand is sold out'**
  String get standSoldOut;

  /// No description provided for @blockSoldOut.
  ///
  /// In en, this message translates to:
  /// **'This block is sold out, try another'**
  String get blockSoldOut;

  /// No description provided for @seatTakenNotice.
  ///
  /// In en, this message translates to:
  /// **'That seat is taken, pick a free one'**
  String get seatTakenNotice;

  /// No description provided for @tapStandHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a stand to zoom in'**
  String get tapStandHint;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @backToMatches.
  ///
  /// In en, this message translates to:
  /// **'Back to matches'**
  String get backToMatches;

  /// No description provided for @legendFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get legendFree;

  /// No description provided for @legendFewLeft.
  ///
  /// In en, this message translates to:
  /// **'Few left'**
  String get legendFewLeft;

  /// No description provided for @legendSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get legendSold;

  /// No description provided for @levelStand.
  ///
  /// In en, this message translates to:
  /// **'Stand'**
  String get levelStand;

  /// No description provided for @levelBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get levelBlock;

  /// No description provided for @levelYourSeat.
  ///
  /// In en, this message translates to:
  /// **'Your seat'**
  String get levelYourSeat;

  /// No description provided for @soldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get soldOut;

  /// No description provided for @freeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} free'**
  String freeCount(String count);

  /// No description provided for @rowSeat.
  ///
  /// In en, this message translates to:
  /// **'Row {row} · Seat {seat}'**
  String rowSeat(int row, int seat);

  /// No description provided for @blockNumber.
  ///
  /// In en, this message translates to:
  /// **'Block {number}'**
  String blockNumber(int number);

  /// No description provided for @tierLower.
  ///
  /// In en, this message translates to:
  /// **'Lower tier'**
  String get tierLower;

  /// No description provided for @tierUpper.
  ///
  /// In en, this message translates to:
  /// **'Upper tier'**
  String get tierUpper;

  /// No description provided for @perTicket.
  ///
  /// In en, this message translates to:
  /// **'per ticket'**
  String get perTicket;

  /// No description provided for @inclVip.
  ///
  /// In en, this message translates to:
  /// **'incl. VIP'**
  String get inclVip;

  /// No description provided for @labelStand.
  ///
  /// In en, this message translates to:
  /// **'Stand'**
  String get labelStand;

  /// No description provided for @labelBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get labelBlock;

  /// No description provided for @labelRow.
  ///
  /// In en, this message translates to:
  /// **'Row'**
  String get labelRow;

  /// No description provided for @labelSeat.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get labelSeat;

  /// No description provided for @labelGate.
  ///
  /// In en, this message translates to:
  /// **'Gate'**
  String get labelGate;

  /// No description provided for @labelPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get labelPaid;

  /// No description provided for @vipUpgrade.
  ///
  /// In en, this message translates to:
  /// **'VIP upgrade'**
  String get vipUpgrade;

  /// No description provided for @vipPerks.
  ///
  /// In en, this message translates to:
  /// **'Lounge access · Gate E fast lane'**
  String get vipPerks;

  /// No description provided for @anotherSeat.
  ///
  /// In en, this message translates to:
  /// **'Another seat'**
  String get anotherSeat;

  /// No description provided for @buyTicket.
  ///
  /// In en, this message translates to:
  /// **'Buy ticket'**
  String get buyTicket;

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutTitle;

  /// No description provided for @testMode.
  ///
  /// In en, this message translates to:
  /// **'Test mode · no card is charged'**
  String get testMode;

  /// No description provided for @backToSeat.
  ///
  /// In en, this message translates to:
  /// **'Back to seat'**
  String get backToSeat;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @payWith.
  ///
  /// In en, this message translates to:
  /// **'Pay with'**
  String get payWith;

  /// No description provided for @payAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payAmount(String amount);

  /// No description provided for @seatJustTaken.
  ///
  /// In en, this message translates to:
  /// **'That seat was just taken'**
  String get seatJustTaken;

  /// No description provided for @seatTakenBody.
  ///
  /// In en, this message translates to:
  /// **'Someone booked it a moment before you. {money}'**
  String seatTakenBody(String money);

  /// No description provided for @nothingCharged.
  ///
  /// In en, this message translates to:
  /// **'Nothing was charged.'**
  String get nothingCharged;

  /// No description provided for @willBeRefunded.
  ///
  /// In en, this message translates to:
  /// **'Payment {reference} will be refunded.'**
  String willBeRefunded(String reference);

  /// No description provided for @pickAnotherSeat.
  ///
  /// In en, this message translates to:
  /// **'Pick another seat'**
  String get pickAnotherSeat;

  /// No description provided for @viewFromSeat.
  ///
  /// In en, this message translates to:
  /// **'View from your seat'**
  String get viewFromSeat;

  /// No description provided for @dragToLookAround.
  ///
  /// In en, this message translates to:
  /// **'Drag to look around'**
  String get dragToLookAround;

  /// No description provided for @paymentCib.
  ///
  /// In en, this message translates to:
  /// **'CIB'**
  String get paymentCib;

  /// No description provided for @paymentCibCaption.
  ///
  /// In en, this message translates to:
  /// **'Interbank card'**
  String get paymentCibCaption;

  /// No description provided for @paymentEdahabia.
  ///
  /// In en, this message translates to:
  /// **'Edahabia'**
  String get paymentEdahabia;

  /// No description provided for @paymentEdahabiaCaption.
  ///
  /// In en, this message translates to:
  /// **'Algérie Poste'**
  String get paymentEdahabiaCaption;

  /// No description provided for @errorSeatGone.
  ///
  /// In en, this message translates to:
  /// **'This seat does not exist any more.'**
  String get errorSeatGone;

  /// No description provided for @errorPayment.
  ///
  /// In en, this message translates to:
  /// **'The payment did not go through. Nothing was charged.'**
  String get errorPayment;

  /// No description provided for @youreIn.
  ///
  /// In en, this message translates to:
  /// **'You\'re in'**
  String get youreIn;

  /// No description provided for @paidRef.
  ///
  /// In en, this message translates to:
  /// **'Paid {amount} · Ref {reference}'**
  String paidRef(String amount, String reference);

  /// No description provided for @backToMap.
  ///
  /// In en, this message translates to:
  /// **'Back to the map'**
  String get backToMap;

  /// No description provided for @gatesOpenAt.
  ///
  /// In en, this message translates to:
  /// **'Gates open at {time}'**
  String gatesOpenAt(String time);

  /// No description provided for @gatesLead.
  ///
  /// In en, this message translates to:
  /// **'That\'s {lead} before kick-off. {where}'**
  String gatesLead(String lead, String where);

  /// No description provided for @leadHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h'**
  String leadHours(int count);

  /// No description provided for @leadMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String leadMinutes(int count);

  /// No description provided for @useGateVip.
  ///
  /// In en, this message translates to:
  /// **'Use Gate {gate}, the VIP fast lane. The lounge opens with the gates.'**
  String useGateVip(String gate);

  /// No description provided for @useGateStand.
  ///
  /// In en, this message translates to:
  /// **'Use Gate {gate}, the entrance for the {stand}.'**
  String useGateStand(String gate, String stand);

  /// No description provided for @ticketNotFound.
  ///
  /// In en, this message translates to:
  /// **'Ticket not found'**
  String get ticketNotFound;

  /// No description provided for @ticketNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'Tickets are kept on this device for the session. Book again from the map.'**
  String get ticketNotFoundBody;

  /// No description provided for @scanAt.
  ///
  /// In en, this message translates to:
  /// **'Scan at {gate}'**
  String scanAt(String gate);

  /// No description provided for @ticketSemantics.
  ///
  /// In en, this message translates to:
  /// **'Ticket {id}'**
  String ticketSemantics(String id);

  /// No description provided for @entryQr.
  ///
  /// In en, this message translates to:
  /// **'Entry QR code'**
  String get entryQr;

  /// No description provided for @matchdayAt.
  ///
  /// In en, this message translates to:
  /// **'Matchday at'**
  String get matchdayAt;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Block depth, shown instead of the tier in a single-tier stadium.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}}'**
  String rowCount(int count);

  /// No description provided for @pickTeamOverline.
  ///
  /// In en, this message translates to:
  /// **'Before the stadium'**
  String get pickTeamOverline;

  /// No description provided for @pickTeamTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick your team'**
  String get pickTeamTitle;

  /// No description provided for @pickTeamBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll take you to its stadium and put its matches first.'**
  String get pickTeamBody;

  /// No description provided for @pickTeamFirst.
  ///
  /// In en, this message translates to:
  /// **'Pick a team to continue'**
  String get pickTeamFirst;

  /// No description provided for @goToStadium.
  ///
  /// In en, this message translates to:
  /// **'Go to the stadium'**
  String get goToStadium;

  /// No description provided for @nextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get nextMatch;

  /// No description provided for @noMatchYet.
  ///
  /// In en, this message translates to:
  /// **'No match on sale yet'**
  String get noMatchYet;

  /// No description provided for @yourTeam.
  ///
  /// In en, this message translates to:
  /// **'Your team'**
  String get yourTeam;

  /// No description provided for @changeTeam.
  ///
  /// In en, this message translates to:
  /// **'Change team'**
  String get changeTeam;

  /// No description provided for @stadiumsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stadiums'**
  String get stadiumsTitle;

  /// No description provided for @changeStadium.
  ///
  /// In en, this message translates to:
  /// **'Change stadium'**
  String get changeStadium;

  /// No description provided for @youAreHere.
  ///
  /// In en, this message translates to:
  /// **'You\'re here'**
  String get youAreHere;
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
      <String>['ar', 'en'].contains(locale.languageCode);

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
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
