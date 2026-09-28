package com.ronganminh.repcoach

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Ghi lại màn hình buổi tập để người test gửi về gỡ lỗi.
 *
 * Chỉ có trong biến thể `diag`. Bản `store` dùng lớp cùng tên nhưng rỗng
 * (src/store/.../DiagRecorder.kt), nên mã MediaProjection không thể lọt vào
 * APK phát hành.
 *
 * KHÔNG ghi âm: `MediaRecorder` chỉ nhận nguồn hình. Nhờ vậy manifest không
 * cần RECORD_AUDIO, và người test không bị thu tiếng trong nhà.
 */
object DiagRecorder {
    const val available = true

    private const val REQUEST_CONSENT = 0xD1A6
    private const val ALBUM = "RepCoach"

    /** Kết quả của `start` được giữ ở đây tới khi người dùng bấm đồng ý/từ chối. */
    private var pending: MethodChannel.Result? = null

    fun isRecording(): Boolean = DiagRecorderService.isRunning

    /** Mở hộp thoại xin phép quay màn hình của hệ thống. */
    fun start(activity: Activity, result: MethodChannel.Result) {
        if (DiagRecorderService.isRunning) {
            result.success(true)
            return
        }
        if (pending != null) {
            result.error("busy", "Đang chờ người dùng đồng ý", null)
            return
        }
        pending = result
        activity.startActivityForResult(
            DiagRecorderService.consentIntent(activity),
            REQUEST_CONSENT,
        )
    }

    /**
     * Gọi từ `MainActivity.onActivityResult`. Trả về true nếu đã xử lý.
     */
    fun onActivityResult(
        activity: Activity,
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        if (requestCode != REQUEST_CONSENT) return false
        val result = pending
        pending = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result?.success(false)
            return true
        }
        val target = outputFile(activity)
        try {
            DiagRecorderService.start(activity, resultCode, data, target)
            result?.success(true)
        } catch (error: Exception) {
            result?.error("start_failed", error.message, null)
        }
        return true
    }

    /** Dừng ghi và trả về đường dẫn file, hoặc null nếu không có gì đang ghi. */
    fun stop(context: Context): String? = DiagRecorderService.stop(context)

    /**
     * Chép file ra bộ nhớ chung để người test tự tìm và gửi đi.
     *
     * Trước đây chỗ này là nút "Gửi" mở thẳng bảng chia sẻ. Lưu ra ngoài tốt
     * hơn: file nằm sẵn trong Thư viện / Tải xuống, người ta gửi lúc nào cũng
     * được, gửi qua đường nào cũng được, và không mất nếu gỡ app.
     *
     * Video vào `Movies/RepCoach`, số liệu vào `Download/RepCoach`.
     *
     * Từ Android 10 dùng MediaStore nên KHÔNG cần quyền bộ nhớ nào.
     *
     * Android 9 trở xuống thì không chép đi đâu cả, chỉ trả về chỗ file đang
     * nằm sẵn. Chép ra thư mục chung ở bản cũ đòi WRITE_EXTERNAL_STORAGE, mà
     * `src/release/AndroidManifest.xml` lại gỡ quyền đó và build type thắng
     * flavor nên không giành lại được — giành cũng không nên, chỉ để phục vụ
     * một nhánh không có máy nào ở đây thử được. Trên Android 9, thư mục
     * `Android/data/<app>/files/diag` vẫn mở được bằng trình quản lý file.
     *
     * Trả về vị trí dạng đọc được, hoặc null nếu hỏng.
     */
    fun save(context: Context, path: String): String? {
        val src = File(path)
        if (!src.exists()) return null
        val isVideo = src.name.endsWith(".mp4")
        val folder = if (isVideo) Environment.DIRECTORY_MOVIES
        else Environment.DIRECTORY_DOWNLOADS
        val mime = if (isVideo) "video/mp4" else "text/csv"
        val shown = "$folder/$ALBUM/${src.name}"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = if (isVideo) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, src.name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, "$folder/$ALBUM")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = context.contentResolver
            val uri = resolver.insert(collection, values) ?: return null
            return try {
                // Ném chứ đừng `return null` ở đây: return sớm sẽ bỏ qua khối
                // catch, để lại một bản ghi IS_PENDING=1 mồ côi trong
                // MediaStore (phải 7 ngày hệ thống mới tự dọn).
                val out = resolver.openOutputStream(uri)
                    ?: throw IllegalStateException("khong mo duoc luong ghi")
                out.use { dst -> src.inputStream().use { it.copyTo(dst) } }
                // Bỏ cờ chờ, lúc này Thư viện mới nhìn thấy file.
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                shown
            } catch (error: Exception) {
                // Chép dở thì xoá bản rác đi, đừng để lại file 0 byte trong
                // Thư viện làm người test tưởng đã lưu xong.
                resolver.delete(uri, null, null)
                null
            }
        }

        // Android 9 trở xuống: để nguyên chỗ cũ, chỉ nói cho người dùng biết.
        return src.absolutePath
    }

    /**
     * Thư mục file ngoài của app: người test tìm được bằng trình quản lý file,
     * mà app vẫn không cần quyền truy cập bộ nhớ nào.
     */
    fun diagDir(context: Context): File {
        val dir = File(context.getExternalFilesDir(null), "diag")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun outputFile(context: Context): File {
        val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
        val model = Build.MODEL.replace(Regex("[^A-Za-z0-9]+"), "-")
        return File(diagDir(context), "repcoach-$model-$stamp.mp4")
    }
}
