import 'dart:io';
import 'package:image/image.dart' as img;

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

    final size = entry.value;
    final image = img.Image(width: size, height: size);

    // Dark lime background
    img.fill(image, color: img.ColorRgba8(20, 30, 13, 255));

    // Outer Lime Ring
    final radius = (size * 0.42).toInt();
    final center = size ~/ 2;

    for (int r = radius - 3; r <= radius; r++) {
      img.drawCircle(image, x: center, y: center, radius: r, color: img.ColorRgba8(139, 195, 74, 255));
    }

    // Inner Compressor vise icon
    final barW = size ~/ 4;
    img.fillRect(image, x1: center - barW, y1: center - (size ~/ 4), x2: center + barW, y2: center - (size ~/ 7), color: img.ColorRgba8(255, 255, 255, 255));
    img.fillRect(image, x1: center - (barW ~/ 2), y1: center - (size ~/ 8), x2: center + (barW ~/ 2), y2: center + (size ~/ 8), color: img.ColorRgba8(139, 195, 74, 255));
    img.fillRect(image, x1: center - barW, y1: center + (size ~/ 7), x2: center + barW, y2: center + (size ~/ 4), color: img.ColorRgba8(255, 255, 255, 255));

    final png = img.encodePng(image);
    File('${dir.path}/ic_launcher.png').writeAsBytesSync(png);
    print('Generated ${dir.path}/ic_launcher.png (${size}x${size})');
  }
}
