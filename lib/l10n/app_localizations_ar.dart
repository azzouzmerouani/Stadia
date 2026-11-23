// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'ستاديا';

  @override
  String get loadingStadium => 'جارٍ تحميل الملعب';

  @override
  String get preparingSeats => 'نجهّز المدرجات والأقسام والمقاعد';

  @override
  String get somethingWentWrong => 'حدث خطأ ما';

  @override
  String get tryAgain => 'أعد المحاولة';

  @override
  String seatCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted مقعد',
      many: '$formatted مقعدًا',
      few: '$formatted مقاعد',
      two: 'مقعدان',
      one: 'مقعد واحد',
      zero: 'لا مقاعد',
    );
    return '$_temp0';
  }

  @override
  String get backToStadium => 'العودة إلى الملعب';

  @override
  String get osmCredit => '© مساهمو OpenStreetMap';

  @override
  String get osmCreditSemantics => 'بيانات الخريطة © مساهمو OpenStreetMap';

  @override
  String get upcomingMatches => 'المباريات القادمة';

  @override
  String get priceFrom => 'ابتداءً من';

  @override
  String get chooseSeats => 'اختر مقعدك';

  @override
  String matchTitle(String home, String away) {
    return '$home ضد $away';
  }

  @override
  String get stepStand => 'المدرج';

  @override
  String get stepBlock => 'القسم';

  @override
  String get stepSeat => 'المقعد';

  @override
  String get stepBuy => 'الشراء';

  @override
  String stepProgress(int current, int total, String label) {
    return 'الخطوة $current من $total: $label';
  }

  @override
  String backToStep(String label) {
    return 'العودة إلى $label';
  }

  @override
  String get standSoldOut => 'نفدت تذاكر هذا المدرج';

  @override
  String get blockSoldOut => 'نفدت تذاكر هذا القسم، جرّب قسمًا آخر';

  @override
  String get seatTakenNotice => 'هذا المقعد محجوز، اختر مقعدًا شاغرًا';

  @override
  String get tapStandHint => 'اضغط على مدرج للاقتراب منه';

  @override
  String get back => 'رجوع';

  @override
  String get backToMatches => 'العودة إلى المباريات';

  @override
  String get legendFree => 'متاح';

  @override
  String get legendFewLeft => 'أماكن قليلة';

  @override
  String get legendSold => 'مباع';

  @override
  String get levelStand => 'المدرج';

  @override
  String get levelBlock => 'القسم';

  @override
  String get levelYourSeat => 'مقعدك';

  @override
  String get soldOut => 'نفدت التذاكر';

  @override
  String freeCount(String count) {
    return 'متاح: $count';
  }

  @override
  String rowSeat(int row, int seat) {
    return 'الصف $row · المقعد $seat';
  }

  @override
  String blockNumber(int number) {
    return 'القسم $number';
  }

  @override
  String get tierLower => 'الطابق السفلي';

  @override
  String get tierUpper => 'الطابق العلوي';

  @override
  String get perTicket => 'للتذكرة';

  @override
  String get inclVip => 'مع ترقية VIP';

  @override
  String get labelStand => 'المدرج';

  @override
  String get labelBlock => 'القسم';

  @override
  String get labelRow => 'الصف';

  @override
  String get labelSeat => 'المقعد';

  @override
  String get labelGate => 'الباب';

  @override
  String get labelPaid => 'المدفوع';

  @override
  String get vipUpgrade => 'ترقية VIP';

  @override
  String get vipPerks => 'دخول الصالة · مسار سريع عبر الباب E';

  @override
  String get anotherSeat => 'مقعد آخر';

  @override
  String get buyTicket => 'اشترِ التذكرة';

  @override
  String get checkoutTitle => 'الدفع';

  @override
  String get testMode => 'وضع تجريبي · لن يُخصم أي مبلغ';

  @override
  String get backToSeat => 'العودة إلى المقعد';

  @override
  String get total => 'المجموع';

  @override
  String get payWith => 'الدفع بواسطة';

  @override
  String payAmount(String amount) {
    return 'ادفع $amount';
  }

  @override
  String get seatJustTaken => 'حُجز هذا المقعد للتو';

  @override
  String seatTakenBody(String money) {
    return 'حجزه شخص آخر قبلك بلحظات. $money';
  }

  @override
  String get nothingCharged => 'لم يُخصم أي مبلغ.';

  @override
  String willBeRefunded(String reference) {
    return 'سيُسترجع المبلغ المدفوع (المرجع $reference).';
  }

  @override
  String get pickAnotherSeat => 'اختر مقعدًا آخر';

  @override
  String get viewFromSeat => 'المنظر من مقعدك';

  @override
  String get dragToLookAround => 'اسحب لتتلفّت حولك';

  @override
  String get paymentCib => 'CIB';

  @override
  String get paymentCibCaption => 'البطاقة البنكية';

  @override
  String get paymentEdahabia => 'الذهبية';

  @override
  String get paymentEdahabiaCaption => 'بريد الجزائر';

  @override
  String get errorSeatGone => 'هذا المقعد لم يعد موجودًا.';

  @override
  String get errorPayment => 'لم تتم عملية الدفع. لم يُخصم أي مبلغ.';

  @override
  String get youreIn => 'تذكرتك جاهزة';

  @override
  String paidRef(String amount, String reference) {
    return 'المدفوع $amount · المرجع $reference';
  }

  @override
  String get backToMap => 'العودة إلى الخريطة';

  @override
  String gatesOpenAt(String time) {
    return 'تُفتح الأبواب على الساعة $time';
  }

  @override
  String gatesLead(String lead, String where) {
    return 'أي قبل $lead من صافرة البداية. $where';
  }

  @override
  String leadHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعة',
      few: '$count ساعات',
      two: 'ساعتين',
      one: 'ساعة',
    );
    return '$_temp0';
  }

  @override
  String leadMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      few: '$count دقائق',
      two: 'دقيقتين',
      one: 'دقيقة',
    );
    return '$_temp0';
  }

  @override
  String useGateVip(String gate) {
    return 'ادخل من الباب $gate، المسار السريع لكبار الزوار. تُفتح الصالة مع فتح الأبواب.';
  }

  @override
  String useGateStand(String gate, String stand) {
    return 'ادخل من الباب $gate، وهو مدخل $stand.';
  }

  @override
  String get ticketNotFound => 'لم نعثر على التذكرة';

  @override
  String get ticketNotFoundBody =>
      'تُحفظ التذاكر على هذا الجهاز طوال الجلسة. احجز من جديد من الخريطة.';

  @override
  String scanAt(String gate) {
    return 'امسح الرمز عند $gate';
  }

  @override
  String ticketSemantics(String id) {
    return 'التذكرة $id';
  }

  @override
  String get entryQr => 'رمز QR للدخول';

  @override
  String get matchdayAt => 'يوم المباراة في';

  @override
  String get skip => 'تخطي';

  @override
  String rowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صف',
      many: '$count صفًا',
      few: '$count صفوف',
      two: 'صفان',
      one: 'صف واحد',
      zero: 'لا صفوف',
    );
    return '$_temp0';
  }

  @override
  String get pickTeamOverline => 'قبل الذهاب إلى الملعب';

  @override
  String get pickTeamTitle => 'اختر فريقك المفضل';

  @override
  String get pickTeamBody => 'سنأخذك إلى ملعبه ونضع مبارياته أولًا.';

  @override
  String get pickTeamFirst => 'اختر فريقًا للمتابعة';

  @override
  String get goToStadium => 'إلى الملعب';

  @override
  String get nextMatch => 'المباراة القادمة';

  @override
  String get noMatchYet => 'لا تذاكر معروضة بعد';

  @override
  String get yourTeam => 'فريقك';

  @override
  String get changeTeam => 'تغيير الفريق';

  @override
  String get stadiumsTitle => 'الملاعب';

  @override
  String get changeStadium => 'تغيير الملعب';

  @override
  String get youAreHere => 'أنت هنا';
}
