
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../data/datasources/firestore_firebase_datasource.dart';
import '../../../data/repositories/patients_repository.dart';
import '../../../data/repositories/prescriptions_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {

  late final PatientsRepository patientsRepository;
  late final PrescriptionsRepository prescriptionsRepository;

  @override
  void initState() {
    super.initState();

    final datasource =
        FirestoreFirebaseDatasource(FirebaseFirestore.instance);

    patientsRepository = PatientsRepository(
      datasource: datasource,
    );

    prescriptionsRepository = PrescriptionsRepository(
      datasource: datasource,
      patientsRepository: patientsRepository,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Dashboard",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
