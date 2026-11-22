import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  /// Strings for the current locale (Arabic in the app, English in most
  /// widget tests).
  AppLocalizations get l10n => AppLocalizations.of(this);
}
