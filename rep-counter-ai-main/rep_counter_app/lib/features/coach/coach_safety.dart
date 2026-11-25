/// D-34 (DRAFT, pending legal/medical review): a message about pain or an
/// injury gets the fixed safety reply first (no diagnosis, see a
/// professional) and an optional no-load session, with no credit.
///
/// Backend gap (10 §stubs 4): `coach_chat` has no `safety` field and every
/// request is charged, so the intent is detected **on the phone** and no
/// request is sent. Anything this list misses still reaches the PT prompt,
/// which refuses to diagnose (L-D43).
abstract final class CoachSafety {
  static final _pain = RegExp(
    r"\b(pain|painful|hurts?|hurting|ache|aches|aching|sore\s+(joint|knee|back|shoulder|wrist)|"
    r"injur(y|ed|ies)|sprain(ed)?|strain(ed)?|swollen|swelling|numb(ness)?|tingling|dizzy|chest\s+tightness|"
    r"pulled\s+a\s+muscle|torn)\b"
    r"|đau|chấn thương|bị thương|bong gân|căng cơ|sưng|tê bì|tê tay|tê chân|chóng mặt|tức ngực|trật khớp|rách cơ",
    caseSensitive: false,
    unicode: true,
  );

  static bool isPain(String message) => _pain.hasMatch(message);
}
