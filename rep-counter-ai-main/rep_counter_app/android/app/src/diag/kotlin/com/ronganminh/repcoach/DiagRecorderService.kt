package com.ronganminh.repcoach

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.view.WindowManager
import java.io.File

/**
 * Dịch vụ nền giữ MediaProjection trong lúc ghi.
 *
 * Từ Android 14 (API 34), MediaProjection BẮT BUỘC phải chạy trong một
 * foreground service kiểu `mediaProjection`, và phải gọi `startForeground`
 * TRƯỚC khi lấy đối tượng MediaProjection. Thứ tự trong `onStartCommand` dưới
 * đây theo đúng ràng buộc đó.
 */
class DiagRecorderService : Service() {

    private var projection: MediaProjection? = null
    private var recorder: MediaRecorder? = null
    private var display: android.hardware.display.VirtualDisplay? = null

    private val projectionCallback = object : MediaProjection.Callback() {
        // Android 14 yêu cầu đăng ký callback này. Người dùng có thể dừng chia
        // sẻ màn hình từ thanh thông báo, lúc đó phải dọn dẹp tử tế.
        override fun onStop() {
            teardown()
            stopSelf()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        val code = intent.getIntExtra(EXTRA_CODE, Activity_RESULT_CANCELED)
        val data: Intent? = intent.getParcelableExtra(EXTRA_DATA)
        val path = intent.getStringExtra(EXTRA_PATH)
        if (data == null || path == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        // 1. Foreground TRƯỚC, rồi mới lấy MediaProjection.
        startForegroundCompat()

        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
            as MediaProjectionManager
        val mp = manager.getMediaProjection(code, data)
        if (mp == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        projection = mp
        mp.registerCallback(projectionCallback, null)

        try {
            beginRecording(mp, File(path))
            outputPath = path
            isRunning = true
        } catch (error: Exception) {
            teardown()
            stopSelf()
            return START_NOT_STICKY
        }
        return START_NOT_STICKY
    }

    private fun beginRecording(mp: MediaProjection, target: File) {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        (getSystemService(Context.WINDOW_SERVICE) as WindowManager)
            .defaultDisplay.getMetrics(metrics)

        // Hạ độ phân giải xuống tối đa 720px chiều rộng. Bộ đếm rep đã ngốn hơn
        // 2 lõi CPU cho MediaPipe; quay nguyên 1080p nữa thì bộ mã hoá sẽ giành
        // CPU và làm rơi khung hình của chính thứ đang cần đo.
        val scale = minOf(1.0, 720.0 / metrics.widthPixels)
        val w = even((metrics.widthPixels * scale).toInt())
        val h = even((metrics.heightPixels * scale).toInt())

        @Suppress("DEPRECATION")
        val rec = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            MediaRecorder()
        }
        rec.apply {
            // Chỉ hình, không tiếng: app không xin quyền micro.
            setVideoSource(MediaRecorder.VideoSource.SURFACE)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            setVideoSize(w, h)
            setVideoFrameRate(FPS)
            setVideoEncodingBitRate(BITRATE)
            setOutputFile(target.absolutePath)
            prepare()
        }
        recorder = rec

        display = mp.createVirtualDisplay(
            "repcoach-diag",
            w,
            h,
            metrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            rec.surface,
            null,
            null,
        )
        rec.start()
    }

    private fun startForegroundCompat() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    "Ghi màn hình gỡ lỗi",
                    NotificationManager.IMPORTANCE_LOW,
                )
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setContentTitle("RepCoach DIAG đang ghi màn hình")
            .setContentText("Dừng trong app khi tập xong")
            .setSmallIcon(android.R.drawable.presence_video_online)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun teardown() {
        try {
            recorder?.stop()
        } catch (_: Exception) {
            // stop() ném RuntimeException nếu chưa nhận được khung hình nào.
            // File sẽ hỏng, nhưng không được để nó làm sập app.
        }
        try {
            recorder?.reset()
            recorder?.release()
        } catch (_: Exception) {
        }
        recorder = null
        display?.release()
        display = null
        projection?.unregisterCallback(projectionCallback)
        projection?.stop()
        projection = null
        isRunning = false
    }

    override fun onDestroy() {
        teardown()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "repcoach_diag"
        private const val NOTIFICATION_ID = 0xD1A6
        // Do thuc te tren LG V60: 720x1640 @ 24fps / 4 Mbps cho ra 41 MB cho
        // 87 giay -> buoi 5 phut se ~140 MB, nguoi test kho gui qua chat.
        // Ha xuong 20fps / 2,5 Mbps: van du muot de nhin khung xuong co bam
        // nguoi hay khong, ma file nho gan mot nua. Ban than app cung chi tinh
        // duoc ~15 khung/giay nen 20fps la du.
        private const val FPS = 20
        private const val BITRATE = 2_500_000
        private const val EXTRA_CODE = "code"
        private const val EXTRA_DATA = "data"
        private const val EXTRA_PATH = "path"
        private const val Activity_RESULT_CANCELED = 0

        @Volatile
        var isRunning = false
            private set

        @Volatile
        private var outputPath: String? = null

        fun consentIntent(context: Context): Intent {
            val manager = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                as MediaProjectionManager
            return manager.createScreenCaptureIntent()
        }

        fun start(context: Context, code: Int, data: Intent, target: File) {
            val intent = Intent(context, DiagRecorderService::class.java).apply {
                putExtra(EXTRA_CODE, code)
                putExtra(EXTRA_DATA, data)
                putExtra(EXTRA_PATH, target.absolutePath)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context): String? {
            if (!isRunning) return null
            val path = outputPath
            context.stopService(Intent(context, DiagRecorderService::class.java))
            isRunning = false
            return path
        }

        private fun even(v: Int): Int = if (v % 2 == 0) v else v - 1
    }
}
