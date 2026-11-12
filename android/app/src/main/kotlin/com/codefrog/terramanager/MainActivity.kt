package com.codefrog.terramanager

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var feedingAlarmChannel: MethodChannel
    private var feedingAlarmChannelReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        feedingAlarmChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.codefrog.terramanager/feeding_alarms",
        )
        feedingAlarmChannelReady = false
        feedingAlarmChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "launchPayload" -> {
                        feedingAlarmChannelReady = true
                        result.success(takeFeedingAlarmPayload(intent))
                    }
                    "pendingIds" -> result.success(RestFeedingAlarms.pendingIds(this))
                    "schedule" -> {
                        RestFeedingAlarms.schedule(
                            this,
                            requireNotNull(call.argument<Int>("id")),
                            RestFeedingAlarm(
                                requireNotNull(call.argument<Number>("at")).toLong(),
                                requireNotNull(call.argument<Number>("pauseFrom")).toLong(),
                                requireNotNull(call.argument<Number>("pauseUntil")).toLong(),
                                requireNotNull(call.argument<String>("body")),
                                requireNotNull(call.argument<String>("payload")),
                            ),
                        )
                        result.success(null)
                    }
                    "cancel" -> {
                        RestFeedingAlarms.cancel(this, call.arguments as Int)
                        result.success(null)
                    }
                    "cancelAll" -> {
                        RestFeedingAlarms.cancelAll(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: RuntimeException) {
                result.error("feeding_alarm", error.message, null)
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.codefrog.terramanager/browser",
        ).setMethodCallHandler { call, result ->
            if (call.method == "deviceTimeZoneId") {
                result.success(java.util.TimeZone.getDefault().id)
                return@setMethodCallHandler
            }
            if (call.method == "openStoreListing") {
                if (PlayStoreListing.open(this)) {
                    result.success(null)
                } else {
                    result.error("no_store_or_browser", "No app can open the Play Store listing.", null)
                }
                return@setMethodCallHandler
            }
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

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action != RestFeedingAlarms.openAction) return
        if (feedingAlarmChannelReady) {
            takeFeedingAlarmPayload(intent)?.let {
                feedingAlarmChannel.invokeMethod("openAnimal", it)
            }
        } else {
            setIntent(intent)
        }
    }

    private fun takeFeedingAlarmPayload(intent: Intent): String? {
        if (intent.action != RestFeedingAlarms.openAction) return null
        val payload = intent.getStringExtra(RestFeedingAlarms.openPayload)
        intent.removeExtra(RestFeedingAlarms.openPayload)
        return payload
    }
}
