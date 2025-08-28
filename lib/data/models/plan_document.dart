// lib/data/models/plan_document.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PlanDocument {
  final String? studyPacing;
  final String? longTermStrategy;
  final Map<String, dynamic>? weeklyPlan;

  PlanDocument({this.studyPacing, this.longTermStrategy, this.weeklyPlan});

  factory PlanDocument.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return PlanDocument(
      studyPacing: data['studyPacing'],
      longTermStrategy: data['longTermStrategy'],
      weeklyPlan: data['weeklyPlan'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() => {
    'studyPacing': studyPacing,
    'longTermStrategy': longTermStrategy,
    'weeklyPlan': weeklyPlan,
  };
}

