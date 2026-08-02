import 'package:flutter/foundation.dart';

const Set<String> _imageExts = {
  'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'tif', 'heic', 'heif', 'ico', 'jfif', 'pnm', 'pgm', 'ppm',
};

const Set<String> _videoExts = {
  'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v', 'mpg', 'mpeg', 'wmv', 'flv', '3gp', 'ogv', 'ts', 'mts', 'm2ts',
};

@immutable
class MediaItem {
  final String path;
  final String name;
  final bool isVideo;
  final int sizeBytes;

  const MediaItem({
    required this.path,
    required this.name,
    required this.isVideo,
    required this.sizeBytes,
  });

  String get ext {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  static bool isVideoPath(String path) {
    final lower = path.toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot == -1) return false;
    return _videoExts.contains(lower.substring(dot + 1));
  }

  static bool isImagePath(String path) {
    final lower = path.toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot == -1) return false;
    return _imageExts.contains(lower.substring(dot + 1));
  }
}
