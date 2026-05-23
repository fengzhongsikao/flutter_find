package com.example.flutter_find

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Log
import android.os.Build
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicBoolean
import java.util.zip.ZipFile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext

class FlutterAppScanner(private val context: Context) {
    private val packageManager: PackageManager = context.packageManager
    private val cancelled = AtomicBoolean(false)

    companion object {
        private const val TAG = "FlutterAppScanner"
        /** Parallel APK inspections; keep low to avoid OOM from libflutter.so reads. */
        private const val SCAN_PARALLELISM = 2
        private const val ICON_MAX_PX = 96
    }

    fun cancel() {
        cancelled.set(true)
    }

    fun resetCancel() {
        cancelled.set(false)
    }

    suspend fun scanAll(
        excludeSystemApps: Boolean,
        onProgress: (Int, Int) -> Unit,
    ): List<Map<String, Any?>> = withContext(Dispatchers.IO) {
        resetCancel()
        val apps = enumerateApplications(excludeSystemApps)

        val total = apps.size
        var completed = 0
        val semaphore = Semaphore(SCAN_PARALLELISM)
        val results = mutableListOf<Map<String, Any?>>()

        coroutineScope {
            apps.map { appInfo ->
                async {
                    semaphore.withPermit {
                        if (cancelled.get()) return@withPermit null
                        try {
                            val flutter = isFlutterApp(appInfo)
                            if (flutter) buildSummaryMap(appInfo, deepAnalyze = true) else null
                        } catch (e: Exception) {
                            Log.w(TAG, "Failed to scan ${appInfo.packageName}", e)
                            null
                        } finally {
                            completed++
                            onProgress(completed, total)
                        }
                    }
                }
            }.awaitAll().filterNotNull().forEach { results.add(it) }
        }

        results.sortedBy { (it["appName"] as String).lowercase() }
    }

    suspend fun analyzePackage(packageName: String): Map<String, Any?>? =
        withContext(Dispatchers.IO) {
            try {
                val appInfo = loadApplicationInfo(packageName) ?: return@withContext null
                if (!isFlutterApp(appInfo)) return@withContext null
                buildDetailMap(appInfo)
            } catch (_: PackageManager.NameNotFoundException) {
                null
            }
        }

    private fun enumerateApplications(excludeSystemApps: Boolean): List<ApplicationInfo> {
        val byPackage = linkedMapOf<String, ApplicationInfo>()

        for (info in getInstalledApplications()) {
            byPackage[info.packageName] = info
        }

        // Release builds cannot rely on debuggable-only visibility; query launcher apps explicitly.
        for (pkg in getLauncherPackageNames()) {
            if (pkg in byPackage) continue
            loadApplicationInfo(pkg)?.let { byPackage[pkg] = it }
        }

        return byPackage.values.filter { info ->
            if (excludeSystemApps && (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0) {
                return@filter false
            }
            info.sourceDir != null
        }
    }

    private fun getInstalledApplications(): List<ApplicationInfo> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getInstalledApplications(
                PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
        }
    }

    private fun getLauncherPackageNames(): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_ALL.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
        }
        return resolveInfos.map { it.activityInfo.packageName }.toSet()
    }

    private fun loadApplicationInfo(packageName: String): ApplicationInfo? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            }
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
    }

    private fun isFlutterApp(appInfo: ApplicationInfo): Boolean {
        val info = loadApplicationInfo(appInfo.packageName) ?: appInfo
        if (hasFlutterManifestMetadata(info)) return true
        if (isFlutterAppFromApkFiles(info)) return true
        return hasFlutterActivity(info.packageName)
    }

    private fun hasFlutterManifestMetadata(appInfo: ApplicationInfo): Boolean {
        val meta = appInfo.metaData ?: return false
        return meta.containsKey("flutterEmbedding")
    }

    private fun hasFlutterActivity(packageName: String): Boolean {
        return try {
            val flags = PackageManager.GET_ACTIVITIES or PackageManager.GET_META_DATA
            val pkgInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(flags.toLong()),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, flags)
            }
            pkgInfo.activities?.any { activity ->
                val name = activity.name
                name.contains("FlutterActivity") ||
                    name.startsWith("io.flutter.embedding.") ||
                    activity.metaData?.let { meta ->
                        meta.containsKey("io.flutter.embedding.android.NormalTheme") ||
                            meta.containsKey("io.flutter.embedding.android.SplashScreenDrawable") ||
                            meta.containsKey("io.flutter.Entrypoint") ||
                            meta.containsKey("io.flutter.EntrypointUri")
                    } == true
            } == true
        } catch (_: Exception) {
            false
        }
    }

    private fun isFlutterAppFromApkFiles(appInfo: ApplicationInfo): Boolean {
        val abis = listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
        val assetMarkers = listOf(
            "assets/flutter_assets/AssetManifest.json",
            "assets/flutter_assets/AssetManifest.bin",
            "assets/flutter_assets/kernel_blob.bin",
            "assets/flutter_assets/NOTICES",
            "assets/flutter_assets/NOTICES.Z",
        )
        return apkPaths(appInfo).any { path ->
            try {
                ZipFile(path).use { zip ->
                    abis.any { zip.getEntry("lib/$it/libflutter.so") != null } ||
                        assetMarkers.any { zip.getEntry(it) != null }
                }
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun apkPaths(appInfo: ApplicationInfo): List<String> {
        return buildList {
            appInfo.sourceDir?.let { add(it) }
            appInfo.splitSourceDirs?.forEach { add(it) }
        }
    }

    private suspend fun buildSummaryMap(
        appInfo: ApplicationInfo,
        deepAnalyze: Boolean,
    ): Map<String, Any?> {
        var flutterVersion: String? = null
        var dartVersion: String? = null
        if (deepAnalyze) {
            val versionInfo = FlutterVersionExtractor.extractFromApkPaths(
                apkPaths(appInfo),
                context,
            )
            flutterVersion = versionInfo.flutterVersion
            dartVersion = versionInfo.dartVersion
        }
        return mapOf(
            "packageName" to appInfo.packageName,
            "appName" to getAppLabel(appInfo),
            "versionName" to getVersionName(appInfo.packageName),
            "versionCode" to getVersionCode(appInfo.packageName),
            "icon" to loadIconBytes(appInfo),
            "flutterVersion" to flutterVersion,
            "dartVersion" to dartVersion,
        )
    }

    private suspend fun buildDetailMap(appInfo: ApplicationInfo): Map<String, Any?> {
        val paths = apkPaths(appInfo)
        val versionInfo = FlutterVersionExtractor.extractFromApkPaths(paths, context)
        val dependencies = NoticesParser.extractDependencies(paths)
            .map { mapOf("name" to it) }

        return mapOf(
            "packageName" to appInfo.packageName,
            "appName" to getAppLabel(appInfo),
            "versionName" to getVersionName(appInfo.packageName),
            "versionCode" to getVersionCode(appInfo.packageName),
            "icon" to loadIconBytes(appInfo),
            "flutterVersion" to versionInfo.flutterVersion,
            "dartVersion" to versionInfo.dartVersion,
            "dependencies" to dependencies,
        )
    }

    private suspend fun loadIconBytes(appInfo: ApplicationInfo): ByteArray? =
        withContext(Dispatchers.IO) {
            try {
                drawableToBytes(packageManager.getApplicationIcon(appInfo))
            } catch (_: Exception) {
                null
            }
        }

    private fun getAppLabel(appInfo: ApplicationInfo): String {
        return try {
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (_: Exception) {
            appInfo.packageName
        }
    }

    private fun getVersionName(packageName: String): String {
        return try {
            val info = packageManager.getPackageInfo(packageName, 0)
            info.versionName ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    private fun getVersionCode(packageName: String): Int {
        return try {
            val info = packageManager.getPackageInfo(packageName, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode.toInt()
            } else {
                @Suppress("DEPRECATION")
                info.versionCode
            }
        } catch (_: Exception) {
            0
        }
    }

    private fun drawableToBytes(drawable: Drawable): ByteArray? {
        return try {
            val source = when (drawable) {
                is BitmapDrawable -> drawable.bitmap
                else -> {
                    val w = drawable.intrinsicWidth.coerceAtLeast(1)
                    val h = drawable.intrinsicHeight.coerceAtLeast(1)
                    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    bmp
                }
            } ?: return null
            val bitmap = scaleDownBitmap(source, ICON_MAX_PX)
            ByteArrayOutputStream().use { stream ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 85, stream)
                stream.toByteArray()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun scaleDownBitmap(bitmap: Bitmap, maxPx: Int): Bitmap {
        val w = bitmap.width
        val h = bitmap.height
        if (w <= maxPx && h <= maxPx) return bitmap
        val scale = minOf(maxPx.toFloat() / w, maxPx.toFloat() / h)
        val nw = (w * scale).toInt().coerceAtLeast(1)
        val nh = (h * scale).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bitmap, nw, nh, true)
    }
}
