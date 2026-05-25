package com.rottymusic.rotty_music

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val channelName = "com.rottymusic.rotty_music/upi"
    private val flashChannel = "com.rottymusic.rotty_music/flashlight"
    private val requestCode = 99127
    private var pendingResult: MethodChannel.Result? = null
    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize camera for flashlight
        try {
            cameraManager = getSystemService(CAMERA_SERVICE) as CameraManager
            cameraId = cameraManager?.cameraIdList?.firstOrNull()
        } catch (_: Exception) {}

        // ── Flashlight Channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, flashChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    result.success(cameraId != null && packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH))
                }
                "turnOn" -> {
                    try {
                        cameraManager?.setTorchMode(cameraId ?: "", true)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("flash_error", e.message, null)
                    }
                }
                "turnOff" -> {
                    try {
                        cameraManager?.setTorchMode(cameraId ?: "", false)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("flash_error", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── UPI Channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getUpiApps" -> {
                    try {
                        result.success(getUpiApps())
                    } catch (e: Exception) {
                        result.error("apps_failed", e.message, null)
                    }
                }
                "startPayment" -> {
                    val packageName = call.argument<String>("package") ?: run {
                        result.error("invalid", "package required", null)
                        return@setMethodCallHandler
                    }
                    val uri = call.argument<String>("uri") ?: run {
                        result.error("invalid", "uri required", null)
                        return@setMethodCallHandler
                    }
                    pendingResult = result
                    startUpi(packageName, uri)
                }
                else -> result.notImplemented()
            }
        }

        // ── OTA Channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rottymusic.rotty_music/ota").setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val path = call.argument<String>("path") ?: run {
                    result.error("invalid", "path required", null)
                    return@setMethodCallHandler
                }
                try {
                    val success = installApk(path)
                    result.success(success)
                } catch (e: Exception) {
                    result.error("install_failed", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getUpiApps(): List<Map<String, Any?>> {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("upi://pay?pa=test@upi&pn=Test&am=1&cu=INR"))
        val pm = packageManager

        // Use broader flags for better detection on all Android versions
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PackageManager.MATCH_ALL
        } else {
            0
        }

        val apps = pm.queryIntentActivities(intent, flags)
        val list = mutableListOf<Map<String, Any?>>()
        val seen = mutableSetOf<String>()

        for (resolve in apps) {
            val pkg = resolve.activityInfo.packageName
            if (!seen.add(pkg)) continue

            val label = try {
                resolve.loadLabel(pm).toString()
            } catch (_: Exception) {
                pkg
            }

            val iconBytes = try {
                val iconDrawable = resolve.loadIcon(pm)
                drawableToPng(iconDrawable)
            } catch (_: Exception) {
                ByteArray(0)
            }

            list.add(
                mapOf(
                    "package" to pkg,
                    "name" to label,
                    "icon" to iconBytes,
                ),
            )
        }
        return list
    }

    private fun drawableToPng(drawable: Drawable): ByteArray {
        val w = drawable.intrinsicWidth.coerceAtLeast(1).coerceAtMost(96)
        val h = drawable.intrinsicHeight.coerceAtLeast(1).coerceAtMost(96)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        val stream = java.io.ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
        bitmap.recycle()
        return stream.toByteArray()
    }

    private fun startUpi(packageName: String, uriString: String) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uriString))
            intent.setPackage(packageName)
            startActivityForResult(intent, requestCode)
        } catch (e: Exception) {
            // Fallback: try without package restriction (let system choose)
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uriString))
                startActivityForResult(intent, requestCode)
            } catch (e2: Exception) {
                pendingResult?.error("launch_failed", e2.message, null)
                pendingResult = null
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != this.requestCode) return
        val result = pendingResult ?: return
        pendingResult = null
        if (data == null) {
            result.error("cancelled", "Payment cancelled", null)
            return
        }
        val response = data.getStringExtra("response")
        if (response.isNullOrBlank()) {
            result.error("empty", "No response from UPI app", null)
        } else {
            result.success(response)
        }
    }

    private fun installApk(filePath: String): Boolean {
        val file = java.io.File(filePath)
        if (!file.exists()) return false

        val context = applicationContext
        val intent = Intent(Intent.ACTION_VIEW)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val authority = "${context.packageName}.fileprovider"
            val uri = androidx.core.content.FileProvider.getUriForFile(context, authority, file)
            intent.setDataAndType(uri, "application/vnd.android.package-archive")
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } else {
            intent.setDataAndType(Uri.fromFile(file), "application/vnd.android.package-archive")
        }

        context.startActivity(intent)
        return true
    }
}
