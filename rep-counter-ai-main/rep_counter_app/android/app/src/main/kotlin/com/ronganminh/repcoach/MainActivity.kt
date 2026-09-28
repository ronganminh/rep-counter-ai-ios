package com.ronganminh.repcoach

import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    /**
     * Kenh chan doan. `DiagRecorder` co hai ban cai dat theo bien the:
     * src/diag (that) va src/store (rong, `available = false`). Nho vay
     * MainActivity khong can biet dang chay ban nao, va ban len Play khong
     * chua ma ghi man hinh.
     */
    private fun configureDiagChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "repcoach/diag",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(DiagRecorder.available)
                "isRecording" -> result.success(DiagRecorder.isRecording())
                "start" -> DiagRecorder.start(this, result)
                "stop" -> result.success(DiagRecorder.stop(this))
                "dir" -> result.success(DiagRecorder.diagDir(this).absolutePath)
                "save" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("missing_path", "Thieu duong dan file", null)
                    } else {
                        result.success(DiagRecorder.save(this, path))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (DiagRecorder.onActivityResult(this, requestCode, resultCode, data)) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureDiagChannel(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "rep_counter/video_frames",
        ).setMethodCallHandler { call, result ->
            if (call.method != "frame") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            val timeMs = call.argument<Int>("timeMs") ?: 0
            val maxWidth = call.argument<Int>("maxWidth") ?: 480
            if (path == null) {
                result.error("missing_path", "Video path is required", null)
                return@setMethodCallHandler
            }
            try {
                val retriever = MediaMetadataRetriever()
                retriever.setDataSource(path)
                val source = retriever.getFrameAtTime(
                    timeMs.toLong() * 1000L,
                    MediaMetadataRetriever.OPTION_CLOSEST,
                )
                retriever.release()
                if (source == null) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                val scaled = if (source.width > maxWidth) {
                    val height = (source.height * maxWidth.toDouble() / source.width).toInt()
                    Bitmap.createScaledBitmap(source, maxWidth, height, true)
                } else {
                    source
                }
                val output = File(cacheDir, "pose_frame.jpg")
                FileOutputStream(output).use {
                    scaled.compress(Bitmap.CompressFormat.JPEG, 78, it)
                }
                if (scaled !== source) scaled.recycle()
                source.recycle()
                result.success(output.absolutePath)
            } catch (error: Exception) {
                result.error("frame_failed", error.message, null)
            }
        }
    }
}
