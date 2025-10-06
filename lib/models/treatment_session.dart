import '../core/enums.dart';

class ChiefComplaintEntry {
  final List<String> complaints;
  final List<String> quadrants;
  ChiefComplaintEntry({required this.complaints, required this.quadrants});

  Map<String, dynamic> toJson() => {
        'complaints': complaints,
        'quadrants': quadrants,
      };
  factory ChiefComplaintEntry.fromJson(Map<String, dynamic> json) => ChiefComplaintEntry(
        complaints: (json['complaints'] as List<dynamic>).cast<String>(),
        quadrants: (json['quadrants'] as List<dynamic>).cast<String>(),
      );
}

class OralExamFinding {
  final String toothNumber; // FDI notation
  final String finding;
  OralExamFinding({required this.toothNumber, required this.finding});
  Map<String, dynamic> toJson() => {'toothNumber': toothNumber, 'finding': finding};
  factory OralExamFinding.fromJson(Map<String, dynamic> json) => OralExamFinding(
        toothNumber: json['toothNumber'] as String,
        finding: json['finding'] as String,
      );
}

class InvestigationFinding {
  final String toothNumber;
  final String finding;
  final String? imagePath; // optional xray image
  InvestigationFinding({required this.toothNumber, required this.finding, this.imagePath});
  Map<String, dynamic> toJson() => {'toothNumber': toothNumber, 'finding': finding, 'imagePath': imagePath};
  factory InvestigationFinding.fromJson(Map<String, dynamic> json) => InvestigationFinding(
        toothNumber: json['toothNumber'] as String,
        finding: json['finding'] as String,
        imagePath: json['imagePath'] as String?,
      );
}

class PrescriptionItem {
  final int serial;
  final String medicine;
  final String timing; // e.g. 1-0-1 or SOS
  final int tablets;
  final int days;
  PrescriptionItem({
    required this.serial,
    required this.medicine,
    required this.timing,
    required this.tablets,
    required this.days,
  });
  Map<String, dynamic> toJson() => {
        'serial': serial,
        'medicine': medicine,
        'timing': timing,
        'tablets': tablets,
        'days': days,
      };
  factory PrescriptionItem.fromJson(Map<String, dynamic> json) => PrescriptionItem(
        serial: json['serial'] as int,
        medicine: json['medicine'] as String,
        timing: json['timing'] as String,
        tablets: json['tablets'] as int,
        days: json['days'] as int,
      );
}

// New structured per-tooth treatment planning entry
class ToothPlanEntry {
  final String toothNumber; // FDI
  final String plan; // planned treatment
  ToothPlanEntry({required this.toothNumber, required this.plan});
  Map<String, dynamic> toJson() => {
        'toothNumber': toothNumber,
        'plan': plan,
      };
  factory ToothPlanEntry.fromJson(Map<String, dynamic> json) => ToothPlanEntry(
        toothNumber: json['toothNumber'] as String,
        plan: json['plan'] as String,
      );
}

// New structured per-tooth treatment actually done entry
class ToothTreatmentDoneEntry {
  final String toothNumber;
  final String treatment; // description of procedure done
  ToothTreatmentDoneEntry({required this.toothNumber, required this.treatment});
  Map<String, dynamic> toJson() => {
        'toothNumber': toothNumber,
        'treatment': treatment,
      };
  factory ToothTreatmentDoneEntry.fromJson(Map<String, dynamic> json) => ToothTreatmentDoneEntry(
        toothNumber: json['toothNumber'] as String,
        treatment: json['treatment'] as String,
      );
}

class PaymentEntry {
  final DateTime date;
  final double amount;
  PaymentEntry({required this.date, required this.amount});
  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'amount': amount};
  factory PaymentEntry.fromJson(Map<String, dynamic> json) => PaymentEntry(
        date: DateTime.parse(json['date'] as String),
        amount: (json['amount'] as num).toDouble(),
      );
}

// Added ProcedureStep model for detailed steps with optional payment
class ProcedureStep {
  final String id;
  final DateTime date;
  final String description;
  final double? payment;
  final String? note;
  ProcedureStep({
    required this.id,
    required this.date,
    required this.description,
    this.payment,
    this.note,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'description': description,
        'payment': payment,
        'note': note,
      };
  factory ProcedureStep.fromJson(Map<String, dynamic> json) => ProcedureStep(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        description: json['description'] as String,
        payment: (json['payment'] as num?)?.toDouble(),
        note: json['note'] as String?,
      );
}

class TreatmentSession {
  final String id;
  final TreatmentType type;
  final DateTime date;
  final String? parentSessionId; // follow-up linkage

  // General
  final ChiefComplaintEntry? chiefComplaint;
  final List<OralExamFinding> oralExamFindings;
  final List<InvestigationType> investigations;
  final List<InvestigationFinding> investigationFindings;
  final List<String> generalTreatmentPlan;
  // New multi-select option lists (non tooth-specific)
  final List<String> planOptions;
  final List<String> treatmentDoneOptions;
  // New structured lists superseding generalTreatmentPlan (kept for backward compatibility)
  final List<ToothPlanEntry> toothPlans;
  final List<ToothTreatmentDoneEntry> treatmentsDone;
  final String notes;
  final List<PrescriptionItem> prescription;
  final List<String> mediaPaths;
  final DateTime? nextAppointment; // new

  // Orthodontic
  final String orthoOralFindings;
  final BracketType? bracketType;
  final double? orthoTotalAmount;
  final String? orthoDoctorInCharge;
  final List<PaymentEntry> payments;
  final List<String> orthoTreatmentDone;
  final List<ProcedureStep> orthoSteps; // new

  // Root Canal
  final List<OralExamFinding> rootCanalFindings;
  final double? rootCanalTotalAmount;
  final List<String> rootCanalProcedures;
  final List<ProcedureStep> rootCanalSteps; // new
  // New: root canal plan entries (similar to toothPlans) & doctor in charge
  final List<ToothPlanEntry> rootCanalPlans; // per-tooth planned RCT steps
  final String? rootCanalDoctorInCharge;

  final String? consentFormPath;

  TreatmentSession({
    required this.id,
    required this.type,
    required this.date,
    this.parentSessionId,
    this.chiefComplaint,
    List<OralExamFinding>? oralExamFindings,
    List<InvestigationType>? investigations,
    List<InvestigationFinding>? investigationFindings,
    List<String>? generalTreatmentPlan,
  List<String>? planOptions,
  List<String>? treatmentDoneOptions,
  List<ToothPlanEntry>? toothPlans,
  List<ToothTreatmentDoneEntry>? treatmentsDone,
    this.notes = '',
    List<PrescriptionItem>? prescription,
    List<String>? mediaPaths,
  this.nextAppointment,
    this.orthoOralFindings = '',
    this.bracketType,
    this.orthoTotalAmount,
    this.orthoDoctorInCharge,
    List<PaymentEntry>? payments,
    List<String>? orthoTreatmentDone,
    List<ProcedureStep>? orthoSteps,
    List<OralExamFinding>? rootCanalFindings,
    this.rootCanalTotalAmount,
    List<String>? rootCanalProcedures,
    List<ProcedureStep>? rootCanalSteps,
  List<ToothPlanEntry>? rootCanalPlans,
    this.rootCanalDoctorInCharge,
    this.consentFormPath,
  })  : oralExamFindings = oralExamFindings ?? [],
        investigations = investigations ?? [],
        investigationFindings = investigationFindings ?? [],
        generalTreatmentPlan = generalTreatmentPlan ?? [],
  planOptions = planOptions ?? [],
  treatmentDoneOptions = treatmentDoneOptions ?? [],
  toothPlans = toothPlans ?? [],
  treatmentsDone = treatmentsDone ?? [],
        prescription = prescription ?? [],
        mediaPaths = mediaPaths ?? [],
        payments = payments ?? [],
        orthoTreatmentDone = orthoTreatmentDone ?? [],
        orthoSteps = orthoSteps ?? [],
        rootCanalFindings = rootCanalFindings ?? [],
        rootCanalProcedures = rootCanalProcedures ?? [],
  rootCanalSteps = rootCanalSteps ?? [],
  rootCanalPlans = rootCanalPlans ?? [];

  TreatmentSession copyWith({
    String? id,
    TreatmentType? type,
    DateTime? date,
    String? parentSessionId,
    ChiefComplaintEntry? chiefComplaint,
    List<OralExamFinding>? oralExamFindings,
    List<InvestigationType>? investigations,
    List<InvestigationFinding>? investigationFindings,
    List<String>? generalTreatmentPlan,
  List<String>? planOptions,
  List<String>? treatmentDoneOptions,
  List<ToothPlanEntry>? toothPlans,
  List<ToothTreatmentDoneEntry>? treatmentsDone,
    String? notes,
    List<PrescriptionItem>? prescription,
    List<String>? mediaPaths,
  DateTime? nextAppointment,
    String? orthoOralFindings,
    BracketType? bracketType,
    double? orthoTotalAmount,
    String? orthoDoctorInCharge,
    List<PaymentEntry>? payments,
    List<String>? orthoTreatmentDone,
    List<ProcedureStep>? orthoSteps,
    List<OralExamFinding>? rootCanalFindings,
    double? rootCanalTotalAmount,
    List<String>? rootCanalProcedures,
    List<ProcedureStep>? rootCanalSteps,
  List<ToothPlanEntry>? rootCanalPlans,
    String? rootCanalDoctorInCharge,
    String? consentFormPath,
  }) => TreatmentSession(
        id: id ?? this.id,
        type: type ?? this.type,
        date: date ?? this.date,
        parentSessionId: parentSessionId ?? this.parentSessionId,
        chiefComplaint: chiefComplaint ?? this.chiefComplaint,
        oralExamFindings: oralExamFindings ?? List.from(this.oralExamFindings),
        investigations: investigations ?? List.from(this.investigations),
        investigationFindings: investigationFindings ?? List.from(this.investigationFindings),
        generalTreatmentPlan: generalTreatmentPlan ?? List.from(this.generalTreatmentPlan),
  planOptions: planOptions ?? List.from(this.planOptions),
  treatmentDoneOptions: treatmentDoneOptions ?? List.from(this.treatmentDoneOptions),
  toothPlans: toothPlans ?? List.from(this.toothPlans),
  treatmentsDone: treatmentsDone ?? List.from(this.treatmentsDone),
        notes: notes ?? this.notes,
        prescription: prescription ?? List.from(this.prescription),
        mediaPaths: mediaPaths ?? List.from(this.mediaPaths),
  nextAppointment: nextAppointment ?? this.nextAppointment,
        orthoOralFindings: orthoOralFindings ?? this.orthoOralFindings,
        bracketType: bracketType ?? this.bracketType,
        orthoTotalAmount: orthoTotalAmount ?? this.orthoTotalAmount,
        orthoDoctorInCharge: orthoDoctorInCharge ?? this.orthoDoctorInCharge,
        payments: payments ?? List.from(this.payments),
        orthoTreatmentDone: orthoTreatmentDone ?? List.from(this.orthoTreatmentDone),
        orthoSteps: orthoSteps ?? List.from(this.orthoSteps),
        rootCanalFindings: rootCanalFindings ?? List.from(this.rootCanalFindings),
        rootCanalTotalAmount: rootCanalTotalAmount ?? this.rootCanalTotalAmount,
        rootCanalProcedures: rootCanalProcedures ?? List.from(this.rootCanalProcedures),
        rootCanalSteps: rootCanalSteps ?? List.from(this.rootCanalSteps),
  rootCanalPlans: rootCanalPlans ?? List.from(this.rootCanalPlans),
        rootCanalDoctorInCharge: rootCanalDoctorInCharge ?? this.rootCanalDoctorInCharge,
        consentFormPath: consentFormPath ?? this.consentFormPath,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'date': date.toIso8601String(),
        'parentSessionId': parentSessionId,
        'chiefComplaint': chiefComplaint?.toJson(),
        'oralExamFindings': oralExamFindings.map((e) => e.toJson()).toList(),
        'investigations': investigations.map((e) => e.index).toList(),
        'investigationFindings': investigationFindings.map((e) => e.toJson()).toList(),
        'generalTreatmentPlan': generalTreatmentPlan,
  'planOptions': planOptions,
  'treatmentDoneOptions': treatmentDoneOptions,
  'toothPlans': toothPlans.map((e) => e.toJson()).toList(),
  'treatmentsDone': treatmentsDone.map((e) => e.toJson()).toList(),
        'notes': notes,
        'prescription': prescription.map((e) => e.toJson()).toList(),
        'mediaPaths': mediaPaths,
  'nextAppointment': nextAppointment?.toIso8601String(),
        'orthoOralFindings': orthoOralFindings,
        'bracketType': bracketType?.index,
        'orthoTotalAmount': orthoTotalAmount,
        'orthoDoctorInCharge': orthoDoctorInCharge,
        'payments': payments.map((e) => e.toJson()).toList(),
        'orthoTreatmentDone': orthoTreatmentDone,
        'orthoSteps': orthoSteps.map((e) => e.toJson()).toList(),
        'rootCanalFindings': rootCanalFindings.map((e) => e.toJson()).toList(),
        'rootCanalTotalAmount': rootCanalTotalAmount,
        'rootCanalProcedures': rootCanalProcedures,
        'rootCanalSteps': rootCanalSteps.map((e) => e.toJson()).toList(),
        'rootCanalPlans': rootCanalPlans.map((e) => e.toJson()).toList(),
        'rootCanalDoctorInCharge': rootCanalDoctorInCharge,
        'consentFormPath': consentFormPath,
      };

  factory TreatmentSession.fromJson(Map<String, dynamic> json) => TreatmentSession(
        id: json['id'] as String,
        type: TreatmentType.values[json['type'] as int],
        date: DateTime.parse(json['date'] as String),
        parentSessionId: json['parentSessionId'] as String?,
        chiefComplaint: json['chiefComplaint'] == null ? null : ChiefComplaintEntry.fromJson(json['chiefComplaint'] as Map<String, dynamic>),
        oralExamFindings: (json['oralExamFindings'] as List<dynamic>).map((e) => OralExamFinding.fromJson(e as Map<String, dynamic>)).toList(),
        investigations: (json['investigations'] as List<dynamic>).map((e) => InvestigationType.values[e as int]).toList(),
        investigationFindings: (json['investigationFindings'] as List<dynamic>).map((e) => InvestigationFinding.fromJson(e as Map<String, dynamic>)).toList(),
        generalTreatmentPlan: (json['generalTreatmentPlan'] as List<dynamic>).cast<String>(),
  planOptions: (json['planOptions'] as List<dynamic>? ?? []).cast<String>(),
  treatmentDoneOptions: (json['treatmentDoneOptions'] as List<dynamic>? ?? []).cast<String>(),
    toothPlans: (json['toothPlans'] as List<dynamic>? ?? [])
      .map((e) => ToothPlanEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
    treatmentsDone: (json['treatmentsDone'] as List<dynamic>? ?? [])
      .map((e) => ToothTreatmentDoneEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
        notes: json['notes'] as String? ?? '',
        prescription: (json['prescription'] as List<dynamic>).map((e) => PrescriptionItem.fromJson(e as Map<String, dynamic>)).toList(),
        mediaPaths: (json['mediaPaths'] as List<dynamic>).cast<String>(),
    nextAppointment: json['nextAppointment'] == null ? null : DateTime.parse(json['nextAppointment'] as String),
        orthoOralFindings: json['orthoOralFindings'] as String? ?? '',
        bracketType: json['bracketType'] == null ? null : BracketType.values[json['bracketType'] as int],
        orthoTotalAmount: (json['orthoTotalAmount'] as num?)?.toDouble(),
        orthoDoctorInCharge: json['orthoDoctorInCharge'] as String?,
        payments: (json['payments'] as List<dynamic>).map((e) => PaymentEntry.fromJson(e as Map<String, dynamic>)).toList(),
        orthoTreatmentDone: (json['orthoTreatmentDone'] as List<dynamic>).cast<String>(),
        orthoSteps: (json['orthoSteps'] as List<dynamic>? ?? []).map((e) => ProcedureStep.fromJson(e as Map<String, dynamic>)).toList(),
        rootCanalFindings: (json['rootCanalFindings'] as List<dynamic>).map((e) => OralExamFinding.fromJson(e as Map<String, dynamic>)).toList(),
        rootCanalTotalAmount: (json['rootCanalTotalAmount'] as num?)?.toDouble(),
        rootCanalProcedures: (json['rootCanalProcedures'] as List<dynamic>).cast<String>(),
        rootCanalSteps: (json['rootCanalSteps'] as List<dynamic>? ?? []).map((e) => ProcedureStep.fromJson(e as Map<String, dynamic>)).toList(),
  rootCanalPlans: (json['rootCanalPlans'] as List<dynamic>? ?? []).map((e) => ToothPlanEntry.fromJson(e as Map<String, dynamic>)).toList(),
        rootCanalDoctorInCharge: json['rootCanalDoctorInCharge'] as String?,
        consentFormPath: json['consentFormPath'] as String?,
      );
}
