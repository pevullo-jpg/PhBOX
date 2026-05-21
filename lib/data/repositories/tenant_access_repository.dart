import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tenant_access.dart';

class TenantAccessRepository {
  final FirebaseFirestore firestore;

  const TenantAccessRepository({required this.firestore});

  Future<TenantAccess?> getForLoginEmail(String email) async {
    final String normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection('tenant_access')
        .doc(normalizedEmail)
        .get();
    final Map<String, dynamic>? data = snapshot.data();
    if (data == null) {
      return null;
    }
    return TenantAccess.fromMap(snapshot.id, data);
  }
}
