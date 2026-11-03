package com.shorie.lifequest

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var calendarBridge: CalendarBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = CalendarBridge(this)
        calendarBridge = bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CalendarBridge.CHANNEL)
            .setMethodCallHandler(bridge)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        calendarBridge?.onRequestPermissionsResult(requestCode, grantResults)
    }
}
