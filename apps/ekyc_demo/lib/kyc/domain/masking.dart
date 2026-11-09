/// Masks all but the first two and last two characters, for showing a
/// document number back to the user without exposing it on screen
/// recordings or over-the-shoulder.
String maskMiddle(String value, {int visible = 2}) {
  if (value.length <= visible * 2) return '•' * value.length;
  return value.substring(0, visible) +
      '•' * (value.length - visible * 2) +
      value.substring(value.length - visible);
}
