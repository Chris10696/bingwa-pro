package com.example.bingwa_pro

import android.Manifest
import android.content.ContentProviderOperation
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.ContactsContract
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * W4-batch-4 — Auto-Save Contacts (Hybrid SaveContactToPhoneBookUseCase parity).
 *
 * On a successful sale, when the agent has enabled Auto-Save Contacts, write the paying
 * customer into the phone's address book as "<name> Nexus" (D-W4-3 — updated from Hybrid's
 * literal " Bingwa" to avoid the Bingwa brand in saved contacts on release).
 *
 * Best-effort + idempotent: no-ops when the toggle is off, WRITE_CONTACTS is not granted,
 * the phone is blank, or a contact with that number already exists (dedup via PhoneLookup —
 * the on-device equivalent of Hybrid's CustomerAlreadySavedInPhoneBookException guard).
 */
object ContactSaver {
    private const val TAG = "ContactSaver"
    private const val SUFFIX = " Nexus"

    fun saveIfEnabled(context: Context, phone: String, name: String?) {
        if (!SessionBridge.getAutoSaveContacts(context)) return
        val number = phone.trim()
        if (number.isEmpty()) return
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_CONTACTS)
            != PackageManager.PERMISSION_GRANTED) {
            Log.d(TAG, "WRITE_CONTACTS not granted — skipping auto-save for $number")
            return
        }
        try {
            if (contactExists(context, number)) {
                Log.d(TAG, "Contact already exists for $number — skipping")
                return
            }
            val displayName =
                (name?.trim()?.takeIf { it.isNotEmpty() } ?: number) + SUFFIX
            val ops = arrayListOf<ContentProviderOperation>()
            val rawIndex = ops.size
            ops.add(
                ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
                    .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, null)
                    .withValue(ContactsContract.RawContacts.ACCOUNT_NAME, null)
                    .build(),
            )
            ops.add(
                ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                    .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, rawIndex)
                    .withValue(
                        ContactsContract.Data.MIMETYPE,
                        ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE,
                    )
                    .withValue(
                        ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME,
                        displayName,
                    )
                    .build(),
            )
            ops.add(
                ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                    .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, rawIndex)
                    .withValue(
                        ContactsContract.Data.MIMETYPE,
                        ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE,
                    )
                    .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, number)
                    .withValue(
                        ContactsContract.CommonDataKinds.Phone.TYPE,
                        ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE,
                    )
                    .build(),
            )
            context.contentResolver.applyBatch(ContactsContract.AUTHORITY, ops)
            Log.d(TAG, "Saved contact '$displayName' ($number)")
        } catch (e: Exception) {
            Log.e(TAG, "Auto-save contact failed for $number: ${e.message}", e)
        }
    }

    /** True if any contact already has this number (PhoneLookup; needs READ_CONTACTS). */
    private fun contactExists(context: Context, number: String): Boolean {
        return try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(number),
            )
            context.contentResolver.query(
                uri,
                arrayOf(ContactsContract.PhoneLookup._ID),
                null,
                null,
                null,
            )?.use { it.moveToFirst() } ?: false
        } catch (e: Exception) {
            Log.w(TAG, "contactExists check failed: ${e.message}")
            false
        }
    }
}
