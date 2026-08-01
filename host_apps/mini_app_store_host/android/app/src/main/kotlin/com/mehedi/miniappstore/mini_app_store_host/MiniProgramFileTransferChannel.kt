package com.mehedi.miniappstore.mini_app_store_host

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Host-owned Android document picker and streaming Publisher API transport.
 *
 * Created by `miniprogram host capability init file`. Tooling will not
 * overwrite this file after installation.
 */
internal class MiniProgramFileTransferChannel :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.ActivityResultListener {
    companion object {
        private const val CHANNEL_NAME = "mini_program/files"
        private const val PICK_UPLOAD_REQUEST = 4201
        private const val PICK_DOWNLOAD_REQUEST = 4202
        private const val BUFFER_SIZE = 64 * 1024

        fun register(flutterEngine: FlutterEngine) {
            flutterEngine.plugins.add(MiniProgramFileTransferChannel())
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newCachedThreadPool()
    private val transfers = ConcurrentHashMap<String, TransferTask>()
    private var applicationContext: Context? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var activity: Activity? = null
    private var channel: MethodChannel? = null
    private var pendingPicker: PendingPicker? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(::handleCall)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        pendingPicker?.fail(
            "file_transfer_unavailable",
            "The Android file provider detached from Flutter.",
        )
        pendingPicker = null
        transfers.values.forEach { it.cancel() }
        transfers.clear()
        channel?.setMethodCallHandler(null)
        channel = null
        applicationContext = null
        executor.shutdownNow()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        attach(binding)

    override fun onDetachedFromActivityForConfigChanges() = detach(
        "The file picker closed during Android configuration change.",
    )

    override fun onDetachedFromActivity() = detach(
        "The file picker closed because the host activity detached.",
    )

    private fun attach(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    private fun detach(message: String) {
        pendingPicker?.fail("file_transfer_unavailable", message)
        pendingPicker = null
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "upload" -> beginUpload(arguments(call, result) ?: return, result)
            "download" -> beginDownload(arguments(call, result) ?: return, result)
            "cancel" -> cancel(arguments(call, result) ?: return, result)
            else -> result.notImplemented()
        }
    }

    private fun arguments(
        call: MethodCall,
        result: MethodChannel.Result,
    ): Map<String, Any?>? {
        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as? Map<String, Any?>
        if (args == null) {
            result.error("file_invalid_result", "File transfer arguments are invalid.", null)
        }
        return args
    }

    private fun beginUpload(args: Map<String, Any?>, result: MethodChannel.Result) {
        val transferId = requiredString(args, "transferId", result) ?: return
        val mediaRefs = stringList(args["mediaRefs"])
        if (mediaRefs.isNotEmpty()) {
            val miniProgramId = requiredString(args, "miniProgramId", result) ?: return
            val maxFiles = (args["maxFiles"] as? Number)?.toInt() ?: 1
            if (mediaRefs.size > maxFiles) {
                result.error(
                    "file_transfer_limit_exceeded",
                    "The selected media count exceeds the accepted host limit.",
                    null,
                )
                return
            }
            val uris = mutableListOf<Uri>()
            for (mediaRef in mediaRefs) {
                val existing = MiniProgramHostMediaRegistry.find(mediaRef)
                if (existing == null) {
                    result.error(
                        "media_not_found",
                        "Temporary media is no longer available.",
                        null,
                    )
                    return
                }
                val entry = MiniProgramHostMediaRegistry.findOwned(
                    miniProgramId,
                    mediaRef,
                )
                if (entry == null) {
                    result.error(
                        "media_not_owned",
                        "Temporary media belongs to another mini-program.",
                        null,
                    )
                    return
                }
                uris.add(entry.uri)
            }
            startUpload(args, result, uris)
            return
        }
        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                "file_transfer_unavailable",
                "Android file picking requires a foreground activity.",
                null,
            )
            return
        }
        if (pendingPicker != null) {
            result.error(
                "file_transfer_limit_exceeded",
                "Another Android document picker is already open.",
                null,
            )
            return
        }
        val mimeTypes = stringList(args["mimeTypes"])
        if (mimeTypes.isEmpty()) {
            result.error("file_type_not_accepted", "No upload MIME types were accepted.", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = if (mimeTypes.size == 1) mimeTypes.first() else "*/*"
            if (mimeTypes.size > 1) {
                putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
            }
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, args["multiple"] == true)
        }
        pendingPicker = PendingPicker(transferId, "upload", args, result)
        try {
            currentActivity.startActivityForResult(intent, PICK_UPLOAD_REQUEST)
        } catch (error: Exception) {
            pendingPicker = null
            result.error(
                "file_transfer_unavailable",
                "Android could not open the document picker.",
                error.message,
            )
        }
    }

    private fun beginDownload(args: Map<String, Any?>, result: MethodChannel.Result) {
        val transferId = requiredString(args, "transferId", result) ?: return
        if (args["destination"]?.toString() != "choose") {
            startDownload(args, result, null)
            return
        }
        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                "file_transfer_unavailable",
                "Choosing a download destination requires a foreground activity.",
                null,
            )
            return
        }
        if (pendingPicker != null) {
            result.error(
                "file_transfer_limit_exceeded",
                "Another Android document picker is already open.",
                null,
            )
            return
        }
        val name = safeFileName(args["suggestedName"]?.toString(), "download.bin")
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = args["expectedMimeType"]?.toString() ?: "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, name)
        }
        pendingPicker = PendingPicker(transferId, "download", args, result)
        try {
            currentActivity.startActivityForResult(intent, PICK_DOWNLOAD_REQUEST)
        } catch (error: Exception) {
            pendingPicker = null
            result.error(
                "file_transfer_unavailable",
                "Android could not open the save destination picker.",
                error.message,
            )
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_UPLOAD_REQUEST && requestCode != PICK_DOWNLOAD_REQUEST) {
            return false
        }
        val pending = pendingPicker ?: return true
        pendingPicker = null
        if (resultCode != Activity.RESULT_OK) {
            pending.fail("file_picker_cancelled", "The Android document picker was cancelled.")
            return true
        }
        if (requestCode == PICK_DOWNLOAD_REQUEST) {
            val outputUri = data?.data
            if (outputUri == null) {
                pending.fail("file_invalid_result", "Android returned no save destination.")
            } else {
                startDownload(pending.args, pending.result, outputUri)
            }
            return true
        }
        val uris = mutableListOf<Uri>()
        val clip = data?.clipData
        if (clip != null) {
            for (index in 0 until clip.itemCount) {
                uris.add(clip.getItemAt(index).uri)
            }
        } else {
            data?.data?.let(uris::add)
        }
        val maxFiles = (pending.args["maxFiles"] as? Number)?.toInt() ?: 1
        if (uris.isEmpty() || uris.size > maxFiles) {
            pending.fail(
                "file_transfer_limit_exceeded",
                "The selected file count exceeds the accepted host limit.",
            )
        } else {
            startUpload(pending.args, pending.result, uris)
        }
        return true
    }

    private fun startUpload(
        args: Map<String, Any?>,
        result: MethodChannel.Result,
        uris: List<Uri>,
    ) {
        val transferId = args["transferId"].toString()
        val task = TransferTask(transferId, "upload", result)
        if (transfers.putIfAbsent(transferId, task) != null) {
            result.error(
                "file_transfer_limit_exceeded",
                "The file transfer identifier is already active.",
                null,
            )
            return
        }
        executor.execute {
            try {
                val response = upload(task, args, uris)
                task.success(response)
            } catch (failure: NativeFailure) {
                task.fail(failure.code, failure.message ?: "File upload failed.")
            } catch (error: Exception) {
                task.fail("file_upload_failed", error.message ?: "File upload failed.")
            } finally {
                transfers.remove(transferId, task)
            }
        }
    }

    private fun upload(
        task: TransferTask,
        args: Map<String, Any?>,
        uris: List<Uri>,
    ): Map<String, Any?> {
        val context = applicationContext ?: throw NativeFailure(
            "file_transfer_unavailable",
            "Android file transfer context is unavailable.",
        )
        val files = uris.map { documentInfo(context, it) }
        val acceptedMimeTypes = stringList(args["mimeTypes"])
        val maxFileBytes = (args["maxFileBytes"] as? Number)?.toLong()
        files.forEach {
            if (acceptedMimeTypes.none { accepted -> mimeMatches(accepted, it.mimeType) }) {
                throw NativeFailure("file_type_not_accepted", "A selected file type is not accepted by host policy.")
            }
            if (maxFileBytes != null && it.size != null && it.size > maxFileBytes) {
                throw NativeFailure("file_too_large", "A selected file exceeds the host limit.")
            }
        }
        val totalBytes = files.mapNotNull { it.size }.takeIf { it.size == files.size }?.sum()
        val boundary = "mp-${UUID.randomUUID()}"
        val fieldName = args["fieldName"]?.toString() ?: "file"
        val metadata = mapValue(args["metadata"])
        val urls = stringList(args["candidateUrls"])
        var lastError: Exception? = null
        for (url in urls) {
            task.checkCancelled()
            var connection: HttpURLConnection? = null
            try {
                connection = openConnection(url, args, task)
                connection.requestMethod = "POST"
                connection.doOutput = true
                connection.setChunkedStreamingMode(BUFFER_SIZE)
                connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                var totalTransferred = 0L
                BufferedOutputStream(connection.outputStream, BUFFER_SIZE).use { output ->
                    metadata.forEach { (key, value) ->
                        writeUtf8(output, "--$boundary\r\n")
                        writeUtf8(output, "Content-Disposition: form-data; name=\"${headerToken(key)}\"\r\n\r\n")
                        writeUtf8(output, "${formValue(value)}\r\n")
                    }
                    files.forEach { file ->
                        task.checkCancelled()
                        writeUtf8(output, "--$boundary\r\n")
                        writeUtf8(
                            output,
                            "Content-Disposition: form-data; name=\"${headerToken(fieldName)}\"; filename=\"${headerToken(file.name)}\"\r\n",
                        )
                        writeUtf8(output, "Content-Type: ${file.mimeType}\r\n\r\n")
                        context.contentResolver.openInputStream(file.uri)?.use { raw ->
                            val input = BufferedInputStream(raw, BUFFER_SIZE)
                            val buffer = ByteArray(BUFFER_SIZE)
                            var fileBytes = 0L
                            while (true) {
                                task.checkCancelled()
                                val count = input.read(buffer)
                                if (count < 0) break
                                fileBytes += count
                                totalTransferred += count
                                if (maxFileBytes != null && fileBytes > maxFileBytes) {
                                    throw NativeFailure("file_too_large", "A selected file exceeds the host limit.")
                                }
                                output.write(buffer, 0, count)
                                progress(task, totalTransferred, totalBytes, file.name)
                            }
                        } ?: throw NativeFailure("file_transfer_unavailable", "Android could not read a selected file.")
                        writeUtf8(output, "\r\n")
                    }
                    writeUtf8(output, "--$boundary--\r\n")
                    output.flush()
                }
                val status = connection.responseCode
                val responseData = readJsonResponse(connection)
                if (status !in 200..299) {
                    throw NativeFailure("file_upload_failed", "Publisher API rejected the upload with HTTP $status.")
                }
                return mapOf(
                    "transferId" to task.id,
                    "direction" to "upload",
                    "statusCode" to status,
                    "bytesTransferred" to totalTransferred,
                    "fileName" to files.singleOrNull()?.name,
                    "mimeType" to files.singleOrNull()?.mimeType,
                    "data" to if (responseData.isEmpty()) {
                        mapOf("fileCount" to files.size)
                    } else {
                        responseData
                    },
                )
            } catch (error: IOException) {
                lastError = error
            } finally {
                task.connection = null
                connection?.disconnect()
            }
        }
        throw NativeFailure(
            "file_upload_failed",
            lastError?.message ?: "Publisher API upload was unreachable.",
        )
    }

    private fun startDownload(
        args: Map<String, Any?>,
        result: MethodChannel.Result,
        selectedUri: Uri?,
    ) {
        val transferId = args["transferId"].toString()
        val task = TransferTask(transferId, "download", result)
        if (transfers.putIfAbsent(transferId, task) != null) {
            result.error(
                "file_transfer_limit_exceeded",
                "The file transfer identifier is already active.",
                null,
            )
            return
        }
        executor.execute {
            try {
                val response = download(task, args, selectedUri)
                task.success(response)
            } catch (failure: NativeFailure) {
                task.fail(failure.code, failure.message ?: "File download failed.")
            } catch (error: Exception) {
                task.fail("file_download_failed", error.message ?: "File download failed.")
            } finally {
                transfers.remove(transferId, task)
            }
        }
    }

    private fun download(
        task: TransferTask,
        args: Map<String, Any?>,
        selectedUri: Uri?,
    ): Map<String, Any?> {
        val context = applicationContext ?: throw NativeFailure(
            "file_transfer_unavailable",
            "Android file transfer context is unavailable.",
        )
        val minimumFreeBytes = (args["minimumFreeBytes"] as? Number)?.toLong() ?: 0L
        if (StatFs(context.filesDir.absolutePath).availableBytes < minimumFreeBytes) {
            throw NativeFailure("file_insufficient_storage", "Android storage is below the host reserve.")
        }
        val maxFileBytes = (args["maxFileBytes"] as? Number)?.toLong()
        val request = mapValue(args["request"])
        val method = args["method"]?.toString()?.uppercase() ?: "GET"
        val urls = stringList(args["candidateUrls"])
        var lastError: Exception? = null
        for (candidate in urls) {
            task.checkCancelled()
            var connection: HttpURLConnection? = null
            var output: OutputTarget? = null
            try {
                val url = if (method == "GET") appendQuery(candidate, request) else candidate
                connection = openConnection(url, args, task)
                connection.requestMethod = method
                if (method == "POST") {
                    val body = JSONObject(request).toString().toByteArray(StandardCharsets.UTF_8)
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                    connection.setFixedLengthStreamingMode(body.size)
                    connection.outputStream.use { it.write(body) }
                }
                val status = connection.responseCode
                if (status !in 200..299) {
                    consumeResponse(connection)
                    throw NativeFailure("file_download_failed", "Publisher API rejected the download with HTTP $status.")
                }
                val contentLength = connection.contentLengthLong.takeIf { it >= 0 }
                if (maxFileBytes != null && contentLength != null && contentLength > maxFileBytes) {
                    throw NativeFailure("file_too_large", "The download exceeds the host limit.")
                }
                val mimeType = connection.contentType?.substringBefore(';')?.trim()
                    ?: args["expectedMimeType"]?.toString()
                    ?: "application/octet-stream"
                val expected = args["expectedMimeType"]?.toString()
                if (expected != null && !mimeMatches(expected, mimeType)) {
                    throw NativeFailure("file_type_not_accepted", "The download MIME type did not match the request.")
                }
                val fallbackName = args["suggestedName"]?.toString() ?: "download.bin"
                val fileName = safeFileName(contentDispositionName(connection), fallbackName)
                output = createOutputTarget(context, args, selectedUri, fileName, mimeType)
                var transferred = 0L
                BufferedInputStream(connection.inputStream, BUFFER_SIZE).use { input ->
                    BufferedOutputStream(output.stream, BUFFER_SIZE).use { destination ->
                        val buffer = ByteArray(BUFFER_SIZE)
                        while (true) {
                            task.checkCancelled()
                            val count = input.read(buffer)
                            if (count < 0) break
                            transferred += count
                            if (maxFileBytes != null && transferred > maxFileBytes) {
                                throw NativeFailure("file_too_large", "The download exceeds the host limit.")
                            }
                            destination.write(buffer, 0, count)
                            progress(task, transferred, contentLength, fileName)
                        }
                        destination.flush()
                    }
                }
                output.complete()
                return mapOf(
                    "transferId" to task.id,
                    "direction" to "download",
                    "statusCode" to status,
                    "bytesTransferred" to transferred,
                    "fileName" to fileName,
                    "mimeType" to mimeType,
                    "destination" to (args["destination"]?.toString() ?: "downloads"),
                )
            } catch (error: IOException) {
                output?.cleanup()
                lastError = error
            } catch (error: Exception) {
                output?.cleanup()
                throw error
            } finally {
                task.connection = null
                connection?.disconnect()
            }
        }
        throw NativeFailure(
            "file_download_failed",
            lastError?.message ?: "Publisher API download was unreachable.",
        )
    }

    private fun cancel(args: Map<String, Any?>, result: MethodChannel.Result) {
        val transferId = args["transferId"]?.toString()?.trim().orEmpty()
        val picker = pendingPicker
        if (picker != null && picker.transferId == transferId) {
            pendingPicker = null
            picker.fail("file_transfer_cancelled", "The file transfer was cancelled.")
            result.success(true)
            return
        }
        val task = transfers[transferId]
        if (task == null) {
            result.success(false)
            return
        }
        task.cancel()
        result.success(true)
    }

    private fun openConnection(
        url: String,
        args: Map<String, Any?>,
        task: TransferTask,
    ): HttpURLConnection {
        val connection = URL(url).openConnection() as HttpURLConnection
        val timeout = ((args["timeoutMs"] as? Number)?.toInt() ?: 20_000).coerceIn(1_000, 120_000)
        connection.connectTimeout = timeout
        connection.readTimeout = timeout
        connection.instanceFollowRedirects = true
        mapValue(args["headers"]).forEach { (key, value) ->
            if (value != null) connection.setRequestProperty(key, value.toString())
        }
        task.connection = connection
        return connection
    }

    private fun createOutputTarget(
        context: Context,
        args: Map<String, Any?>,
        selectedUri: Uri?,
        fileName: String,
        mimeType: String,
    ): OutputTarget {
        if (selectedUri != null) {
            val stream = context.contentResolver.openOutputStream(selectedUri, "w")
                ?: run {
                    runCatching { context.contentResolver.delete(selectedUri, null, null) }
                    throw NativeFailure("file_transfer_unavailable", "Android could not open the selected destination.")
                }
            return OutputTarget(stream, {}, {
                runCatching { context.contentResolver.delete(selectedUri, null, null) }
            })
        }
        return when (args["destination"]?.toString()) {
            "temporary" -> {
                val file = File(context.cacheDir, "mp_${UUID.randomUUID()}_$fileName")
                OutputTarget(FileOutputStream(file), {}, { file.delete() })
            }
            else -> createDownloadsTarget(context, fileName, mimeType)
        }
    }

    private fun createDownloadsTarget(
        context: Context,
        fileName: String,
        mimeType: String,
    ): OutputTarget {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = context.contentResolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                values,
            ) ?: throw NativeFailure("file_insufficient_storage", "Android could not create the download.")
            val stream = context.contentResolver.openOutputStream(uri, "w")
                ?: run {
                    runCatching { context.contentResolver.delete(uri, null, null) }
                    throw NativeFailure("file_insufficient_storage", "Android could not open the download.")
                }
            return OutputTarget(
                stream,
                {
                    val completed = ContentValues().apply {
                        put(MediaStore.Downloads.IS_PENDING, 0)
                    }
                    context.contentResolver.update(uri, completed, null, null)
                },
                { context.contentResolver.delete(uri, null, null) },
            )
        }
        val directory = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: context.filesDir
        directory.mkdirs()
        val file = uniqueFile(directory, fileName)
        return OutputTarget(FileOutputStream(file), {}, { file.delete() })
    }

    private fun documentInfo(context: Context, uri: Uri): DocumentInfo {
        var name: String? = null
        var size: Long? = null
        context.contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (nameIndex >= 0) name = cursor.getString(nameIndex)
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) size = cursor.getLong(sizeIndex)
            }
        }
        return DocumentInfo(
            uri,
            safeFileName(name, "upload.bin"),
            context.contentResolver.getType(uri) ?: "application/octet-stream",
            size,
        )
    }

    private fun progress(task: TransferTask, bytes: Long, total: Long?, name: String?) {
        val data = mutableMapOf<String, Any?>(
            "transferId" to task.id,
            "direction" to task.direction,
            "bytesTransferred" to bytes,
            "fileName" to name,
        )
        if (total != null) data["totalBytes"] = total
        mainHandler.post { channel?.invokeMethod("progress", data) }
    }

    private fun appendQuery(url: String, request: Map<String, Any?>): String {
        if (request.isEmpty()) return url
        val separator = if (url.contains('?')) '&' else '?'
        val query = request.entries.joinToString("&") { (key, value) ->
            val encodedValue = when (value) {
                is Map<*, *>, is List<*> -> JSONObject.wrap(value).toString()
                null -> ""
                else -> value.toString()
            }
            "${encode(key)}=${encode(encodedValue)}"
        }
        return "$url$separator$query"
    }

    private fun consumeResponse(connection: HttpURLConnection) {
        val stream = if (connection.responseCode in 200..299) {
            connection.inputStream
        } else {
            connection.errorStream
        }
        stream?.use { input ->
            val buffer = ByteArray(BUFFER_SIZE)
            while (input.read(buffer) >= 0) Unit
        }
    }

    private fun readJsonResponse(connection: HttpURLConnection): Map<String, Any?> {
        val stream = if (connection.responseCode in 200..299) {
            connection.inputStream
        } else {
            connection.errorStream
        } ?: return emptyMap()
        val output = ByteArrayOutputStream()
        stream.use { input ->
            val buffer = ByteArray(8 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                if (output.size() + count > 1024 * 1024) {
                    throw NativeFailure("file_invalid_result", "Publisher upload response is too large.")
                }
                output.write(buffer, 0, count)
            }
        }
        val source = output.toString(StandardCharsets.UTF_8.name()).trim()
        if (source.isEmpty()) return emptyMap()
        return try {
            val json = JSONObject(source)
            json.keys().asSequence().associateWith { key -> jsonValue(json.get(key)) }
        } catch (error: Exception) {
            emptyMap()
        }
    }

    private fun jsonValue(value: Any?): Any? = when (value) {
        JSONObject.NULL -> null
        is JSONObject -> value.keys().asSequence().associateWith { key -> jsonValue(value.get(key)) }
        is org.json.JSONArray -> (0 until value.length()).map { jsonValue(value.get(it)) }
        else -> value
    }

    private fun formValue(value: Any?): String = when (value) {
        is Map<*, *>, is List<*> -> JSONObject.wrap(value).toString()
        null -> ""
        else -> value.toString()
    }

    private fun contentDispositionName(connection: HttpURLConnection): String? {
        val header = connection.getHeaderField("Content-Disposition") ?: return null
        val match = Regex("filename\\*?=(?:UTF-8''|\\\")?([^\\\";]+)", RegexOption.IGNORE_CASE)
            .find(header)
        return match?.groupValues?.getOrNull(1)?.let { Uri.decode(it) }
    }

    private fun mimeMatches(expected: String, actual: String): Boolean {
        if (expected == "*/*" || expected.equals(actual, ignoreCase = true)) return true
        return expected.endsWith("/*") &&
            actual.startsWith("${expected.substringBefore('/')}/", ignoreCase = true)
    }

    private fun uniqueFile(directory: File, requested: String): File {
        var file = File(directory, requested)
        var index = 1
        val base = requested.substringBeforeLast('.', requested)
        val extension = requested.substringAfterLast('.', "")
        while (file.exists()) {
            val suffix = if (extension.isEmpty()) "" else ".$extension"
            file = File(directory, "$base ($index)$suffix")
            index++
        }
        return file
    }

    private fun safeFileName(value: String?, fallback: String): String {
        val cleaned = value.orEmpty()
            .replace(Regex("[\\\\/:*?\"<>|\\p{Cntrl}]"), "_")
            .trim()
            .take(180)
        return if (cleaned.isEmpty() || cleaned == "." || cleaned == "..") fallback else cleaned
    }

    private fun headerToken(value: String): String = value
        .replace("\\", "_")
        .replace("\"", "_")
        .replace("\r", "_")
        .replace("\n", "_")

    private fun requiredString(
        args: Map<String, Any?>,
        key: String,
        result: MethodChannel.Result,
    ): String? {
        val value = args[key]?.toString()?.trim().orEmpty()
        if (value.isEmpty()) {
            result.error("file_invalid_result", "File transfer requires $key.", null)
            return null
        }
        return value
    }

    private fun stringList(value: Any?): List<String> =
        (value as? List<*>)?.mapNotNull { it?.toString() } ?: emptyList()

    private fun mapValue(value: Any?): Map<String, Any?> {
        @Suppress("UNCHECKED_CAST")
        return value as? Map<String, Any?> ?: emptyMap()
    }

    private fun writeUtf8(output: OutputStream, value: String) {
        output.write(value.toByteArray(StandardCharsets.UTF_8))
    }

    private fun encode(value: String): String =
        URLEncoder.encode(value, StandardCharsets.UTF_8.name())

    private inner class TransferTask(
        val id: String,
        val direction: String,
        private val result: MethodChannel.Result,
    ) {
        private val finished = AtomicBoolean(false)
        private val cancelled = AtomicBoolean(false)
        @Volatile var connection: HttpURLConnection? = null

        fun checkCancelled() {
            if (cancelled.get()) {
                throw NativeFailure("file_transfer_cancelled", "The file transfer was cancelled.")
            }
        }

        fun cancel() {
            cancelled.set(true)
            connection?.disconnect()
        }

        fun success(value: Map<String, Any?>) {
            if (finished.compareAndSet(false, true)) {
                mainHandler.post { result.success(value) }
            }
        }

        fun fail(code: String, message: String) {
            val effectiveCode = if (cancelled.get()) "file_transfer_cancelled" else code
            val effectiveMessage = if (cancelled.get()) "The file transfer was cancelled." else message
            if (finished.compareAndSet(false, true)) {
                mainHandler.post { result.error(effectiveCode, effectiveMessage, null) }
            }
        }
    }

    private data class PendingPicker(
        val transferId: String,
        val direction: String,
        val args: Map<String, Any?>,
        val result: MethodChannel.Result,
    ) {
        fun fail(code: String, message: String) = result.error(code, message, null)
    }

    private data class DocumentInfo(
        val uri: Uri,
        val name: String,
        val mimeType: String,
        val size: Long?,
    )

    private data class OutputTarget(
        val stream: OutputStream,
        val complete: () -> Unit,
        val cleanup: () -> Unit,
    )

    private class NativeFailure(val code: String, message: String) : IOException(message)
}
