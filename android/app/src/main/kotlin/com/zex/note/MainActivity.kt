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
                    "systemProperties" -> {
                        val keys = listOf(
                            "ro.flyme.version",
                            "ro.flyme.os.version",
                            "ro.build.flyme.version",
                            "persist.sys.flyme.version",
                            "ro.aios.version",
                            "ro.vivo.os.name",
                            "ro.vivo.os.version",
                            "ro.vivo.product.overseas",
                            "ro.build.display.id",
                            "ro.build.fingerprint",
                            "ro.product.brand",
                            "ro.product.manufacturer",
                            "ro.product.model"
                        )
                        val properties = keys.associateWith { getSystemProperty(it) }
                        result.success(properties)
                    }
                    "hasRootAccess" -> runRootCommand("id", result)
                    "rootInstallApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null || !File(path).isFile) {
                            result.success(mapOf("success" to false, "message" to "APK 文件不存在"))
                        } else {
                            runRootInstall(File(path), result)
                        }
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

    private fun getSystemProperty(key: String): String {
        try {
            val systemProperties = Class.forName("android.os.SystemProperties")
            val get = systemProperties.getMethod("get", String::class.java, String::class.java)
            val value = get.invoke(null, key, "") as? String
            if (!value.isNullOrEmpty()) return value
        } catch (_: Exception) {}
        return try {
            val process = ProcessBuilder("getprop", key).start()
            val value = process.inputStream.bufferedReader().use { it.readText() }.trim()
            process.waitFor()
            value
        } catch (_: Exception) {
            ""
        }
    }

    private fun runRootCommand(command: String, result: MethodChannel.Result) {
        Thread {
            val success = try {
                val process = ProcessBuilder("su", "-c", command).start()
                process.waitFor() == 0
            } catch (_: Exception) {
                false
            }
            runOnUiThread { result.success(success) }
        }.start()
    }

    private fun runRootInstall(apkFile: File, result: MethodChannel.Result) {
        Thread {
            var message = ""
            val tempPath = "/data/local/tmp/zexnote-${System.nanoTime()}.apk"
            val success = try {
                val command = "cat > $tempPath && chown 2000:2000 $tempPath && chmod 0644 $tempPath && " +
                    "pm install -r $tempPath; status=\$?; rm -f $tempPath; exit \$status"
                val process = ProcessBuilder("su", "-c", command)
                    .redirectErrorStream(true)
                    .start()
                process.outputStream.use { output ->
                    apkFile.inputStream().use { input -> input.copyTo(output) }
                }
                message = process.inputStream.bufferedReader().use { it.readText() }.trim()
                process.waitFor() == 0 && message.contains("Success", ignoreCase = true)
            } catch (error: Exception) {
                message = error.message ?: error.javaClass.simpleName
                try {
                    ProcessBuilder("su", "-c", "rm -f $tempPath").start().waitFor()
                } catch (_: Exception) {}
                false
            }
            runOnUiThread {
                result.success(mapOf("success" to success, "message" to message))
            }
        }.start()
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
