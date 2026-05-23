package com.example.flutter_find

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class FlutterFindPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private lateinit var scanner: FlutterAppScanner
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var scanJob: Job? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        scanner = FlutterAppScanner(context)
        channel = MethodChannel(binding.binaryMessenger, "com.example.flutter_find/scanner")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(
            binding.binaryMessenger,
            "com.example.flutter_find/scan_progress",
        )
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        scope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scanAll" -> {
                val excludeSystemApps = call.argument<Boolean>("excludeSystemApps") ?: false
                scanJob?.cancel()
                scanJob = scope.launch {
                    try {
                        val apps = scanner.scanAll(excludeSystemApps) { current, total ->
                            mainHandler.post {
                                eventSink?.success(mapOf("current" to current, "total" to total))
                            }
                        }
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("SCAN_ERROR", e.message, null)
                    }
                }
            }
            "analyzePackage" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName == null) {
                    result.error("INVALID_ARG", "packageName required", null)
                    return
                }
                scope.launch {
                    try {
                        val detail = scanner.analyzePackage(packageName)
                        if (detail == null) {
                            result.error("NOT_FOUND", "Not a Flutter app or not found", null)
                        } else {
                            result.success(detail)
                        }
                    } catch (e: Exception) {
                        result.error("ANALYZE_ERROR", e.message, null)
                    }
                }
            }
            "cancelScan" -> {
                scanner.cancel()
                scanJob?.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
