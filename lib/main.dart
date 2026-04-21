import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: "AIzaSyBSJoTKtjoLTT-Q8Q5iAWmtERyavIINjLs",
        authDomain: "phbox-369e8.firebaseapp.com",
        projectId: "phbox-369e8",
        storageBucket: "phbox-369e8.firebasestorage.app",
        messagingSenderId: "829413724215",
        appId: "1:829413724215:web:8401e651b56b98f30fefb2",
        measurementId: "G-VF8E5DQRCZ"),
  );

  runApp(const FarmaciaApp());
}
