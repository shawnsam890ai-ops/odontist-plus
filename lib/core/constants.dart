class AppConstants {
  static const appName = 'Dental Clinic';

  // Chief complaints options & Quadrants (can be later loaded from storage)
  static const chiefComplaints = [
    'Pain', 'Stains', 'Swelling', 'Sensitivity', 'Mobile tooth', 'Decayed Tooth', 'Broken Tooth'
  ];

  static const quadrants = [
    'U/L', 'U/R', 'U/F', 'L/R', 'L/L', 'L/F', 'All quadrants'
  ];

  static const oralFindings = [
    'DDC', 'DC', 'PI', 'Generalized Stains and Deposits', 'Early childhood Caries (ECC)',
    'Initial Carious Lesion', 'Severe Black stains', 'Grade 1 mobile'
  ];

  static const investigations = ['IOPAR', 'OPG', 'CBCT'];

  static const generalTreatmentPlanOptions = [
    'Advice Rootcanal', 'Oral Prophylaxis', 'Extraction', 'Filling'
  ];

  static const prescriptionMedicines = [
    'Paracetamol 500mg', 'Ibuprofen 400mg', 'Amoxicillin 500mg', 'Vitamin C'
  ];

  static const orthodonticTreatmentOptions = [
    'Banding', 'Bonding', 'Archwire change', 'Bracket reposition', 'Debonding'
  ];

  static const rootCanalProcedureOptions = [
    'Access opening', 'Working length determination', 'Biomechanical preparation', 'Obturation'
  ];

  static const labWorkTypes = [
    'Crown', 'Bridge', 'Denture', 'Aligner', 'Retainer'
  ];
}
