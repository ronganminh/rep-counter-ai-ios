# Đối chiếu văn bản pháp lý VI ↔ EN

> **File này được sinh tự động.** Đừng sửa tay — sửa
> [`lib/core/i18n/app_strings.dart`](../lib/core/i18n/app_strings.dart) rồi chạy
> `python tools/gen_legal_table.py`.

Nguồn duy nhất của các chuỗi này là `app_strings.dart` (`S.vi` và `S.en`);
[`lib/features/legal/legal_page.dart`](../lib/features/legal/legal_page.dart)
chỉ ghép chúng lại.

Bản tiếng Anh trong app phải khớp **từng câu** với trang web tại
`https://repcoach-ai.duckdns.org/`. Kiểm tra bằng
`python tools/verify_policy_sync.py`. Trang web chỉ có tiếng Anh — đó là chủ ý.

## Cách nhờ AI khác kiểm tra

Bản dịch cố ý bám sát từng ý của bản tiếng Việt, không viết lại cho mượt, để so
từng dòng cho dễ. Khi nhờ ChatGPT/Gemini duyệt, hỏi đúng ba câu:

1. Bản tiếng Anh có nói **thừa** điều gì mà bản tiếng Việt không nói không?
   (Nguy hiểm nhất: hứa hẹn về bảo mật/quyền riêng tư mạnh hơn thực tế.)
2. Có nói **thiếu** ý nào so với bản tiếng Việt không?
3. Câu nào nghe như **cam kết pháp lý** chặt hơn ý định ban đầu?

Đừng hỏi "dịch có hay không" — văn bản pháp lý cần đúng, không cần hay.

---

## Chính sách quyền riêng tư / Privacy policy

| Khoá | Tiếng Việt | English |
|---|---|---|
| `privacyPolicy` — *tiêu đề trang* | Chính sách quyền riêng tư | Privacy policy |
| `legalEffective` — *nhãn ngày hiệu lực* | Có hiệu lực | Effective |
| `legalDate` — *ngày hiệu lực* | 05/09/2026 | September 5, 2026 |
| `privacyIntroBody` — *mở đầu (đứng sau tên app)* | tôn trọng quyền riêng tư. Chính sách này mô tả dữ liệu được xử lý khi bạn dùng ứng dụng. | respects your privacy. This policy describes the data that is processed when you use the app. |
| `privCameraTitle` | Camera và video | Camera and video |
| `privCameraBody` | Ứng dụng dùng camera để nhận diện tư thế và đếm số lần lặp động tác. Khung hình camera, video bạn tự chọn để kiểm thử và landmark tư thế đều được xử lý trên thiết bị. Ứng dụng không tải những hình ảnh hay video này lên máy chủ. | The app uses your camera to detect body pose and count exercise repetitions. Camera frames, videos that you select for testing, and pose landmarks are processed on your device. The app does not upload these images or videos to a server. |
| `privWorkoutTitle` | Dữ liệu buổi tập | Workout data |
| `privWorkoutBody` | Số rep, thời lượng, mục tiêu buổi tập và các chỉ số chất lượng động tác được lưu cục bộ trên thiết bị để hiển thị lịch sử tập. | Rep count, duration, workout goal, and movement-quality metrics are stored locally on your device to provide workout history. |
| `privAiTitle` | Nhận xét AI | AI feedback |
| `privAiBody` | Khi bạn chủ động yêu cầu hoặc đã đồng ý bật nhận xét AI tự động, ứng dụng gửi bản tóm tắt buổi tập đến máy chủ do nhà phát triển vận hành và Google Gemini. Bản tóm tắt có thể gồm số rep, thời lượng, mục tiêu và các chỉ số chất lượng động tác. Nó không chứa hình ảnh, video hay landmark tư thế thô. | When you explicitly request AI feedback or consent to automatic feedback, the app sends a workout summary to the server operated by the developer and to Google Gemini. The summary may contain rep count, duration, goal, and movement-quality metrics. It does not contain images, videos, or raw pose landmarks. |
| `privRetentionTitle` | Lưu giữ và xóa dữ liệu | Data retention and deletion |
| `privRetentionBody` | Lịch sử tập được giữ trên thiết bị cho đến khi bạn xóa trong ứng dụng, xóa dữ liệu ứng dụng trong cài đặt Android, hoặc gỡ cài đặt. Phiên bản này không tạo tài khoản người dùng. Bản tóm tắt gửi cho AI chỉ được xử lý để tạo phản hồi và không được máy chủ của ứng dụng lưu lại. | Workout history remains on your device until you delete it in the app, clear the app data in Android settings, or uninstall the app. The current version does not provide user accounts. AI workout summaries are processed solely to generate a response and are not stored by the app backend. |
| `privSecurityTitle` | Bảo mật và bên xử lý | Security and processors |
| `privSecurityBody` | Dữ liệu gửi đi để lấy nhận xét AI được truyền qua HTTPS. Google xử lý các yêu cầu Gemini theo điều khoản và chính sách quyền riêng tư hiện hành của họ. Hạ tầng Internet có thể xử lý thông tin kỹ thuật như địa chỉ IP trong quá trình cung cấp dịch vụ. | Data sent for AI feedback is transmitted over HTTPS. Google processes Gemini requests under its applicable terms and privacy policies. Internet infrastructure may process technical information such as IP addresses as part of delivering the service. |
| `privChildrenTitle` | Quyền riêng tư của trẻ em | Children and privacy |
| `privChildrenBody` | Ứng dụng không hướng đến trẻ em dưới 13 tuổi, và chúng tôi không cố ý thu thập thông tin cá nhân của trẻ em dưới 13 tuổi. | The app is not directed to children under 13, and we do not knowingly collect personal information from children under 13. |
| `privChoicesTitle` | Lựa chọn của bạn | Your choices |
| `privChoicesBody` | Bạn có thể dùng bộ đếm rep chạy trên thiết bị mà không cần yêu cầu nhận xét AI. Bạn có thể thu hồi quyền camera bất cứ lúc nào trong cài đặt Android và xóa lịch sử tập lưu trên máy ngay trong ứng dụng. | You can use the on-device rep counter without requesting AI feedback. You may revoke camera permission at any time in Android settings and delete locally stored workout history from within the app. |
| `privChangesTitle` | Thay đổi và liên hệ | Changes and contact |
| `privChangesBody` | Chính sách này có thể được cập nhật. Ngày hiệu lực ở trên cho biết bản sửa đổi mới nhất. Mọi câu hỏi về quyền riêng tư xin gửi về địa chỉ dưới đây. | We may update this policy. The effective date above identifies the latest revision. Send privacy questions to the address below. |
| `privContactTitle` — *phía dưới là tên nhà phát triển và email* | Liên hệ | Contact |

## Điều khoản sử dụng / Terms of use

| Khoá | Tiếng Việt | English |
|---|---|---|
| `termsOfUse` — *tiêu đề trang* | Điều khoản sử dụng | Terms of use |
| `legalEffective` — *nhãn ngày hiệu lực* | Có hiệu lực | Effective |
| `legalDate` — *ngày hiệu lực* | 05/09/2026 | September 5, 2026 |
| `termsIntroPrefix` — *mở đầu, ghép: tiền tố + tên app + hậu tố* | Khi sử dụng | By using |
| `termsIntroSuffix` | , bạn đồng ý với các điều khoản dưới đây. | , you agree to the terms below. |
| `termsPurposeTitle` | Mục đích | Purpose |
| `termsPurposeBody` | Ứng dụng giúp bạn theo dõi hoạt động thể dục và đưa ra phản hồi mang tính thông tin chung. | The app helps you track fitness activity and provides general informational feedback. |
| `termsNotMedicalTitle` | Không phải thiết bị y tế | Not a medical device |
| `termsNotMedicalBody` | RepCoach AI không đưa ra lời khuyên y tế và không chẩn đoán, điều trị, chữa khỏi hay phòng ngừa bất kỳ tình trạng y khoa nào. Số rep và nhận xét AI có thể không chính xác. | RepCoach AI does not provide medical advice and does not diagnose, treat, cure, or prevent any medical condition. Rep counts and AI feedback may be inaccurate. |
| `termsSafetyTitle` | Tập luyện an toàn | Exercise safety |
| `termsSafetyBody` | Dừng tập nếu bạn thấy đau, chóng mặt hoặc khó chịu bất thường. Hãy hỏi ý kiến chuyên gia y tế có chuyên môn trước khi bắt đầu một chương trình tập mới, nhất là khi bạn đang có chấn thương, bệnh nền hoặc đang mang thai. Đặt điện thoại chắc chắn và giữ khu vực tập thông thoáng. | Stop exercising if you experience pain, dizziness, or unusual discomfort. Consult a qualified healthcare professional before beginning a new exercise program, especially if you have an injury, a health condition, or are pregnant. Place your phone securely and keep the workout area clear. |
| `termsLiabilityTitle` | Giới hạn kỹ thuật | Technical limitations |
| `termsLiabilityBody` | Kết quả phụ thuộc góc máy, ánh sáng, hiệu năng thiết bị, trang phục và mức độ camera nhìn rõ cơ thể bạn. Bạn tự chịu trách nhiệm chọn bài tập và cường độ phù hợp. | Results depend on camera angle, lighting, device performance, clothing, and how clearly the camera can see your body. You are responsible for choosing an appropriate exercise and intensity. |
| `termsUseTitle` | Sử dụng hợp lệ | Acceptable use |
| `termsUseBody` | Bạn không được phá hoại dịch vụ, lạm dụng API, dịch ngược ứng dụng trái pháp luật, hoặc dùng ứng dụng cho mục đích trái pháp luật. | You must not disrupt the service, abuse its API, unlawfully reverse engineer the app, or use it for unlawful purposes. |
| `termsChangesTitle` | Tính khả dụng và thay đổi | Availability and changes |
| `termsChangesBody` | Các tính năng có thể thay đổi, bị gián đoạn hoặc ngừng cung cấp. Điều khoản có thể được cập nhật và ngày hiệu lực mới sẽ được công bố tại đây. | Features may change, be interrupted, or be discontinued. We may update these terms, and a new effective date will be published here. |
| `termsContactTitle` | Liên hệ | Contact |
| `termsContactBody` — *phía dưới là email* | Mọi câu hỏi về điều khoản xin gửi về địa chỉ dưới đây. | Questions about these terms may be sent to the address below. |

---

## Những chỗ cố ý dịch không sát chữ

1. **Ngày hiệu lực.** Bản tiếng Việt là `05/09/2026` (DD/MM/YYYY); người đọc tiếng Anh
   sẽ hiểu thành ngày 9 tháng 5. Bản tiếng Anh dùng hằng số riêng
   `LegalConfig.effectiveDateEn` = `September 5, 2026`. **Đổi ngày phải đổi cả hai hằng số.**

2. **"máy chủ do nhà phát triển vận hành"** → *"the server operated by the
   developer"*, không phải *"the developer's server"*. Nghĩa như nhau; tránh
   dấu nháy đơn phải escape trong chuỗi Dart.

3. **`privChangesBody` và `termsContactBody`** kết thúc bằng "địa chỉ dưới
   đây" / "the address below", còn trang web kết thúc bằng thẻ `<a>` mailto.
   `verify_policy_sync.py` bỏ qua hai đoạn này có chủ đích.
