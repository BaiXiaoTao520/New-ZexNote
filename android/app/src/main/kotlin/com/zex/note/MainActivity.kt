package com.zex.note

import android.Manifest
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
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
                    "hasStoragePermission" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            Environment.isExternalStorageManager()
                        } else {
                            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
                                PackageManager.PERMISSION_GRANTED
                        }
                        result.success(granted)
                    }
                    "openStoragePermissionSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                            )
                        } else {
                            requestPermissions(
                                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                                2002
                            )
                        }
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
                    "verifyApkSignature" -> {
                        val path = call.argument<String>("path")
                        result.success(path != null && hasSameApkSignature(File(path)))
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
                            clipData = ClipData.newRawUri("APK", apkUri)
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun hasSameApkSignature(apkFile: File): Boolean {
        if (!apkFile.isFile) return false
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        val downloadedInfo = packageManager.getPackageArchiveInfo(apkFile.path, flags) ?: return false
        val installedInfo = packageManager.getPackageInfo(packageName, flags)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val downloadedSigners = downloadedInfo.signingInfo?.apkContentsSigners
                ?.map { it.toCharsString() }
                ?.toSet()
                ?: return false
            val installedSigners = installedInfo.signingInfo?.apkContentsSigners
                ?.map { it.toCharsString() }
                ?.toSet()
                ?: return false
            return downloadedSigners == installedSigners
        }

        val downloadedSigners = downloadedInfo.signatures?.map { it.toCharsString() }?.toSet()
        val installedSigners = installedInfo.signatures?.map { it.toCharsString() }?.toSet()
        return downloadedSigners != null && downloadedSigners == installedSigners
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
