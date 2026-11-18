package app.awavenue.c001apk

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build.VERSION.SDK_INT
import android.os.Build.VERSION_CODES.P
import android.os.Environment
import android.os.Build
import android.os.Bundle
import android.window.BackEvent
import android.webkit.MimeTypeMap;
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.BackEventCompat
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "samples.flutter.dev/channel"
    private var linksChannel: MethodChannel? = null
    private val pendingLinks = mutableListOf<String>()

    private fun enqueueLink(intent: Intent?) {
        if (intent?.action == Intent.ACTION_VIEW) {
            intent.dataString?.let { pendingLinks.add(it) }
            linksChannel?.invokeMethod("linksChanged", null)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        enqueueLink(intent)
    }

    // Flutter 3.24's FragmentActivity forwards only completed back presses.
    // Keep the FragmentActivity required by the document picker, and bridge
    // Android 14+ progress through Flutter's existing back gesture channel.
    private val predictiveBackCallback = object : OnBackPressedCallback(false) {
        private var gestureStarted = false

        override fun handleOnBackStarted(backEvent: BackEventCompat) {
            if (SDK_INT >= 34) {
                gestureStarted = true
                flutterEngine?.backGestureChannel?.startBackGesture(
                    BackEvent(backEvent.touchX, backEvent.touchY,
                        backEvent.progress, backEvent.swipeEdge))
            }
        }

        override fun handleOnBackProgressed(backEvent: BackEventCompat) {
            if (SDK_INT >= 34) {
                flutterEngine?.backGestureChannel?.updateBackGestureProgress(
                    BackEvent(backEvent.touchX, backEvent.touchY,
                        backEvent.progress, backEvent.swipeEdge))
            }
        }

        override fun handleOnBackCancelled() {
            gestureStarted = false
            flutterEngine?.backGestureChannel?.cancelBackGesture()
        }

        override fun handleOnBackPressed() {
            if (gestureStarted) {
                gestureStarted = false
                flutterEngine?.backGestureChannel?.commitBackGesture()
            } else {
                flutterEngine?.navigationChannel?.popRoute()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (SDK_INT >= 34) {
            onBackPressedDispatcher.addCallback(this, predictiveBackCallback)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Flutter's default deep-link route is disabled in the manifest.
        // Queue the launch intent until Dart has mounted the root navigator.
        enqueueLink(intent)
        linksChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "app.awavenue.c001apk/links").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "takePendingLinks") {
                    val links = pendingLinks.toList()
                    pendingLinks.clear()
                    result.success(links)
                } else {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "setPredictiveBackEnabled") {
                // Root destinations leave back-to-home to Android itself.
                predictiveBackCallback.isEnabled = SDK_INT >= 34 && call.arguments == true
                result.success(null)
            } else if (call.method == "getAppBuildNumber") {
                result.success(getString(R.string.app_build_number))
            } else if (call.method == "getProtocolDeviceProfile") {
                result.success(mapOf(
                    "manufacturer" to Build.MANUFACTURER,
                    "brand" to Build.BRAND,
                    "model" to Build.MODEL,
                    "buildNumber" to Build.DISPLAY,
                    "sdkInt" to SDK_INT.toString(),
                    "androidVersion" to Build.VERSION.RELEASE
                ))
            } else if (call.method == "openOfficialIdSettings") {
                try {
                    packageManager.getApplicationInfo("com.coolapk.market", 0)
                    // This app also handles coolmarket links. Explicitly target
                    // the official client so the guide never opens ourselves.
                    startActivity(Intent(Intent.ACTION_VIEW,
                        Uri.parse("coolmarket://www.coolapk.com/native/testSettings"))
                        .setPackage("com.coolapk.market"))
                    result.success(true)
                } catch (e: PackageManager.NameNotFoundException) {
                    result.error("official_client_not_installed", null, null)
                } catch (e: Exception) {
                    result.success(false)
                }
            } else if (call.method == "getInstalledApps") {
                Thread {
                    result.success(getInstalledApps())
                }.start()
            } else if (call.method == "downloadApk") {
                val url = call.argument<String>("url")
                val name = call.argument<String>("name")
                if (url != null && name != null) {
                    val response = downloadApk(url, name)
                    result.success(response)
                } else {
                    result.success(false)
                }
            } else if (call.method == "exportData") {
                val data = call.argument<String>("data")
                val fileName = call.argument<String>("fileName")
                if (data != null && fileName != null) {
                    exportData = data
                    exportData(fileName)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private var exportData: String? = null

    private val backupSAFLauncher =
        registerForActivityResult(ActivityResultContracts.CreateDocument("application/json")) backup@{ uri ->
            if (uri == null) return@backup
            try{
                contentResolver.openOutputStream(uri).use { output ->
                    if (output == null)
                        return@backup
                    else if (exportData != null) {
                            output.write(exportData!!.toByteArray())
                            exportData = null
                            Toast.makeText(this, "导出成功", Toast.LENGTH_SHORT).show()
                        }
                    else
                        Toast.makeText(this, "暂无可导出的数据", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Toast.makeText(this, "导出失败，请检查文件访问权限后重试", Toast.LENGTH_SHORT).show()
            }
    }

    private fun exportData(fileName: String) {
        try {
            backupSAFLauncher.launch(fileName)
        } catch (e: Exception) {
            Toast.makeText(this, "无法打开文件保存窗口，请稍后重试", Toast.LENGTH_SHORT).show()
        }
    }

    private fun downloadApk(url: String, name: String): Boolean {
        try {
            val mimeType = MimeTypeMap.getSingleton()
                .getMimeTypeFromExtension(MimeTypeMap.getFileExtensionFromUrl(url))
            val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            val request = DownloadManager
                .Request(Uri.parse(url))
                .setMimeType(mimeType)
                .setTitle(name)
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, name)
            if (SDK_INT < 29) {
                request.allowScanningByMediaScanner()
                request.setVisibleInDownloadsUi(true)
            }
            downloadManager.enqueue(request)
            return true
        } catch (e: Exception) {
            return false
        }
    }

    private fun getInstalledApps(): List<Map<String, Any?>> {
        var appList = packageManager.getInstalledApplications(0).filter { info ->
            (info.flags and ApplicationInfo.FLAG_SYSTEM) != ApplicationInfo.FLAG_SYSTEM
        }
        return appList.map { info ->
            val packageInfo = packageManager.getPackageInfo(info.packageName, 0)
            mapOf(
                "icon" to drawableToByteArray(info.loadIcon(packageManager)),
                "appName" to packageManager.getApplicationLabel(info),
                "packageName" to info.packageName,
                "versionName" to packageInfo.versionName,
                "versionCode" to getVersionCode(packageInfo).toString(),
                "lastUpdateTime" to packageInfo.lastUpdateTime.toString(),
            )
        }
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val bitmap = drawableToBitmap(drawable)
        ByteArrayOutputStream().use { stream ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            return stream.toByteArray()
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable) {
            return drawable.bitmap
        }
        val bitmap = Bitmap.createBitmap(
            drawable.intrinsicWidth,
            drawable.intrinsicHeight,
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    private fun getVersionCode(packageInfo: PackageInfo): Long {
        return if (SDK_INT < P) packageInfo.versionCode.toLong()
        else packageInfo.longVersionCode
    }

}
