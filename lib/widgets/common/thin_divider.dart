import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

class ThinDivider extends StatelessWidget {
  const ThinDivider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 65, endIndent: 14, color: AppPalette.line);
}
