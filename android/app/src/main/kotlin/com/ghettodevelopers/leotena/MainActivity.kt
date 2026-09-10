package com.ghettodevelopers.leotena

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import android.webkit.WebView
import com.ghettodevelopers.leotena.player.PlaybackPreferences
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val NATIVE_PLAYER_REQUEST = 48291
    }

    private val nativePlayerChannel = "com.ghettodevelopers.leotena/native_player"
    private var nativeOpenResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        // Warm WebView engine so gateway failover starts faster.
        Handler(Looper.getMainLooper()).post {
            try {
                WebView(applicationContext).apply {
                    settings.javaScriptEnabled = true
                    loadUrl("about:blank")
                    destroy()
                }
            } catch (_: Exception) {
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == NATIVE_PLAYER_REQUEST) {
            completeNativeOpen()
        }
    }

    private fun completeNativeOpen() {
        val pending = nativeOpenResult ?: return
        nativeOpenResult = null
        try {
            pending.success(null)
        } catch (_: Exception) {
            // Already replied or engine torn down — never crash Flutter.
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, nativePlayerChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?>
                        if (args == null) {
                            result.error("bad_args", "Expected map", null)
                            return@setMethodCallHandler
                        }
                        // Only one native open at a time.
                        if (nativeOpenResult != null) {
                            result.error("busy", "Player already open", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val intent = Intent(this, OrizonPlayerActivity::class.java)
                            intent.putExtra("url", args["url"]?.toString().orEmpty())
                            intent.putExtra("licenseUrl", args["licenseUrl"]?.toString().orEmpty())
                            intent.putExtra("token", args["token"]?.toString().orEmpty())
                            intent.putExtra(
                                "drmType",
                                args["drmType"]?.toString().orEmpty().ifEmpty { "NONE" },
                            )
                            val mergedClearKey = sequenceOf(
                                args["clearKeyHex"]?.toString(),
                                args["drmClearKey"]?.toString(),
                                args["drm_clear_key"]?.toString(),
                            ).firstOrNull { !it.isNullOrBlank() }.orEmpty()
                            intent.putExtra("clearKeyHex", mergedClearKey)
                            intent.putExtra("headersJson", args["headersJson"]?.toString().orEmpty())
                            intent.putExtra(
                                "audioLanguage",
                                args["audioLanguage"]?.toString().orEmpty().ifEmpty { "sw" },
                            )
                            intent.putExtra(
                                "dataSaver",
                                args["dataSaver"] == true ||
                                    args["dataSaver"]?.toString()?.equals("true", ignoreCase = true) == true,
                            )
                            intent.putExtra(
                                "defaultQuality",
                                args["defaultQuality"]?.toString().orEmpty().ifEmpty { "480p" },
                            )
                            intent.putExtra(
                                "videoZoomMode",
                                args["videoZoomMode"]?.toString().orEmpty().ifEmpty { "contain" },
                            )
                            nativeOpenResult = result
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, NATIVE_PLAYER_REQUEST)
                        } catch (e: Exception) {
                            nativeOpenResult = null
                            result.error(
                                "native_open_failed",
                                e.message ?: "Failed to open player",
                                null,
                            )
                        }
                    }
                    "syncPlaybackPreferences" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?>
                        if (args == null) {
                            result.error("bad_args", "Expected map", null)
                            return@setMethodCallHandler
                        }
                        PlaybackPreferences.update(
                            dataSaver = args["dataSaver"] == true ||
                                args["dataSaver"]?.toString()?.equals("true", ignoreCase = true) == true,
                            defaultQuality = args["defaultQuality"]?.toString().orEmpty().ifEmpty { "480p" },
                            videoZoomMode = args["videoZoomMode"]?.toString().orEmpty().ifEmpty { "contain" },
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
