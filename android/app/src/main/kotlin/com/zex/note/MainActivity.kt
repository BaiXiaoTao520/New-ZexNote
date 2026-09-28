package com.zex.note

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.content.FileProvider
import java.io.File

class MainActivity : ComponentActivity() {
    private lateinit var services: AppServices

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        services = AppServices(this)
        setContent { ZexNoteApp(services) }
    }
}

class AppServices(private val context: Context) {
    private val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    private val client = okhttp3.OkHttpClient()

    fun getBoolean(key: String, default: Boolean) = prefs.getBoolean("flutter.$key", default)
    fun setBoolean(key: String, value: Boolean) = prefs.edit().putBoolean("flutter.$key", value).apply()
    fun getInt(key: String, default: Int) = prefs.getInt("flutter.$key", default)
    fun setInt(key: String, value: Int) = prefs.edit().putInt("flutter.$key", value).apply()
    fun getString(key: String, default: String = "") = prefs.getString("flutter.$key", default) ?: default
    fun setString(key: String, value: String) = prefs.edit().putString("flutter.$key", value).apply()

    fun hasStoragePermission(): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        Environment.isExternalStorageManager()
    } else {
        context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
    }

    fun openStorageSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            context.startActivity(Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:${context.packageName}")))
        } else {
            (context as? Activity)?.requestPermissions(
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                2002,
            )
        }
    }

    fun canInstallPackages(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.O || context.packageManager.canRequestPackageInstalls()

    fun openInstallSettings() {
        context.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}")))
    }

    fun downloadDirectory(): File {
        val configured = getString("downloadDirectoryName").trim()
            .replace(Regex("[\\\\/:*?\\\"<>|]"), "_")
        val directory = if (configured.isEmpty()) {
            File("/storage/emulated/0/Download")
        } else {
            File("/storage/emulated/0/Download", configured)
        }
        directory.mkdirs()
        return directory
    }

    fun verifyApkSignature(file: File): Boolean {
        if (!file.isFile) return false
        @Suppress("DEPRECATION")
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val downloaded = context.packageManager.getPackageArchiveInfo(file.path, flags) ?: return false
        val installed = context.packageManager.getPackageInfo(context.packageName, flags)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val a = downloaded.signingInfo?.apkContentsSigners?.map { it.toCharsString() }?.toSet() ?: return false
            val b = installed.signingInfo?.apkContentsSigners?.map { it.toCharsString() }?.toSet() ?: return false
            return a == b
        }
        @Suppress("DEPRECATION")
        val a = downloaded.signatures?.map { it.toCharsString() }?.toSet()
        @Suppress("DEPRECATION")
        val b = installed.signatures?.map { it.toCharsString() }?.toSet()
        return a != null && a == b
    }

    fun installApk(file: File) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        context.startActivity(Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }

    fun httpClient() = client
}
