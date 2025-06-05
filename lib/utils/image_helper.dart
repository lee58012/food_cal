import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class ImageHelper {
  static ImageProvider? getImageProvider(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    try {
      if (imageUrl.startsWith('data:image')) {
        // Base64 이미지 처리
        final base64Str = imageUrl.split(',')[1];
        final bytes = base64Decode(base64Str);
        return MemoryImage(bytes);
      } else if (imageUrl.startsWith('http')) {
        // 네트워크 이미지 처리
        return NetworkImage(imageUrl);
      } else {
        // 로컬 파일 이미지 처리
        final file = File(imageUrl);
        if (file.existsSync()) {
          return FileImage(file);
        }
      }
    } catch (e) {
      debugPrint('이미지 로딩 오류: $e');
    }

    return null;
  }

  static DecorationImage? getDecorationImage(String? imageUrl) {
    final provider = getImageProvider(imageUrl);
    if (provider == null) return null;

    return DecorationImage(image: provider, fit: BoxFit.cover);
  }

  static Widget buildImage(
    String? imageUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return errorWidget ?? const SizedBox();
    }

    try {
      if (imageUrl.startsWith('data:image')) {
        final base64Str = imageUrl.split(',')[1];
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              errorWidget ?? const Center(child: Text('이미지를 불러올 수 없습니다')),
        );
      } else if (imageUrl.startsWith('http')) {
        return Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              errorWidget ?? const Center(child: Text('이미지를 불러올 수 없습니다')),
        );
      } else {
        return Image.file(
          File(imageUrl),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              errorWidget ?? const Center(child: Text('이미지를 불러올 수 없습니다')),
        );
      }
    } catch (e) {
      debugPrint('이미지 로딩 오류: $e');
      return errorWidget ?? const Center(child: Text('이미지를 불러올 수 없습니다'));
    }
  }
}
