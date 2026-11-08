package com.shorie.lifequest

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var calendarBridge: CalendarBridge? = null
    private var sharedStorageBridge: SharedStorageBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = CalendarBridge(this)
        calendarBridge = bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CalendarBridge.CHANNEL)
            .setMethodCallHandler(bridge)

        val storage = SharedStorageBridge(this)
        sharedStorageBridge = storage
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SharedStorageBridge.CHANNEL)
            .setMethodCallHandler(storage)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        calendarBridge?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        sharedStorageBridge?.onActivityResult(requestCode, resultCode, data)
    }
}
