import '../models/patient.dart';
import '../models/treatment_session.dart';
import '../core/enums.dart';

class AiInsight {
  final String title;
  final String message;
  final String severity; // info | warn | critical
  AiInsight(this.title, this.message, {this.severity = 'info'});
}

class AiInsightsService {
  // Medicine safety checks based on patient flags/history
  List<AiInsight> checkPrescriptionSafety(Patient p, List<PrescriptionItem> items) {
    final out = <AiInsight>[];
    final meds = items.map((e) => e.medicine.toLowerCase()).toList();
    bool contains(String keyword) => meds.any((m) => m.contains(keyword));

    if (p.breastfeeding) {
      if (contains('metronidazole')) {
        out.add(AiInsight('Breastfeeding caution', 'Metronidazole is generally not recommended during breastfeeding. Consider alternatives or counsel on timing of feeds.', severity: 'warn'));
      }
    }
    if (p.pregnant) {
      if (contains('ibuprofen') || contains('nsaid')) {
        out.add(AiInsight('Pregnancy contraindication', 'Avoid NSAIDs like Ibuprofen during pregnancy, especially in 3rd trimester. Prefer Paracetamol for analgesia.', severity: 'critical'));
      }
      if (contains('tetracycline')) {
        out.add(AiInsight('Pregnancy contraindication', 'Tetracyclines are contraindicated in pregnancy due to effects on fetal teeth/bone.', severity: 'critical'));
      }
    }
    // Allergy checks
    for (final a in p.drugAllergies) {
      final aLower = a.toLowerCase();
      if (aLower.contains('penicillin') && (contains('amoxicillin') || contains('penicillin'))) {
        out.add(AiInsight('Allergy risk', 'Patient has Penicillin allergy. Avoid Amoxicillin/Penicillin class antibiotics.', severity: 'critical'));
      }
      if (aLower.contains('nsaid') && (contains('ibuprofen') || contains('diclofenac') || contains('ketorolac'))) {
        out.add(AiInsight('Allergy risk', 'Patient reports NSAID allergy. Avoid Ibuprofen/Diclofenac/Ketorolac.', severity: 'critical'));
      }
    }
    return out;
  }

  // Prioritize treatments based on findings (very lightweight heuristics)
  List<AiInsight> prioritizePlans(TreatmentSession session) {
    final out = <AiInsight>[];
    // If oral findings include swelling or severe pain, prioritize RCT/extraction
    final findings = [
      ...session.oralExamFindings.map((f) => f.finding.toLowerCase()),
      ...session.rootCanalFindings.map((f) => f.finding.toLowerCase()),
      ...session.prosthodonticFindings.map((f) => f.finding.toLowerCase()),
    ];
    bool has(String s) => findings.any((f) => f.contains(s));
    if (has('swelling') || has('severe') || has('acute pain')) {
      out.add(AiInsight('Priority care', 'Acute symptoms detected. Prioritize pain relief and pulpal therapy (RCT) or extraction as indicated.', severity: 'warn'));
    }
    if (has('generalized stains') || has('deposits')) {
      out.add(AiInsight('Preventive care', 'Consider early scaling/prophylaxis and oral hygiene reinforcement.', severity: 'info'));
    }
    return out;
  }

  // Simple analytics: counts in last 30 days
  Map<String, int> recentProcedureCounts(Patient p, {int days = 30}) {
    final since = DateTime.now().subtract(Duration(days: days));
    int rct = 0, extraction = 0, fillings = 0, ortho = 0, prostho = 0;
    for (final s in p.sessions) {
      if (s.date.isBefore(since)) continue;
      switch (s.type) {
        case TreatmentType.rootCanal:
          rct++;
          break;
        case TreatmentType.orthodontic:
          ortho++;
          break;
        case TreatmentType.prosthodontic:
          prostho++;
          break;
        case TreatmentType.general:
          if (s.treatmentDoneOptions.any((t) => t.toLowerCase().contains('extraction'))) extraction++;
          if (s.treatmentDoneOptions.any((t) => t.toLowerCase().contains('filling'))) fillings++;
          break;
        case TreatmentType.labWork:
          break;
      }
    }
    return {
      'rct': rct,
      'extraction': extraction,
      'fillings': fillings,
      'orthodontic': ortho,
      'prosthodontic': prostho,
    };
  }
}
