import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../ui/tokens.dart';

/// Always-visible "© OpenStreetMap contributors" credit, as required by the
/// OSM tile usage policy. Tapping opens the copyright page.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  static final _copyright = Uri.parse('https://www.openstreetmap.org/copyright');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: 'Map data © OpenStreetMap contributors',
      child: GestureDetector(
        onTap: () => launchUrl(_copyright, mode: LaunchMode.externalApplication),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: StadiaColors.navy900.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              '© OpenStreetMap contributors',
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
