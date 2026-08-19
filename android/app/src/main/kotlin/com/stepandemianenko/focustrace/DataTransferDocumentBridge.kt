package com.stepandemianenko.focustrace

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

internal class DataTransferDocumentBridge(
    private val activity: FlutterActivity,
) {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingExport: String? = null

    fun configure(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            if (pendingResult != null) {
                result.error("TRANSFER_IN_PROGRESS", "Another data transfer is already open.", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "saveBackup" -> {
                    val arguments = call.arguments as? Map<*, *>
                    val fileName = arguments?.get("suggestedFileName") as? String
                    val contents = arguments?.get("contents") as? String
                    if (fileName.isNullOrBlank() || contents == null) {
                        result.error("INVALID_EXPORT", "Backup name and contents are required.", null)
                        return@setMethodCallHandler
                    }
                    pendingResult = result
                    pendingExport = contents
                    activity.startActivityForResult(
                        Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = JSON_MIME_TYPE
                            putExtra(Intent.EXTRA_TITLE, fileName)
                        },
                        REQUEST_CREATE_BACKUP,
                    )
                }
                "openBackup" -> {
                    pendingResult = result
                    activity.startActivityForResult(
                        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = JSON_MIME_TYPE
                            putExtra(
                                Intent.EXTRA_MIME_TYPES,
                                arrayOf(JSON_MIME_TYPE, "text/plain", "application/octet-stream"),
                            )
                        },
                        REQUEST_OPEN_BACKUP,
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CREATE_BACKUP && requestCode != REQUEST_OPEN_BACKUP) {
            return false
        }
        val result = pendingResult ?: return true
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pendingExport = null
            if (requestCode == REQUEST_CREATE_BACKUP) result.success(false) else result.success(null)
            return true
        }

        try {
            val uri = requireNotNull(data.data)
            if (requestCode == REQUEST_CREATE_BACKUP) {
                val contents = requireNotNull(pendingExport)
                activity.contentResolver.openOutputStream(uri, "wt").use { output ->
                    requireNotNull(output) { "Could not open the selected backup destination." }
                    output.write(contents.toByteArray(Charsets.UTF_8))
                }
                pendingExport = null
                result.success(true)
            } else {
                val bytes = activity.contentResolver.openInputStream(uri).use { input ->
                    requireNotNull(input) { "Could not open the selected backup file." }
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var total = 0
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        total += read
                        require(total <= MAX_BACKUP_BYTES) { "Backup file is larger than 10 MB." }
                        output.write(buffer, 0, read)
                    }
                    output.toByteArray()
                }
                result.success(bytes.toString(Charsets.UTF_8))
            }
        } catch (error: Exception) {
            pendingExport = null
            result.error("DATA_TRANSFER_FAILED", error.message, null)
        }
        return true
    }

    private companion object {
        const val CHANNEL_NAME = "focustrace/data_transfer"
        const val JSON_MIME_TYPE = "application/json"
        const val REQUEST_CREATE_BACKUP = 7310
        const val REQUEST_OPEN_BACKUP = 7311
        const val MAX_BACKUP_BYTES = 10 * 1024 * 1024
    }
}
