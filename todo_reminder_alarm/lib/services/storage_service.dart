import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../models/order.dart';

class StorageService {
  StorageService(this._storage);

  final FirebaseStorage _storage;
  static const int _imageQuality = 75;
  static const int _maxDimension = 1800;

  Future<String> _uploadImage({
    required String directory,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final normalizedFile = await _prepareImage(fileName: fileName, bytes: bytes);
    final path =
        '$directory/${DateTime.now().millisecondsSinceEpoch}_${normalizedFile.fileName}';
    final ref = _storage.ref().child(path);
    final result = await ref.putData(
      normalizedFile.bytes,
      SettableMetadata(contentType: normalizedFile.contentType),
    );
    return result.ref.getDownloadURL();
  }

  Future<OrderAttachment> uploadOrderAttachment({
    required String orderId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final url = await _uploadImage(
      directory: 'orders/$orderId',
      fileName: fileName,
      bytes: bytes,
    );
    return OrderAttachment(name: fileName, url: url);
  }

  Future<String> uploadUserProfileImage({
    required String userId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    return _uploadImage(
      directory: 'users/$userId/profile',
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<String> uploadBusinessLogo({
    required String businessId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    return _uploadImage(
      directory: 'businesses/$businessId/logo',
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<String> uploadCatalogImage({
    required String businessId,
    required String productId,
    String? variantId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final directory = variantId == null || variantId.isEmpty
        ? 'catalog/$businessId/products/$productId'
        : 'catalog/$businessId/products/$productId/variants/$variantId';
    return _uploadImage(
      directory: directory,
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<OrderAttachment> uploadSupportTicketAttachment({
    required String userId,
    required String ticketId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final url = await _uploadImage(
      directory: 'support/$userId/$ticketId',
      fileName: fileName,
      bytes: bytes,
    );
    return OrderAttachment(name: fileName, url: url);
  }

  Future<_PreparedImage> _prepareImage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final sanitizedName = _sanitizeFileName(fileName);
    final extension = _extensionOf(sanitizedName);
    final format = _compressFormatFor(extension);
    final targetExtension = _targetExtensionFor(extension, format);
    final normalizedName = _replaceExtension(sanitizedName, targetExtension);

    if (format == null) {
      return _PreparedImage(
        fileName: normalizedName,
        bytes: bytes,
        contentType: _contentTypeForExtension(targetExtension),
      );
    }

    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      format: format,
      quality: _imageQuality,
      minWidth: _maxDimension,
      minHeight: _maxDimension,
      keepExif: false,
    );

    return _PreparedImage(
      fileName: normalizedName,
      bytes: compressed.isEmpty ? bytes : Uint8List.fromList(compressed),
      contentType: _contentTypeForExtension(targetExtension),
    );
  }

  String _sanitizeFileName(String fileName) {
    final trimmed = fileName.trim().isEmpty ? 'image.jpg' : fileName.trim();
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'jpg';
    return fileName.substring(dot + 1).toLowerCase();
  }

  CompressFormat? _compressFormatFor(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return CompressFormat.jpeg;
      case 'png':
        return CompressFormat.png;
      case 'webp':
        return CompressFormat.webp;
      case 'heic':
      case 'heif':
        return CompressFormat.heic;
      case 'gif':
      case 'svg':
        return null;
      default:
        return CompressFormat.jpeg;
    }
  }

  String _targetExtensionFor(String originalExtension, CompressFormat? format) {
    if (format == null) return originalExtension;
    switch (format) {
      case CompressFormat.jpeg:
        return 'jpg';
      case CompressFormat.png:
        return 'png';
      case CompressFormat.webp:
        return 'webp';
      case CompressFormat.heic:
        return 'heic';
    }
  }

  String _replaceExtension(String fileName, String extension) {
    final dot = fileName.lastIndexOf('.');
    final baseName = dot == -1 ? fileName : fileName.substring(0, dot);
    return '$baseName.$extension';
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'gif':
        return 'image/gif';
      case 'svg':
        return 'image/svg+xml';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}

class _PreparedImage {
  const _PreparedImage({
    required this.fileName,
    required this.bytes,
    required this.contentType,
  });

  final String fileName;
  final Uint8List bytes;
  final String contentType;
}
