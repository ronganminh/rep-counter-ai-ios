package com.ronganminh.repcoach

import android.app.Activity
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Bản RỖNG cho biến thể `store`.
 *
 * Cùng API với src/diag/.../DiagRecorder.kt nhưng không làm gì. Nhờ vậy:
 *
 *  - MainActivity ở src/main gọi chung một lớp, không cần `if` theo biến thể;
 *  - APK lên Google Play KHÔNG chứa một dòng mã MediaProjection nào, cũng
 *    không có quyền hay foreground service liên quan;
 *  - `available = false` nên phía Flutter tự ẩn nút ghi màn hình.
 *
 * Đừng thêm gì vào file này. Muốn sửa tính năng ghi thì sửa bản trong src/diag.
 */
object DiagRecorder {
    const val available = false

    fun isRecording(): Boolean = false

    fun start(activity: Activity, result: MethodChannel.Result) {
        result.success(false)
    }

    fun onActivityResult(
        activity: Activity,
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean = false

    fun stop(context: Context): String? = null

    fun save(context: Context, path: String): String? = null

    fun diagDir(context: Context): File = context.cacheDir
}
