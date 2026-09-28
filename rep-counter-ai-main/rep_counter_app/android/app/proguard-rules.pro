# Luật R8 cho bản release.
#
# Flutter tự bật rút gọn mã cho bản release (FlutterPlugin.kt:
# `releaseBuildType.isMinifyEnabled = true`) kèm `proguard-android-optimize.txt`.
# Không có file này thì R8 xoá mất những thứ chỉ được gọi qua reflection.
#
# Flutter tự nạp file này nếu nó tồn tại ở android/app/proguard-rules.pro.

# ============================================================
# Room — BẮT BUỘC, không có là app crash ngay khi mở
# ============================================================
# Room sinh ra các lớp `*_Impl` và chỉ tạo chúng bằng reflection
# (`Class.forName(...).newInstance()`), nên R8 không thấy ai gọi hàm khởi tạo
# và xoá nó đi. Room bắt InstantiationException rồi ném
# "Failed to create an instance of ..." — app chết trước cả khi Flutter khởi
# động, trên MỌI thiết bị.
#
# Đây không phải phỏng đoán. build/app/outputs/mapping/release/usage.txt của
# bản build hỏng ghi đúng dòng này trong danh sách đã xoá:
#
#     androidx.work.impl.WorkDatabase_Impl:
#         public void <init>()
#
# Room chỉ kèm sẵn luật này từ phiên bản 2.3.0. androidx.work 2.7.0 (do
# camera_android_camerax kéo theo) dùng Room 2.2.x nên không có.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-dontwarn androidx.room.paging.**

# ============================================================
# WorkManager
# ============================================================
# WorkManager khởi tạo qua androidx.startup.InitializationProvider ngay lúc
# tạo Application. Hỏng ở đây là hỏng trước mọi thứ khác.
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }
-keep class * extends androidx.work.Worker { <init>(...); }
-keep class * extends androidx.work.ListenableWorker { <init>(...); }

# ============================================================
# ML Kit pose detection
# ============================================================
# Bộ nhận diện tư thế nạp mô hình và lớp xử lý qua reflection.
-keep class com.google.mlkit.vision.pose.** { *; }
-keep class com.google.mlkit.common.** { *; }
-dontwarn com.google.mlkit.**

# ============================================================
# Bớt cảnh báo nhiễu
# ============================================================
# Các lớp chỉ dùng khi biên dịch, không có mặt lúc chạy.
-dontwarn javax.annotation.**
-dontwarn javax.lang.model.element.Modifier
