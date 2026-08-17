/// Pre-flight checks for a file picked in Creator Studio.
///
/// The server stays the authority: it re-decodes the upload at finalize and
/// refuses what it does not like. These checks run first only so the editor can
/// name the reason *before* spending a round trip on a frame it will refuse —
/// and so a refusal is never silent.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

/// Hero frame minimum, measured against the slots that actually render one.
///
/// Every banner slot — Home, the collection index, the phone login band, the
/// paywall strip — is a wide band between 1.9:1 and 4:1, and the render
/// endpoint never fetches wider than 2000px. 1600 matches the widest bucket a
/// phone asks for; 900 covers the tallest band with room to pan focalY.
const int kMinHeroPhotoWidth = 1600;
const int kMinHeroPhotoHeight = 900;

/// The desktop login is the one portrait slot: a left panel at 46% of the
/// window, full height, so a band lands there upscaled and cropped to a sliver.
/// Frames shorter than this may carry every other role, just not that one.
const int kMinLoginPhotoHeight = 1200;

/// The server's own bounds (backend/app/api/v1/endpoints/studio.py), mirrored
/// here so the reason arrives as a sentence instead of a 422.
const int kMinAssetSide = 320;
const int kMaxAssetSide = 6000;
const int kMaxAssetBytes = 12 * 1024 * 1024;

const Set<String> kAssetExtensions = {'jpg', 'jpeg', 'png', 'webp'};

class StudioImageSize {
  const StudioImageSize(this.width, this.height);

  final int width, height;

  @override
  String toString() => '$width×$height';
}

/// Decodes just enough of [bytes] to learn the frame size, or null when the
/// file is not an image this app can read.
Future<StudioImageSize?> probeImageSize(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = StudioImageSize(frame.image.width, frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return size;
  } catch (_) {
    return null;
  }
}

/// Why this file cannot be uploaded at all, in the author's words, or null.
String? assetRejection({
  required String fileName,
  required String? extension,
  required int sizeBytes,
  required Uint8List? bytes,
  required StudioImageSize? size,
}) {
  final kind = (extension ?? '').toLowerCase();
  if (!kAssetExtensions.contains(kind)) {
    return '«$fileName» не додано: підтримуються лише JPG, PNG і WebP'
        '${kind.isEmpty ? '' : ', а не .$kind'}.';
  }
  if (bytes == null) {
    return '«$fileName» не додано: не вдалося прочитати файл із диска. '
        'Скопіюйте його в іншу теку й спробуйте ще раз.';
  }
  if (sizeBytes > kMaxAssetBytes) {
    return '«$fileName» не додано: ${_megabytes(sizeBytes)} МБ — більше за '
        'ліміт ${kMaxAssetBytes ~/ (1024 * 1024)} МБ.';
  }
  if (size == null) {
    return '«$fileName» не додано: файл не вдалося прочитати як зображення. '
        'Найчастіше це HEIC або RAW із розширенням .jpg — перезбережіть кадр '
        'як JPEG, PNG чи WebP.';
  }
  final smallest = size.width < size.height ? size.width : size.height;
  final largest = size.width > size.height ? size.width : size.height;
  if (smallest < kMinAssetSide || largest > kMaxAssetSide) {
    return '«$fileName» не додано: $size — кожна сторона має бути від '
        '$kMinAssetSide до $kMaxAssetSide px.';
  }
  return null;
}

/// Why this file cannot become a hero frame, or null when it can. Avatars do
/// not go through this: they are cropped to a circle and need no master size.
String? heroFrameRejection({
  required String fileName,
  required StudioImageSize size,
}) {
  final shortWidth = size.width < kMinHeroPhotoWidth;
  final shortHeight = size.height < kMinHeroPhotoHeight;
  if (!shortWidth && !shortHeight) return null;
  final missing = [
    if (shortWidth) 'по ширині на ${kMinHeroPhotoWidth - size.width} px',
    if (shortHeight) 'по висоті на ${kMinHeroPhotoHeight - size.height} px',
  ].join(' і ');
  return '«$fileName» не додано як кадр: $size — менше за мінімум '
      '$kMinHeroPhotoWidth×$kMinHeroPhotoHeight ($missing). Банер тягнеться на '
      'всю ширину колонки, тож меншому кадру нема чим її закрити: візьміть '
      'вихідний файл більшої роздільності. Для аватара цей мінімум не діє.';
}

/// Why this frame cannot carry [role], or null when it can. Only the desktop
/// login asks for more than the upload minimum.
String? heroRoleRejection({
  required String role,
  required StudioImageSize size,
}) {
  if (role != 'login' || size.height >= kMinLoginPhotoHeight) return null;
  return 'Роль login не призначено: $size — на '
      '${kMinLoginPhotoHeight - size.height} px нижче за '
      '$kMinLoginPhotoHeight px. На широкому екрані логін показує кадр '
      'вертикальною панеллю на всю висоту, тож смугу там довелося б розтягнути '
      'і обрізати з боків. Решта ролей цьому кадру доступна.';
}

String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
