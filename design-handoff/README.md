# RepCoach AI — Design handoff

Thư mục này chứa toàn bộ thiết kế để code lại app bằng Flutter.

- `docs/DESIGN_HANDOFF.md` — **tài liệu chính cho coding agent** (tokens, code Dart theme, component spec, từng màn hình, routes, state machine, asset, accessibility).
- `design/*.dc.html` — file thiết kế gốc, mở trực tiếp bằng trình duyệt (cần `support.js` cùng thư mục, chạy qua local server: `npx serve design`).
  - `flow.dc.html` — prototype click-through toàn bộ flow.
  - `app-icon.dc.html` — icon chính thức (concept 2) + feature graphic Play.

Gợi ý prompt cho Codex:
> Đọc `design-handoff/docs/DESIGN_HANDOFF.md` và code app Flutter RepCoach AI đúng spec: bắt đầu từ `lib/theme/` (copy nguyên code Dart ở mục 3), sau đó widgets ở mục 4, rồi từng màn hình theo mục 5 và routes/state machine ở mục 6–7.
