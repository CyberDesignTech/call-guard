import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import 'icon_box.dart';

class RuleSwitch extends StatelessWidget {
  const RuleSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconColor = AppPalette.blue,
    this.iconBackground,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color iconColor;
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
      secondary: IconBox(
        icon: icon,
        color: iconColor,
        background: iconBackground ?? AppPalette.bluePale,
        size: 39,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: AppPalette.ink,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppPalette.muted, fontSize: 11),
      ),
      activeTrackColor: AppPalette.green,
      dense: true,
    );
  }
}
