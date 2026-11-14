package com.wepr.callguard.call_guard

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.util.Log

/** Shared ContactsContract.PhoneLookup checks for call screening and the answering module. */
object ContactLookup {
    fun hasPermission(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            context.checkSelfPermission(Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * Returns true when the number belongs to a contact, false when it does not,
     * or null when the contacts provider could not be queried.
     */
    fun isContact(context: Context, lookupNumber: String): Boolean? {
        val lookupUri = Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
            Uri.encode(lookupNumber),
        )
        return runCatching {
            context.contentResolver.query(
                lookupUri,
                arrayOf(ContactsContract.PhoneLookup._ID),
                null,
                null,
                null,
            )?.use { it.moveToFirst() } ?: false
        }.onFailure { Log.w(TAG, "Could not query the local contacts provider", it) }
            .getOrNull()
    }

    /** Screening semantics: an unknown lookup result keeps the call allowed. */
    fun isInContacts(context: Context, lookupNumber: String): Boolean {
        if (lookupNumber.isBlank()) return false
        return isContact(context, lookupNumber) ?: true
    }

    /** Answering-module semantics: only a confirmed contact counts as known. */
    fun isUnknownNumber(context: Context, lookupNumber: String): Boolean =
        isContact(context, lookupNumber)?.not() ?: false

    private const val TAG = "CallGuardContactLookup"
}
