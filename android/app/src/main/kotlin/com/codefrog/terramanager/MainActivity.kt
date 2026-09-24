package com.codefrog.terramanager

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.codefrog.terramanager/browser",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openExternalUrl") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val raw = call.argument<String>("url")
            val uri = raw?.let(Uri::parse)
            if (uri == null ||
                uri.scheme != "https" ||
                uri.host.isNullOrBlank() ||
                !uri.path.isNullOrEmpty() && uri.path != "/" ||
                !uri.query.isNullOrEmpty() ||
                !uri.fragment.isNullOrEmpty() ||
                !uri.userInfo.isNullOrEmpty()
            ) {
                result.error("invalid_url", "An HTTPS server origin is required.", null)
                return@setMethodCallHandler
            }
            try {
                val intent = Intent(Intent.ACTION_VIEW, uri)
                    .addCategory(Intent.CATEGORY_BROWSABLE)
                startActivity(intent)
                result.success(null)
            } catch (_: ActivityNotFoundException) {
                result.error("no_browser", "No browser can open the URL.", null)
            }
        }
    }
}
