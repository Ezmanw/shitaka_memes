import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

img.Image generateCoolEmoji(int size) {
  final image = img.Image(width: size, height: size);

  // Background: Dark Lime (#141E0D)
  img.fill(image, color: img.ColorRgba8(20, 30, 13, 255));

  final cx = size ~/ 2;
  final cy = size ~/ 2;
  final radius = (size * 0.40).toInt();

  // 1. Draw Yellow Emoji Face Base (#FFC107 / #FFD54F)
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist <= radius) {
        final factor = (dist / radius).clamp(0.0, 1.0);
        final r = (255 - factor * 10).toInt();
        final g = (213 - factor * 50).toInt();
        final b = (79 - factor * 70).toInt();
        image.setPixel(x, y, img.ColorRgba8(r, g, b, 255));
      } else if (dist <= radius + 1.5) {
        image.setPixel(x, y, img.ColorRgba8(180, 120, 0, 255));
      }
    }
  }

  // 2. Draw Cool Sunglasses 😎
  final glassW = (size * 0.28).toInt();
  final glassH = (size * 0.18).toInt();
  final glassY1 = cy - (size * 0.16).toInt();
  final glassY2 = glassY1 + glassH;

  // Left Lens
  final leftX1 = cx - (size * 0.32).toInt();
  final leftX2 = leftX1 + glassW;
  img.fillRect(image, x1: leftX1, y1: glassY1, x2: leftX2, y2: glassY2, color: img.ColorRgba8(20, 20, 20, 255));

  // Right Lens
  final rightX1 = cx + (size * 0.04).toInt();
  final rightX2 = rightX1 + glassW;
  img.fillRect(image, x1: rightX1, y1: glassY1, x2: rightX2, y2: glassY2, color: img.ColorRgba8(20, 20, 20, 255));

  // Sunglasses Bridge
  img.fillRect(image, x1: leftX2, y1: glassY1 + 2, x2: rightX1, y2: glassY1 + (size * 0.06).toInt(), color: img.ColorRgba8(20, 20, 20, 255));

  // Lens Glare Highlights
  final shineW = math.max(2, size ~/ 32);
  img.drawLine(image, x1: leftX1 + 4, y1: glassY1 + 4, x2: leftX1 + (glassW ~/ 2), y2: glassY2 - 4, color: img.ColorRgba8(255, 255, 255, 200), thickness: shineW);
  img.drawLine(image, x1: rightX1 + 4, y1: glassY1 + 4, x2: rightX1 + (glassW ~/ 2), y2: glassY2 - 4, color: img.ColorRgba8(255, 255, 255, 200), thickness: shineW);

  // 3. Draw Cool Smirk / Smile 😁
  final smileRadius = (size * 0.20).toInt();
  final smileCY = cy + (size * 0.08).toInt();
  final thick = math.max(2, size ~/ 36);

  for (int y = smileCY; y <= smileCY + smileRadius; y++) {
    for (int x = cx - smileRadius; x <= cx + smileRadius; x++) {
      final dx = x - cx;
      final dy = y - smileCY;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist >= smileRadius - thick && dist <= smileRadius) {
        image.setPixel(x, y, img.ColorRgba8(20, 20, 20, 255));
      }
    }
  }

  return image;
}

void main() {
  final sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in sizes.entries) {
    final dir = Directory('android/app/src/main/res/${entry.key}');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final image = generateCoolEmoji(entry.value);
    final png = img.encodePng(image);
    File('${dir.path}/ic_launcher.png').writeAsBytesSync(png);
  }

  // Generate Windows app_icon.ico
  final icoDir = Directory('windows/runner/resources');
  if (!icoDir.existsSync()) {
    icoDir.createSync(recursive: true);
  }

  final icoImage = generateCoolEmoji(256);
  final icoPng = img.encodePng(icoImage);
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(icoPng);

  print('Generated Android and Windows Cool Sunglasses Emoji 😎 icons successfully!');
}
