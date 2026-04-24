import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {

  final FirebaseFirestore firestore;

  FirestoreService({FirebaseFirestore? instance})
      : firestore = instance ?? FirebaseFirestore.instance;

}