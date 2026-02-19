import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../models/order.dart';

class StorageService {
  StorageService(this._storage);

  final FirebaseStorage _storage;

  Future<String> _uploadBytes({
    required String path,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref().child(path);
    final result = await ref.putData(bytes);
    return result.ref.getDownloadURL();
  }

  Future<OrderAttachment> uploadOrderAttachment({
    required String orderId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ref = _storage
        .ref()
        .child('orders')
        .child(orderId)
        .child('${DateTime.now().millisecondsSinceEpoch}_$sanitizedName');
    final result = await ref.putData(bytes);
    final url = await result.ref.getDownloadURL();
    return OrderAttachment(name: fileName, url: url);
  }

  Future<String> uploadUserProfileImage({
    required String userId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return _uploadBytes(
      path:
          'users/$userId/profile/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName',
      bytes: bytes,
    );
  }

  Future<String> uploadBusinessLogo({
    required String businessId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return _uploadBytes(
      path:
          'businesses/$businessId/logo/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName',
      bytes: bytes,
    );
  }
}
