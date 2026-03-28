String usernameKeyFromInput(String input) {
  var v = input.trim().toLowerCase();

  // Replace anything unsafe for a Firestore doc id with '_'.
  // (Firestore doc ids cannot contain '/'; we also keep it simple.)
  v = v.replaceAll(RegExp(r'[^a-z0-9._-]+'), '_');

  // Trim separators and collapse repeated underscores.
  v = v.replaceAll(RegExp(r'_+'), '_');
  v = v.replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');

  // Enforce length.
  if (v.length > 32) v = v.substring(0, 32);
  return v;
}
