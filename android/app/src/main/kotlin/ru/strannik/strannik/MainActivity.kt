package ru.strannik.strannik

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var notificationPermissionResult: MethodChannel.Result? = null
    private val notificationPermissionRequest = 304
    private val rewardsChannel = "strannik_rewards"
    private val notificationManager: NotificationManager
        get() = getSystemService(NotificationManager::class.java)

    private fun notificationsAllowed(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        if (!notificationManager.areNotificationsEnabled()) return false
        val channel = notificationManager.getNotificationChannel(rewardsChannel)
        return channel == null || channel.importance != NotificationManager.IMPORTANCE_NONE
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "strannik/support")
            .setMethodCallHandler { call, result ->
                if (call.method != "email") { result.notImplemented(); return@setMethodCallHandler }
                val subject = call.argument<String>("subject") ?: "Странник"
                val intent = Intent(Intent.ACTION_SENDTO,
                    Uri.parse("mailto:strannik@mail.ru?subject=" + Uri.encode(subject)))
                try { startActivity(intent); result.success(true) }
                catch (_: ActivityNotFoundException) { result.success(false) }
                catch (_: SecurityException) { result.success(false) }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "strannik/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "allowed" -> result.success(notificationsAllowed())
                    "requestPermission" -> {
                        notificationManager.createNotificationChannel(NotificationChannel(
                            rewardsChannel, "Подарки в Страннике", NotificationManager.IMPORTANCE_DEFAULT))
                        if (notificationsAllowed()) { result.success(true) }
                        else if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            if (notificationPermissionResult != null) { result.success(false) }
                            else {
                                notificationPermissionResult = result
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationPermissionRequest)
                            }
                        } else { result.success(false) }
                    }
                    "reward" -> {
                        val amount = call.argument<Number>("amount")?.toLong() ?: 0
                        val operation = call.argument<String>("operationId")
                        if (amount <= 0 || operation.isNullOrEmpty()) {
                            result.error("invalid_reward", "Missing reward amount or operation", null)
                        } else if (!notificationsAllowed()) { result.success(null) }
                        else {
                            val open = PendingIntent.getActivity(this, 0,
                                Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                            val notification = Notification.Builder(this, rewardsChannel)
                                .setSmallIcon(R.drawable.ic_notification)
                                .setContentTitle("Новый подарок!")
                                .setContentText("Вам подарили $amount ₣ для новых приключений в Страннике.")
                                .setContentIntent(open).setAutoCancel(true).build()
                            try { notificationManager.notify(operation, 1, notification); result.success(null) }
                            catch (_: SecurityException) { result.success(null) }
                        }
                    }
                    "clear" -> { notificationManager.cancelAll(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationPermissionRequest) {
            val callback = notificationPermissionResult
            notificationPermissionResult = null
            callback?.success(notificationsAllowed())
        }
    }

    override fun onDestroy() {
        notificationPermissionResult?.success(false)
        notificationPermissionResult = null
        super.onDestroy()
    }
}
