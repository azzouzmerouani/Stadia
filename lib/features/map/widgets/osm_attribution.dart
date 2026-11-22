import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/l10n.dart';
import '../../../ui/tokens.dart';

/// Always-visible "© OpenStreetMap contributors" credit, as required by the
/// OSM tile usage policy. Tapping opens the copyright page.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  static final _copyright = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      link: true,
      label: l10n.osmCreditSemantics,
      child: GestureDetector(
        onTap: () =>
            launchUrl(_copyright, mode: LaunchMode.externalApplication),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: StadiaColors.page.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(StadiaRadii.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              l10n.osmCredit,
              style: StadiaText.caption.copyWith(
                fontSize: 11,
                color: StadiaColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
