import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../platform/call_screening_channel.dart';

Future<ContactPickerResult?> pickContactFromPhoneBook({
  required BuildContext context,
  required AppStrings strings,
  required CallScreeningChannel channel,
}) async {
  try {
    var result = await channel.pickContact();
    if (result?.permissionRequired == true) {
      final permissions = await channel.requestContactsPermission();
      if (!permissions.readContacts) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(strings.call('contactPickerPermissionNeeded')),
              ),
            );
        }
        return null;
      }
      result = await channel.pickContact();
    }
    return result;
  } on PlatformException {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(strings.call('contactPickerError'))),
        );
    }
    return null;
  } on MissingPluginException {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(strings.call('contactPickerError'))),
        );
    }
    return null;
  }
}
