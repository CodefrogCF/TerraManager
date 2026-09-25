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
            val uri = when (call.method) {
                "openExternalUrl" -> {
                    val raw = call.argument<String>("url")
                    val candidate = raw?.let(Uri::parse)
                    if (candidate == null ||
                        candidate.scheme != "https" ||
                        candidate.host.isNullOrBlank() ||
                        !candidate.path.isNullOrEmpty() && candidate.path != "/" ||
                        !candidate.query.isNullOrEmpty() ||
                        !candidate.fragment.isNullOrEmpty() ||
                        !candidate.userInfo.isNullOrEmpty()
                    ) {
                        result.error("invalid_url", "An HTTPS server origin is required.", null)
                        return@setMethodCallHandler
                    }
                    candidate
                }
                "openProjectPage" -> {
                    val url = when (call.argument<String>("page")) {
                        "website-de" -> "https://codefrogcf.github.io/TerraManager/"
                        "website-en" -> "https://codefrogcf.github.io/TerraManager/en/"
                        "guide-de" -> "https://codefrogcf.github.io/TerraManager/guide/"
                        "guide-en" -> "https://codefrogcf.github.io/TerraManager/guide/en/"
                        else -> null
                    }
                    if (url == null) {
                        result.error("invalid_page", "Unknown project page.", null)
                        return@setMethodCallHandler
                    }
                    Uri.parse(url)
                }
                else -> {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
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
