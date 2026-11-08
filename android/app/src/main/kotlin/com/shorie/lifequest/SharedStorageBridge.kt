package com.shorie.lifequest

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.documentfile.provider.DocumentFile
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 現世（アプリ）をまたぐ共有フォルダへの橋渡し。
 *
 * Android 10+ の scoped storage では `/data/local/tmp` にアプリから書けない。
 * アプリ間で見える唯一の正式な場所は Storage Access Framework（SAF）で
 * ユーザーが選んだフォルダ。ここではその URI を永続化し、
 * `DocumentFile` 経由で読み書きする。
 *
 * Dart 側は `AndroidSharedFileStore` が対応する。
 * チャンネル: `com.shorie.lifequest/shared_storage`
 */
class SharedStorageBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.shorie.lifequest/shared_storage"
        private const val REQUEST_CODE = 4821
        private const val PREFS = "shared_storage"
        private const val KEY_URI = "directory_uri"
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ensureDirectory" -> ensureDirectory(result)
            "chooseDirectory" -> chooseDirectory(result)
            "writeString" -> writeString(call, result)
            "appendLine" -> appendLine(call, result)
            "readString" -> readString(call, result)
            "delete" -> delete(call, result)
            "exists" -> exists(call, result)
            "listFiles" -> listFiles(result)
            "forget" -> forget(result)
            else -> result.notImplemented()
        }
    }

    // --- フォルダ解決 -------------------------------------------------------

    private fun savedUri(): Uri? {
        val raw = activity.getSharedPreferences(PREFS, Activity.MODE_PRIVATE)
            .getString(KEY_URI, null) ?: return null
        return try {
            Uri.parse(raw)
        } catch (e: Exception) {
            null
        }
    }

    private fun saveUri(uri: Uri) {
        activity.getSharedPreferences(PREFS, Activity.MODE_PRIVATE)
            .edit().putString(KEY_URI, uri.toString()).apply()
        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        try {
            activity.contentResolver.takePersistableUriPermission(uri, flags)
        } catch (e: SecurityException) {
            // 一部のプロバイダは永続化を許さない。書込自体は続行できる。
        }
    }

    private fun directory(): DocumentFile? {
        val uri = savedUri() ?: return null
        return DocumentFile.fromTreeUri(activity, uri)
    }

    /** 保存済みで書き込み可能なら true。**UI は出さない**（起動時・書込時に黙って失敗を返す）。 */
    private fun ensureDirectory(result: MethodChannel.Result) {
        result.success(directory()?.canWrite() == true)
    }

    /** フォルダ選択 UI を出し、結果を [onActivityResult] で返す（連携画面から明示的に呼ぶ）。 */
    private fun chooseDirectory(result: MethodChannel.Result) {
        pendingResult?.success(false)
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
        }
        activity.startActivityForResult(intent, REQUEST_CODE)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_CODE) return
        val result = pendingResult ?: return
        pendingResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(false)
            return
        }
        val uri = data?.data
        if (uri == null) {
            result.success(false)
            return
        }
        saveUri(uri)
        result.success(directory()?.canWrite() == true)
    }

    // --- ファイル操作 -------------------------------------------------------

    private fun find(name: String): DocumentFile? =
        directory()?.findFile(name)?.takeIf { it.isFile }

    private fun writeString(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")
        val content = call.argument<String>("content")
        if (name == null || content == null) {
            result.error("bad_args", "name/content required", null)
            return
        }
        try {
            val dir = directory() ?: run {
                result.error("no_directory", "shared folder not chosen", null)
                return
            }
            find(name)?.delete()
            val file = dir.createFile("application/octet-stream", name)
                ?: run {
                    result.error("create_failed", "createFile returned null", null)
                    return
                }
            activity.contentResolver.openOutputStream(file.uri)?.use { out ->
                out.write(content.toByteArray(Charsets.UTF_8))
                out.flush()
            } ?: run {
                result.error("open_failed", "openOutputStream returned null", null)
                return
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("write_failed", e.message, e.toString())
        }
    }

    private fun appendLine(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")
        val line = call.argument<String>("line")
        if (name == null || line == null) {
            result.error("bad_args", "name/line required", null)
            return
        }
        try {
            val dir = directory() ?: run {
                result.error("no_directory", "shared folder not chosen", null)
                return
            }
            var file = find(name)
            if (file == null) {
                file = dir.createFile("application/octet-stream", name) ?: run {
                    result.error("create_failed", "createFile returned null", null)
                    return
                }
            }
            activity.contentResolver.openOutputStream(file.uri, "wa")?.use { out ->
                out.write("$line\n".toByteArray(Charsets.UTF_8))
                out.flush()
            } ?: run {
                result.error("open_failed", "openOutputStream returned null", null)
                return
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("append_failed", e.message, e.toString())
        }
    }

    private fun readString(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name") ?: run {
            result.error("bad_args", "name required", null)
            return
        }
        try {
            val file = find(name)
            if (file == null) {
                result.success(null)
                return
            }
            val text = activity.contentResolver.openInputStream(file.uri)?.use { input ->
                input.readBytes().toString(Charsets.UTF_8)
            }
            result.success(text)
        } catch (e: Exception) {
            result.error("read_failed", e.message, e.toString())
        }
    }

    private fun delete(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name") ?: run {
            result.error("bad_args", "name required", null)
            return
        }
        try {
            val file = find(name)
            result.success(file?.delete() ?: false)
        } catch (e: Exception) {
            result.error("delete_failed", e.message, e.toString())
        }
    }

    private fun exists(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name") ?: run {
            result.error("bad_args", "name required", null)
            return
        }
        try {
            result.success(find(name) != null)
        } catch (e: Exception) {
            result.error("exists_failed", e.message, e.toString())
        }
    }

    private fun listFiles(result: MethodChannel.Result) {
        try {
            val dir = directory()
            if (dir == null) {
                result.success(emptyList<String>())
                return
            }
            result.success(dir.listFiles().filter { it.isFile }.map { it.name ?: "" })
        } catch (e: Exception) {
            result.error("list_failed", e.message, e.toString())
        }
    }

    private fun forget(result: MethodChannel.Result) {
        activity.getSharedPreferences(PREFS, Activity.MODE_PRIVATE).edit().clear().apply()
        result.success(true)
    }
}
