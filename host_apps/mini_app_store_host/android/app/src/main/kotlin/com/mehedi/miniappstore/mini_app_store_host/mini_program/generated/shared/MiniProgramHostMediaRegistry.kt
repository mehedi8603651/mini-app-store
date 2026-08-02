package com.mehedi.miniappstore.mini_app_store_host

import android.net.Uri
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * Shared host-owned registry for opaque temporary media references.
 *
 * Native locations never cross the Flutter channel. Camera producers register
 * entries here; preview and file-transfer consumers resolve only same-app refs.
 */
internal object MiniProgramHostMediaRegistry {
    data class Entry(
        val miniProgramId: String,
        val mediaRef: String,
        val file: File,
        val uri: Uri,
        val fileName: String,
        val mimeType: String,
    ) {
        val size: Long get() = file.length()
    }

    private val entries = ConcurrentHashMap<String, Entry>()

    fun register(entry: Entry): Boolean {
        if (entry.miniProgramId.isBlank() ||
            entry.mediaRef.isBlank() ||
            !entry.file.exists() ||
            entry.file.length() <= 0L
        ) {
            return false
        }
        return entries.putIfAbsent(entry.mediaRef, entry) == null
    }

    fun find(mediaRef: String): Entry? = entries[mediaRef]

    fun findOwned(miniProgramId: String, mediaRef: String): Entry? {
        val entry = entries[mediaRef] ?: return null
        return if (entry.miniProgramId == miniProgramId) entry else null
    }

    fun releaseOwned(miniProgramId: String, mediaRef: String): Boolean {
        val entry = entries[mediaRef] ?: return false
        if (entry.miniProgramId != miniProgramId) return false
        if (!entries.remove(mediaRef, entry)) return false
        entry.file.delete()
        return true
    }

    fun releaseAny(mediaRef: String): Boolean {
        val entry = entries.remove(mediaRef) ?: return false
        entry.file.delete()
        return true
    }
}
