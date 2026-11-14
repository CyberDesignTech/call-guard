import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';

class RepeatFields extends StatelessWidget {
  const RepeatFields({
    required this.strings,
    required this.repeatType,
    required this.intervalController,
    required this.onRepeatTypeChanged,
  });

  final AppStrings strings;
  final String repeatType;
  final TextEditingController intervalController;
  final ValueChanged<String> onRepeatTypeChanged;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      RadioGroup<String>(
        groupValue: repeatType,
        onChanged: (value) {
          if (value != null) onRepeatTypeChanged(value);
        },
        child: Column(
          children: [
            RadioListTile<String>(
              value: 'none',
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(strings.call('repeatNone')),
            ),
            RadioListTile<String>(
              value: 'daily',
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(strings.call('repeatDaily')),
            ),
            RadioListTile<String>(
              value: 'weekly',
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(strings.call('repeatWeekly')),
            ),
            RadioListTile<String>(
              value: 'custom',
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(strings.call('repeatCustom')),
            ),
          ],
        ),
      ),
      if (repeatType == 'custom')
        Padding(
          padding: const EdgeInsets.only(left: 48, right: 8, bottom: 8),
          child: TextField(
            controller: intervalController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: strings.call('repeatIntervalLabel'),
              suffixText: strings.call('repeatDaysUnit'),
            ),
          ),
        ),
    ],
  );
}
