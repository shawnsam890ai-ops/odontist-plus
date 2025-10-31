import '../models/patient.dart';
import '../models/treatment_session.dart';
import '../core/enums.dart';

class AiInsight {
  final String title;
  final String message;
  final String severity; // info | warn | critical
  AiInsight(this.title, this.message, {this.severity = 'info'});
}

class ContraindicationResult {
  final String message; // short red banner message
  final String details; // brief reason and source notes
  const ContraindicationResult(this.message, {this.details = ''});
}

class AiInsightsService {

  /// Returns a short contraindication result for a single medicine against
  /// the patient's allergies/history/active meds. Null when no clear stop.
  /// This is a conservative surface check and does NOT replace clinical judgment.
  ContraindicationResult? contraindicationFor(Patient p, String medicine) {
    final m = medicine.toLowerCase();
    bool any(List<String> list, List<String> keys) =>
        list.map((e) => e.toLowerCase()).any((h) => keys.any((k) => h.contains(k)));

    // Helpers for drug families
    bool isNSAID() => ['ibuprofen','diclofenac','ketorolac','piroxicam','nimesulide','mefenamic','etoricoxib','aceclofenac'].any(m.contains);
    bool isPenicillin() => ['amoxicillin','penicillin','amoxycillin'].any(m.contains);
    bool isCephalosporin() => ['cef','cefixime','cefdinir','ceftriax','cephal'].any(m.contains);
    bool isFluoroquinolone() => ['ofloxacin','ciprofloxacin','levofloxacin','moxifloxacin'].any(m.contains);
    bool isNitroimidazole() => ['metronidazole','ornidazole','tinidazole'].any(m.contains);
    bool isOpioid() => ['tramadol','codeine'].any(m.contains);
    bool isPPI() => ['omeprazole','esomeprazole','pantoprazole','rabeprazole','lansoprazole'].any(m.contains);

    // Allergies
    final allergies = p.drugAllergies.map((e) => e.toLowerCase()).toList();
    if (allergies.any((a) => a.contains('penicillin')) && (isPenicillin() || m.contains('clavulan'))) {
      return const ContraindicationResult(
        'Current medication is contraindicated (penicillin allergy).',
        details: 'Beta-lactam cross-reactivity. Refer: FDA labeling; WHO ATC allergy cautions.',
      );
    }
    // Check for NSAID class allergy OR specific NSAID drug allergies
    if (isNSAID() && (allergies.any((a) => a.contains('nsaid')) || allergies.any((a) => m.contains(a)))) {
      return const ContraindicationResult(
        'Current medication is contraindicated (NSAID allergy).',
        details: 'Risk of hypersensitivity reactions. Refer: FDA NSAID class labeling.',
      );
    }
    if (allergies.any((a) => a.contains('ceph')) && isCephalosporin()) {
      return const ContraindicationResult(
        'Current medication is contraindicated (cephalosporin allergy).',
        details: 'Cross-reactivity within beta-lactams. Refer: FDA cephalosporin labeling.',
      );
    }
    // General check: if patient allergic to specific drug and medicine contains that exact drug
    for (final allergy in allergies) {
      if (allergy.isNotEmpty && m.contains(allergy.trim())) {
        return ContraindicationResult(
          'Current medication is contraindicated (allergy to ${allergy.trim()}).',
          details: 'Patient has documented allergy to this medication. Review allergy details and select alternative.',
        );
      }
    }

    // Past medical/dental history keywords
    final history = [...p.pastMedicalHistory, ...p.pastDentalHistory].map((e)=>e.toLowerCase()).toList();
    bool has(List<String> keys) => history.any((h) => keys.any((k) => h.contains(k)));

    // Renal disease vs NSAIDs and some antibiotics
    if (has(['ckd','chronic kidney','renal failure','kidney disease']) && isNSAID()) {
      return const ContraindicationResult(
        'Current medication is contraindicated in CKD/renal disease (NSAID).',
        details: 'NSAIDs reduce renal perfusion; AKI risk. Refer: FDA NSAID warning; NICE CKD guidance.',
      );
    }
    // Peptic ulcer / gastritis vs NSAIDs
    if (has(['peptic ulcer','pud','gastric ulcer','gastritis','gi bleed']) && isNSAID()) {
      return const ContraindicationResult(
        'Current medication is contraindicated in ulcer/gastritis (NSAID).',
        details: 'GI bleeding/perforation risk. Refer: FDA NSAID boxed warning; NICE CKS dyspepsia/ulcer.',
      );
    }
    // Severe liver disease vs hepatotoxic agents
    if (has(['cirrhosis','severe liver','hepatic failure','hepatitis']) && (m.contains('nimesulide') || isNitroimidazole())) {
      return const ContraindicationResult(
        'Current medication is contraindicated in severe hepatic impairment.',
        details: 'Hepatotoxicity/altered metabolism. Refer: DrugBank/NICE monographs for nimesulide/nitroimidazoles.',
      );
    }

    // Pregnancy/breastfeeding flags
    if (p.pregnant && (isNSAID() || isFluoroquinolone())) {
      return const ContraindicationResult(
        'Current medication is contraindicated in pregnancy.',
        details: 'NSAIDs (ductus closure in late gestation); fluoroquinolones (cartilage toxicity). Refer: FDA pregnancy labeling.',
      );
    }
    if (p.breastfeeding && isNitroimidazole()) {
      return const ContraindicationResult(
        'Current medication may be contraindicated during breastfeeding.',
        details: 'Metronidazole/ornidazole excreted in milk; consider timing/alternatives. Refer: LactMed/FDA.',
      );
    }

    // QT risk with domperidone/fluoroquinolones in cardiac history
    if (has(['long qt','arrhythmia','heart failure']) && (m.contains('domperidone') || isFluoroquinolone())) {
      return const ContraindicationResult(
        'Current medication is contraindicated with QT/arrhythmia risk.',
        details: 'Domperidone/fluoroquinolones prolong QT. Refer: EMA/FDA safety communications.',
      );
    }

    // Opioid cautions in seizure disorder
    if (has(['seizure','epilep']) && isOpioid()) {
      return const ContraindicationResult(
        'Current medication is contraindicated in seizure disorder (opioid).',
        details: 'Tramadol lowers seizure threshold. Refer: FDA tramadol labeling.',
      );
    }

    // ---- Interactions with current medications (bleeding risk / dual therapy) ----
    final meds = p.currentMedications.map((e)=> e.toLowerCase()).toList();
    bool onAnticoagulant = any(meds, ['warfarin','aceno','apixaban','rivaroxaban','edoxaban','dabigatran']);
    bool onAntiplatelet = any(meds, ['aspirin','clopidogrel','prasugrel','ticagrelor']);
    bool onSSRI = any(meds, ['sertraline','fluoxetine','paroxetine','citalopram','escitalopram']);
    bool onDomperidone = any(meds, ['domperidone']);
    bool onTizanidine = any(meds, ['tizanidine']);

    // NSAIDs + anticoagulant/antiplatelet/SSRI -> bleeding
    if (isNSAID() && (onAnticoagulant || onAntiplatelet || onSSRI)) {
      return const ContraindicationResult(
        'Current medication increases bleeding risk.',
        details: 'NSAIDs with anticoagulants/antiplatelets/SSRIs ↑ GI bleeding. Refer: FDA NSAID safety; NICE CKS; DrugBank interactions.',
      );
    }
    // Warfarin + metronidazole
    if (onAnticoagulant && isNitroimidazole()) {
      return const ContraindicationResult(
        'Current medication interacts with warfarin (↑INR).',
        details: 'Metronidazole inhibits warfarin metabolism. Refer: FDA warfarin/Flagyl labeling; RxClass.',
      );
    }
    // Macrolide (azithro) + domperidone -> QT
    if (onDomperidone && (m.contains('azithromycin') || m.contains('clarithromycin') || m.contains('erythromycin'))) {
      return const ContraindicationResult(
        'Current medication + domperidone: QT prolongation risk.',
        details: 'Avoid co‑administration. Refer: EMA/FDA domperidone/macrolide safety notices.',
      );
    }
    // Fluoroquinolone + tizanidine (notably ciprofloxacin); conservative for class
    if (onTizanidine && isFluoroquinolone()) {
      return const ContraindicationResult(
        'Avoid with tizanidine: hypotension/sedation risk.',
        details: 'Fluoroquinolones inhibit tizanidine metabolism (class caution). Refer: Ciprofloxacin label; DrugBank.',
      );
    }
    // Dual therapy: second NSAID or second PPI
    if (isNSAID() && any(meds, ['ibuprofen','diclofenac','ketorolac','piroxicam','nimesulide','mefenamic','etoricoxib','aceclofenac'])) {
      return const ContraindicationResult(
        'Avoid dual NSAID therapy.',
        details: 'No added benefit; ↑ GI/renal adverse events. Refer: NICE/WHO analgesia guidance.',
      );
    }
    if (isPPI() && any(meds, ['omeprazole','esomeprazole','pantoprazole','rabeprazole','lansoprazole'])) {
      return const ContraindicationResult(
        'Avoid duplicate PPI therapy.',
        details: 'Use single PPI; long‑term risks include fractures, hypomagnesemia. Refer: FDA PPI labeling.',
      );
    }

    // Default: no hard stop
    return null;
  }
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
