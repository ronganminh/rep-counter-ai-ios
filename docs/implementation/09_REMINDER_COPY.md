# 09 — NT-2 friendly reminder lines (layer 1)

Decision **L-D44**. These are the 54 lines of the ARB catalog (`lib/l10n/app_en.arb` / `app_vi.arb`, keys `reminderNudge…`; the Final C handoff copies are byte-identical). The owner reviews them here. To change a line, edit both ARB files (app and handoff) and run `flutter gen-l10n`; the tests in `test/features/plan/reminder_copy_test.dart` re-check every line.

Variables: `{name}` (only when a name is known), `{exercise}` (the session's first exercise), `{time}` (reminder time), `{streak}` (days in a row), `{sets}` (sets in the session).

VI: the exercise name is written in lower case inside a sentence ("Khởi động rồi hít đất") and keeps its capital at the start of the line or after `.`/`!`/`?` ("Hít đất đang chờ bạn…"); `ReminderCopy.text` does this, the ARB strings are unchanged. EN keeps the name as it is.

Rules, enforced by tests:
- one line of at most 110 characters, so it fits in 2 lines on a phone;
- at most 1 emoji;
- no blame words and no hurrying;
- every variable is filled.

Which situation applies:
- The next reminder can be "first session" (the plan has started nothing yet), then "streak" (7+ days in a row), then "after missed" (the last past session was missed or skipped).
- Every other reminder is "weekend" (Sat/Sun), "evening" (18:00 or later) or "regular".

The same line is never used twice within 14 days.

| Key | Situation | EN | VI |
|---|---|---|---|
| reminderNudgeRegular01 | regular | {exercise} is waiting for you at {time}. A few easy sets and you're done. | {exercise} đang chờ bạn lúc {time}. Vài set nhẹ nhàng là xong. |
| reminderNudgeRegular02 | regular | Today's plan: {sets} sets. Start whenever you're ready. | Kế hoạch hôm nay: {sets} set. Bắt đầu khi bạn sẵn sàng nhé. |
| reminderNudgeRegular03 | regular | Your session is on for today. Warm up, then {exercise} first. | Hôm nay có buổi tập. Khởi động rồi vào {exercise} trước nhé. |
| reminderNudgeRegular04 | regular | A little movement today keeps the habit going. See you at {time}. | Vận động một chút hôm nay để giữ thói quen. Hẹn bạn lúc {time}. |
| reminderNudgeRegular05 | regular | Ready when you are: {sets} sets of good, steady reps. | Khi nào bạn sẵn sàng thì mình bắt đầu: {sets} set, từng rep chắc chắn. |
| reminderNudgeRegular06 | regular | Small session, real progress. {exercise} is first up. | Buổi tập nhỏ, tiến bộ thật. Mở đầu bằng {exercise}. |
| reminderNudgeRegular07 | regular | Time for today's training. Go at your own pace. | Đến giờ tập hôm nay rồi. Cứ theo nhịp của bạn. |
| reminderNudgeRegular08 | regular | {name}, your plan has a session for you today. | {name} ơi, kế hoạch hôm nay có một buổi tập cho bạn. |
| reminderNudgeRegular09 | regular | Set the phone up, step back, and let's count some reps. | Dựng điện thoại, lùi lại một chút, mình cùng đếm rep nào. |
| reminderNudgeRegular10 | regular | Today: {exercise} and more. Quality over speed. | Hôm nay: {exercise} và vài bài nữa. Chậm mà chắc. |
| reminderNudgeRegular11 | regular | One session closer to your goal, whenever you're ready. | Thêm một buổi là gần mục tiêu hơn. Khi nào sẵn sàng thì tập nhé. |
| reminderNudgeRegular12 | regular | Your {sets}-set session is ready. Short breaks, steady form. | Buổi {sets} set đã sẵn sàng. Nghỉ ngắn, giữ form đều. |
| reminderNudgeRegular13 | regular | {name}, a few good sets today will feel great later. | {name}, vài set tốt hôm nay, lát nữa sẽ thấy thật dễ chịu. |
| reminderNudgeRegular14 | regular | Training day. Start with {exercise} and see how it feels. | Ngày tập đây. Bắt đầu với {exercise} rồi cảm nhận nhé. |
| reminderNudgeAfterMissed01 | afterMissed | Welcome back! Today is a fresh start, no catching up needed. | Chào mừng trở lại! Hôm nay là khởi đầu mới, không cần bù gì cả. |
| reminderNudgeAfterMissed02 | afterMissed | Life gets busy. A short session today is a great way back in. | Ai cũng có lúc bận. Một buổi ngắn hôm nay là cách quay lại thật tốt. |
| reminderNudgeAfterMissed03 | afterMissed | Start from where you are. {exercise} at an easy pace is plenty. | Bắt đầu lại từ chỗ bạn đang đứng. {exercise} nhịp nhẹ là đủ rồi. |
| reminderNudgeAfterMissed04 | afterMissed | No pressure: even a few reps today count. | Không áp lực đâu: hôm nay vài rep cũng đáng kể. |
| reminderNudgeAfterMissed05 | afterMissed | Your plan is still here for you. Ready at {time}? | Kế hoạch vẫn ở đây chờ bạn. Sẵn sàng lúc {time} chứ? |
| reminderNudgeAfterMissed06 | afterMissed | {name}, good to have you back. Let's keep it light today. | {name}, vui vì bạn quay lại. Hôm nay tập nhẹ thôi nhé. |
| reminderNudgeAfterMissed07 | afterMissed | Every comeback starts with one set. Today is a good day for it. | Mọi lần quay lại đều bắt đầu từ một set. Hôm nay là ngày đẹp để bắt đầu. |
| reminderNudgeAfterMissed08 | afterMissed | Easy does it: warm up well and go at your own pace. | Từ từ thôi: khởi động kỹ và tập theo nhịp của bạn. |
| reminderNudgeStreak01 | streak | {streak} days in a row. Nice rhythm! Keep it easy and steady. | {streak} ngày liên tiếp. Nhịp tốt lắm! Cứ đều đặn, nhẹ nhàng. |
| reminderNudgeStreak02 | streak | Your streak is at {streak} days 🔥 Today's session keeps it going. | Chuỗi của bạn đã {streak} ngày 🔥 Buổi hôm nay giữ nhịp tiếp. |
| reminderNudgeStreak03 | streak | {streak} days of showing up. That's how habits are built. | {streak} ngày đều đặn. Thói quen được xây như thế đấy. |
| reminderNudgeStreak04 | streak | Great consistency: {streak} days. Listen to your body today. | Đều đặn tuyệt vời: {streak} ngày. Hôm nay nhớ lắng nghe cơ thể nhé. |
| reminderNudgeStreak05 | streak | {name}, {streak} days strong. One more good session today? | {name}, {streak} ngày bền bỉ. Thêm một buổi tốt hôm nay nhé? |
| reminderNudgeStreak06 | streak | Day {streak}! Steady form beats fast reps. | Ngày thứ {streak}! Form đều quan trọng hơn rep nhanh. |
| reminderNudgeStreak07 | streak | {streak} days and counting. A rest day is fine too when you need it. | {streak} ngày và vẫn tiếp tục. Cần nghỉ thì cứ nghỉ, không sao cả. |
| reminderNudgeStreak08 | streak | {streak} days in a row says it all. See you at {time}. | Chuỗi {streak} ngày đã nói lên tất cả. Hẹn bạn lúc {time}. |
| reminderNudgeWeekend01 | weekend | Weekend session! A relaxed {sets} sets whenever suits you. | Buổi tập cuối tuần! {sets} set thoải mái, lúc nào tiện thì tập. |
| reminderNudgeWeekend02 | weekend | A weekend workout fits nicely between plans. Ready at {time}? | Buổi tập cuối tuần chen giữa các cuộc vui thật vừa. Sẵn sàng lúc {time} chứ? |
| reminderNudgeWeekend03 | weekend | Slow weekend morning or busy afternoon, {exercise} fits in. | Sáng cuối tuần thong thả hay chiều bận rộn, {exercise} vẫn vừa vặn. |
| reminderNudgeWeekend04 | weekend | Weekend energy: a few good sets, then enjoy your day. | Năng lượng cuối tuần: vài set tốt rồi tận hưởng ngày nghỉ. |
| reminderNudgeWeekend05 | weekend | {name}, a quick weekend session and the rest of the day is yours. | {name}, một buổi ngắn cuối tuần rồi cả ngày là của bạn. |
| reminderNudgeWeekend06 | weekend | No rush this weekend. Your session is ready when you are. | Cuối tuần không vội. Buổi tập sẵn sàng khi bạn sẵn sàng. |
| reminderNudgeWeekend07 | weekend | Weekend check-in: {exercise} first, then take it easy. | Điểm danh cuối tuần: {exercise} trước, rồi thư giãn nhé. |
| reminderNudgeWeekend08 | weekend | End the week on a good note with today's session. | Khép lại tuần thật đẹp với buổi tập hôm nay. |
| reminderNudgeEvening01 | evening | Evening session at {time}. Keep it calm and controlled. | Buổi tập tối lúc {time}. Giữ nhịp bình tĩnh và có kiểm soát. |
| reminderNudgeEvening02 | evening | Wind down the day with {sets} steady sets. | Khép lại ngày với {sets} set đều đặn. |
| reminderNudgeEvening03 | evening | A short evening workout, then time to relax. | Một buổi tập tối ngắn, rồi thư giãn thôi. |
| reminderNudgeEvening04 | evening | Evening reps: smooth and steady, no need to push hard. | Rep buổi tối: nhẹ nhàng, đều đặn, không cần cố quá. |
| reminderNudgeEvening05 | evening | {name}, a few sets tonight and today's plan is done. | {name}, vài set tối nay là xong kế hoạch hôm nay. |
| reminderNudgeEvening06 | evening | Tonight's session is ready. {exercise} first, at your pace. | Buổi tập tối nay đã sẵn sàng. {exercise} trước, theo nhịp của bạn. |
| reminderNudgeEvening07 | evening | Good evening! Today's session fits before or after dinner. | Chào buổi tối! Buổi tập hôm nay vừa trước hoặc sau bữa tối. |
| reminderNudgeEvening08 | evening | Finish the day strong, then get some good rest. | Kết thúc ngày thật khoẻ, rồi nghỉ ngơi thật tốt. |
| reminderNudgeFirstSession01 | firstSession | Your plan starts today. Let's begin with {exercise}! | Kế hoạch bắt đầu từ hôm nay. Mình mở đầu với {exercise} nhé! |
| reminderNudgeFirstSession02 | firstSession | Day one! Go easy, learn the moves, and enjoy it. | Ngày đầu tiên! Tập nhẹ, làm quen động tác và tận hưởng nhé. |
| reminderNudgeFirstSession03 | firstSession | First session: {sets} sets. Focus on good form, not speed. | Buổi đầu: {sets} set. Tập trung vào form đúng, không cần nhanh. |
| reminderNudgeFirstSession04 | firstSession | Welcome to your new plan. See you at {time}. | Chào mừng bạn đến với kế hoạch mới. Hẹn bạn lúc {time}. |
| reminderNudgeFirstSession05 | firstSession | {name}, your first planned session is today. You've got this. | {name}, hôm nay là buổi đầu tiên trong kế hoạch. Bạn làm được mà. |
| reminderNudgeFirstSession06 | firstSession | New plan, fresh start. Set up the phone and let's count. | Kế hoạch mới, khởi đầu mới. Dựng điện thoại lên rồi đếm thôi. |
| reminderNudgeFirstSession07 | firstSession | The first session is the start of a habit. Take it slow. | Buổi đầu tiên là khởi đầu của một thói quen. Cứ từ từ. |
| reminderNudgeFirstSession08 | firstSession | Today is day one. Warm up, then {exercise} at your own pace. | Hôm nay là ngày đầu. Khởi động rồi {exercise} theo nhịp của bạn. |
