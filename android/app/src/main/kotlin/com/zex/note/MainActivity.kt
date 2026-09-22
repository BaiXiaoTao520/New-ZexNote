package com.zex.note

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.zex.note/installer"
    private val createTextFileRequestCode = 1001
    private var pendingTextResult: MethodChannel.Result? = null
    private var pendingTextContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallPackages" -> {
                        result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls())
                    }
                    "openInstallSettings" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(null)
                    }
                    "showToast" -> {
                        Toast.makeText(this, call.argument<String>("message") ?: "", Toast.LENGTH_SHORT).show()
                        result.success(null)
                    }
                    "saveTextFile" -> {
                        val filename = call.argument<String>("filename") ?: "便签.txt"
                        pendingTextResult = result
                        pendingTextContent = call.argument<String>("content") ?: ""
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TITLE, filename)
                        }
                        startActivityForResult(intent, createTextFileRequestCode)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("MISSING_PATH", "APK path is missing", null)
                            return@setMethodCallHandler
                        }
                        val apkUri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            File(path)
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != createTextFileRequestCode) return

        val result = pendingTextResult
        val content = pendingTextContent
        pendingTextResult = null
        pendingTextContent = null
        if (result == null || resultCode != RESULT_OK || data?.data == null || content == null) {
            result?.success(false)
            return
        }

        try {
            val output = contentResolver.openOutputStream(data.data!!)
            if (output == null) {
                result.success(false)
                return
            }
            output.use { it.write(content.toByteArray(Charsets.UTF_8)) }
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }
}
