package com.example.flutter_find

import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.util.regex.Pattern
import java.util.zip.ZipFile

data class FlutterVersionInfo(
    val flutterVersion: String?,
    val dartVersion: String?,
    val engineHashes: List<String>,
)

object FlutterVersionExtractor {
    private val DART_VERSION_PATTERN = Pattern.compile(
        "([\\d.\\w-]+)\\s+\\((stable|beta|dev)\\)"
    )
    private val ENGINE_SHA_PATTERN = Pattern.compile("([a-f0-9]{40})")

    private var engineMap: Map<String, String>? = null

    fun loadEngineMap(context: android.content.Context) {
        if (engineMap != null) return
        try {
            context.assets.open("engine_release_map.json").use { stream ->
                val json = JSONObject(stream.bufferedReader().readText())
                val map = mutableMapOf<String, String>()
                json.keys().forEach { key ->
                    map[key.lowercase()] = json.getString(key)
                }
                engineMap = map
            }
        } catch (_: Exception) {
            engineMap = emptyMap()
        }
    }

    fun extractFromApkPaths(
        apkPaths: List<String>,
        context: android.content.Context,
    ): FlutterVersionInfo {
        loadEngineMap(context)
        for (path in apkPaths) {
            try {
                val info = extractFromApk(path, context)
                if (info.flutterVersion != null || info.dartVersion != null) {
                    return info
                }
            } catch (_: Exception) {
                // APK may be unreadable on Android 11+; try next split.
            }
        }
        return FlutterVersionInfo(null, null, emptyList())
    }

    fun extractFromApk(apkPath: String, context: android.content.Context): FlutterVersionInfo {
        loadEngineMap(context)
        ZipFile(apkPath).use { zip ->
            val abiOrder = listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
            for (abi in abiOrder) {
                val entry = zip.getEntry("lib/$abi/libflutter.so")
                if (entry != null) {
                    zip.getInputStream(entry).use { input ->
                        return extractFromLibFlutter(input)
                    }
                }
            }
        }
        return FlutterVersionInfo(null, null, emptyList())
    }

    /** Max bytes read from libflutter.so per pass (version strings live in early .rodata). */
    private const val LIBFLUTTER_READ_LIMIT = 6 * 1024 * 1024

    fun extractFromLibFlutter(input: InputStream): FlutterVersionInfo {
        val text = readBoundedBinaryAsLatin1(input, LIBFLUTTER_READ_LIMIT)

        var dartVersion: String? = null
        val dartMatcher = DART_VERSION_PATTERN.matcher(text)
        if (dartMatcher.find()) {
            dartVersion = "${dartMatcher.group(1)} (${dartMatcher.group(2)})"
        }

        val hashes = mutableSetOf<String>()
        val shaMatcher = ENGINE_SHA_PATTERN.matcher(text)
        while (shaMatcher.find()) {
            hashes.add(shaMatcher.group(1)!!)
        }

        var flutterVersion: String? = null
        val map = engineMap ?: emptyMap()
        for (hash in hashes) {
            val v = map[hash.lowercase()]
            if (v != null) {
                flutterVersion = v
                break
            }
        }

        if (flutterVersion == null) {
            val flutterVerMatcher = Pattern.compile(
                "Flutter ([\\d.]+(?:\\.\\d+)*(?:-pre)?)"
            ).matcher(text)
            if (flutterVerMatcher.find()) {
                flutterVersion = flutterVerMatcher.group(1)
            }
        }

        if (flutterVersion == null && hashes.isNotEmpty()) {
            flutterVersion = "Unknown"
        }

        return FlutterVersionInfo(
            flutterVersion = flutterVersion,
            dartVersion = dartVersion,
            engineHashes = hashes.toList(),
        )
    }

    private fun readBoundedBinaryAsLatin1(input: InputStream, maxBytes: Int): String {
        val buffer = ByteArray(64 * 1024)
        val out = ByteArrayOutputStream(minOf(maxBytes, buffer.size))
        var total = 0
        while (total < maxBytes) {
            val toRead = minOf(buffer.size, maxBytes - total)
            val read = input.read(buffer, 0, toRead)
            if (read <= 0) break
            out.write(buffer, 0, read)
            total += read
        }
        return out.toByteArray().toString(Charsets.ISO_8859_1)
    }
}
