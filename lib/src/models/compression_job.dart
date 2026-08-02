import 'package:flutter/foundation.dart';

@immutable
class CompressionJob {
  final String fileName;
  final bool isVideo;
  final int inputBytes;
  final int outputBytes;
  final int targetBytes;
  final bool success;
  final String? error;
  final String? outputPath;
  final DateTime timestamp;

  const CompressionJob({
    required this.fileName,
    required this.isVideo,
    required this.inputBytes,
    required this.outputBytes,
    required this.targetBytes,
    required this.success,
    this.error,
    this.outputPath,
    required this.timestamp,
  });

  double get reductionRatio {
    if (inputBytes <= 0) return 0;
    return 1 - (outputBytes / inputBytes);
  }

  int get reductionPercent {
    if (inputBytes <= 0) return 0;
    return ((1 - outputBytes / inputBytes) * 100).round().clamp(0, 100);
  }

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'isVideo': isVideo,
        'inputBytes': inputBytes,
        'outputBytes': outputBytes,
        'targetBytes': targetBytes,
        'success': success,
        'error': error,
        'outputPath': outputPath,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CompressionJob.fromJson(Map<String, dynamic> json) => CompressionJob(
        fileName: json['fileName'] as String? ?? 'unknown',
        isVideo: json['isVideo'] as bool? ?? false,
        inputBytes: json['inputBytes'] as int? ?? 0,
        outputBytes: json['outputBytes'] as int? ?? 0,
        targetBytes: json['targetBytes'] as int? ?? 2048,
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
        outputPath: json['outputPath'] as String?,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}
