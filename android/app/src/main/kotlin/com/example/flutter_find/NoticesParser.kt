package com.example.flutter_find

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.zip.GZIPInputStream
import java.util.zip.ZipFile

object NoticesParser {
    private val SDK_PACKAGES = setOf(
        "flutter",
        "sky_engine",
        "flutter_test",
        "flutter_localizations",
        "flutter_web_plugins",
        "flutter_driver",
        "flutter_goldens",
        "flutter_tools",
    )

    private val PACKAGE_NAME_REGEX = Regex("^[a-z][a-z0-9_]*\$")

    fun extractDependencies(apkPaths: List<String>): List<String> {
        val all = mutableSetOf<String>()
        for (path in apkPaths) {
            try {
                all.addAll(extractDependenciesFromApk(path))
            } catch (_: Exception) {
                // APK may be unreadable on Android 11+; try next split.
            }
        }
        return all.filter { it !in SDK_PACKAGES && it.isNotEmpty() }
            .distinct()
            .sorted()
    }

    private fun extractDependenciesFromApk(apkPath: String): List<String> {
        val fromNotices = mutableSetOf<String>()
        val fromAssets = mutableSetOf<String>()

        ZipFile(apkPath).use { zip ->
            val noticesEntry = zip.getEntry("assets/flutter_assets/NOTICES.Z")
                ?: zip.getEntry("assets/flutter_assets/NOTICES")
            if (noticesEntry != null) {
                try {
                    zip.getInputStream(noticesEntry).use { input ->
                        val text = decompressNotices(input.readBytes())
                        fromNotices.addAll(parsePackageNamesFromNotices(text))
                    }
                } catch (_: Exception) {
                    // Keep scanning packages/ paths even if NOTICES parsing fails.
                }
            }

            zip.entries().asSequence().forEach { entry ->
                val match = Regex("^assets/flutter_assets/packages/([a-z][a-z0-9_]*)/")
                    .find(entry.name)
                if (match != null) {
                    fromAssets.add(match.groupValues[1])
                }
            }
        }

        return (fromNotices + fromAssets).toList()
    }

    fun decompressNotices(compressed: ByteArray): String {
        var data = compressed
        while (isGzip(data)) {
            data = gunzip(data)
        }
        return data.toString(Charsets.UTF_8)
    }

    private fun isGzip(data: ByteArray): Boolean =
        data.size >= 2 && data[0] == 0x1f.toByte() && data[1] == 0x8b.toByte()

    private fun gunzip(input: ByteArray): ByteArray {
        GZIPInputStream(ByteArrayInputStream(input)).use { gzip ->
            val out = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            var read: Int
            while (gzip.read(buffer).also { read = it } != -1) {
                out.write(buffer, 0, read)
            }
            return out.toByteArray()
        }
    }

    fun parsePackageNamesFromNotices(text: String): List<String> {
        val names = mutableListOf<String>()
        val lines = text.lines()
        for (i in lines.indices) {
            val line = lines[i].trim()
            if (line.isEmpty() || !PACKAGE_NAME_REGEX.matches(line) || line in SDK_PACKAGES) {
                continue
            }
            val prevBlank = i == 0 || lines[i - 1].trim().isEmpty()
            if (!prevBlank) continue
            val nextIdx = i + 1
            if (nextIdx < lines.size) {
                val next = lines[nextIdx].trim()
                if (next.isEmpty() ||
                    next.startsWith("Copyright") ||
                    next.contains("license", ignoreCase = true) ||
                    next.contains("License", ignoreCase = true)
                ) {
                    names.add(line)
                }
            } else {
                names.add(line)
            }
        }
        return names.distinct()
    }
}
