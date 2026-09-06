import 'dart:typed_data';

/// Client-side mirror of the server's image checks, so a wrong file is rejected the moment
/// it is picked rather than after the record has already been saved. The server validates
/// the same rules again — this only moves the feedback to where the mistake happens.
const _maxImageBytes = 5 * 1024 * 1024;

class _SignaturePart {
  final int offset;
  final List<int> bytes;
  const _SignaturePart(this.offset, this.bytes);
}

/// Every part must match for the file to count as that format.
const _signatures = <String, List<_SignaturePart>>{
  'image/jpeg': [
    _SignaturePart(0, [0xFF, 0xD8, 0xFF]),
  ],
  'image/png': [
    _SignaturePart(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
  ],
  // RIFF is a generic container (also .wav, .avi), so the WEBP form marker decides.
  'image/webp': [
    _SignaturePart(0, [0x52, 0x49, 0x46, 0x46]), // "RIFF"
    _SignaturePart(8, [0x57, 0x45, 0x42, 0x50]), // "WEBP"
  ],
};

/// Content type derived from the file name; also decides which signature is expected.
String imageContentTypeFor(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Error message when [bytes] are not a valid image of [contentType], or null when acceptable.
String? validateImage(Uint8List bytes, String contentType) {
  if (bytes.isEmpty) return 'Fajl je prazan.';
  if (bytes.length > _maxImageBytes) return 'Slika ne smije biti veća od 5 MB.';

  final signature = _signatures[contentType];
  if (signature == null) return 'Dozvoljeni formati slike su JPEG, PNG i WebP.';

  for (final part in signature) {
    if (!_matchesAt(bytes, part.offset, part.bytes)) {
      return 'Sadržaj fajla ne odgovara prijavljenom formatu slike.';
    }
  }
  return null;
}

bool _matchesAt(Uint8List data, int offset, List<int> expected) {
  if (data.length < offset + expected.length) return false;
  for (var i = 0; i < expected.length; i++) {
    if (data[offset + i] != expected[i]) return false;
  }
  return true;
}
