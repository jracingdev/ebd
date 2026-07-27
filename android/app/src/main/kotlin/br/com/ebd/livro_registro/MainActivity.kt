package br.com.ebd.livro_registro

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.nio.charset.StandardCharsets

/// FlutterFragmentActivity é obrigatório para local_auth (BiometricPrompt / Fragment).
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "br.com.ebd.livro_registro/backup"
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickBackup" -> {
                        if (pendingResult != null) {
                            result.error("busy", "Outra operação de arquivo em andamento.", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(
                                Intent.EXTRA_MIME_TYPES,
                                arrayOf("application/json", "text/plain", "text/*", "*/*"),
                            )
                        }
                        startActivityForResult(intent, REQ_OPEN)
                    }
                    "saveBackup" -> {
                        if (pendingResult != null) {
                            result.error("busy", "Outra operação de arquivo em andamento.", null)
                            return@setMethodCallHandler
                        }
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName") ?: "ebd-backup.json"
                        if (bytes == null) {
                            result.error("args", "bytes obrigatórios", null)
                            return@setMethodCallHandler
                        }
                        pendingResult = result
                        pendingBytes = bytes
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/json"
                            putExtra(Intent.EXTRA_TITLE, fileName)
                        }
                        startActivityForResult(intent, REQ_CREATE)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val result = pendingResult
        pendingResult = null
        if (result == null) return

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pendingBytes = null
            result.success(null)
            return
        }

        val uri: Uri = data.data!!
        try {
            when (requestCode) {
                REQ_OPEN -> {
                    val text = contentResolver.openInputStream(uri)?.use { input ->
                        BufferedReader(InputStreamReader(input, StandardCharsets.UTF_8)).readText()
                    }
                    result.success(text)
                }
                REQ_CREATE -> {
                    val bytes = pendingBytes
                    pendingBytes = null
                    if (bytes == null) {
                        result.error("args", "Sem dados para salvar", null)
                        return
                    }
                    contentResolver.openOutputStream(uri)?.use { out ->
                        out.write(bytes)
                        out.flush()
                    } ?: run {
                        result.error("write", "Não foi possível gravar o arquivo.", null)
                        return
                    }
                    result.success(uri.toString())
                }
                else -> result.success(null)
            }
        } catch (e: Exception) {
            pendingBytes = null
            result.error("io", e.message, null)
        }
    }

    companion object {
        private const val REQ_OPEN = 4101
        private const val REQ_CREATE = 4102
    }
}
