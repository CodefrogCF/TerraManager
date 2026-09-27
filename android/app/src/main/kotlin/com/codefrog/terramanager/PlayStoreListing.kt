package com.codefrog.terramanager

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri

/** Opens a fixed public listing only after the Settings action is tapped. */
object PlayStoreListing {
    const val APPLICATION_ID = "com.codefrog.terramanager"
    const val WEB_URL = "https://play.google.com/store/apps/details?id=$APPLICATION_ID"

    fun open(context: Context): Boolean {
        val store = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$APPLICATION_ID"))
            .setPackage("com.android.vending")
        if (tryOpen(context, store)) return true

        val browser = Intent(Intent.ACTION_VIEW, Uri.parse(WEB_URL))
            .addCategory(Intent.CATEGORY_BROWSABLE)
        return tryOpen(context, browser)
    }

    private fun tryOpen(context: Context, intent: Intent): Boolean =
        try {
            context.startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
}
