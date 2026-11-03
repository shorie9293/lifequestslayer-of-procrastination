package com.shorie.lifequest

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.provider.CalendarContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 端末カレンダー（CalendarContract）への橋渡し。
 *
 * Dart 側は `MethodChannelCalendarGateway` が対応する。読み取りのみを提供し、
 * 書き込みは既存の .ics 共有（calendar_export）に任せる。
 */
class CalendarBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.shorie.lifequest/calendar"
        private const val PERMISSION_REQUEST_CODE = 4711
        private val PERMISSIONS = arrayOf(Manifest.permission.READ_CALENDAR)
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ensureAccess" -> ensureAccess(result)
            "readEvents" -> {
                val from = call.argument<Number>("fromMillis")?.toLong() ?: 0L
                val to = call.argument<Number>("toMillis")?.toLong() ?: 0L
                result.success(readEvents(from, to))
            }
            else -> result.notImplemented()
        }
    }

    /** 権限を確認し、無ければ要求する。結果は [onRequestPermissionsResult] で返す。 */
    private fun ensureAccess(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success("granted")
            return
        }
        // 連打時は古い要求を denied で畳んでから新しい要求を待つ（結果の取り違え防止）。
        pendingResult?.success("denied")
        pendingResult = result
        activity.requestPermissions(PERMISSIONS, PERMISSION_REQUEST_CODE)
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQUEST_CODE) return
        val result = pendingResult ?: return
        pendingResult = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        result.success(if (granted) "granted" else "denied")
    }

    private fun hasPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return activity.checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun readEvents(fromMillis: Long, toMillis: Long): List<Map<String, Any?>> {
        if (!hasPermission()) return emptyList()

        val events = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            CalendarContract.Events._ID,
            CalendarContract.Events.CALENDAR_ID,
            CalendarContract.Events.TITLE,
            CalendarContract.Events.DTSTART,
            CalendarContract.Events.DTEND,
            CalendarContract.Events.ALL_DAY,
            CalendarContract.Events.EVENT_LOCATION,
        )
        val selection = "${CalendarContract.Events.DTSTART} >= ? AND " +
            "${CalendarContract.Events.DTSTART} <= ? AND " +
            "${CalendarContract.Events.DELETED} = 0"
        val selectionArgs = arrayOf(fromMillis.toString(), toMillis.toString())

        activity.contentResolver.query(
            CalendarContract.Events.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            "${CalendarContract.Events.DTSTART} ASC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val start = cursor.getLong(3)
                // 繰り返し予定は DTEND を持たないことがある。その場合は開始と同じ扱い。
                val end = if (cursor.isNull(4)) start else cursor.getLong(4)
                events.add(
                    mapOf(
                        "eventId" to cursor.getLong(0).toString(),
                        "calendarId" to cursor.getLong(1).toString(),
                        "title" to if (cursor.isNull(2)) "" else cursor.getString(2),
                        "startMillis" to start,
                        "endMillis" to end,
                        "allDay" to (cursor.getInt(5) == 1),
                        "location" to if (cursor.isNull(6)) null else cursor.getString(6),
                    ),
                )
            }
        }
        return events
    }
}
