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

  // Separate list for treatments actually done (can diverge from plan)
  static const generalTreatmentDoneOptions = [
    'RCT Completed', 'Filling Completed', 'Extraction Completed', 'Scaling Done', 'Crown Cemented'
  ];

  static const prescriptionMedicines = [
    'Paracetamol 500mg', 'Ibuprofen 400mg', 'Amoxicillin 500mg', 'Vitamin C'
  ];

  // Default set of medicine contents (active ingredients)
  static const medicineContents = [
    'Paracetamol',
    'Ibuprofen',
    'Diclofenac',
    'Ketorolac',
    'Mefenamic Acid',
    'Etoricoxib',
    'Aceclofenac',
    'Amoxicillin',
    'Amoxicillin + Clavulanate',
    'Azithromycin',
    'Clarithromycin',
    'Metronidazole',
    'Ornidazole',
    'Tinidazole',
    'Ofloxacin',
    'Ciprofloxacin',
    'Levofloxacin',
    'Moxifloxacin',
    'Cefixime',
    'Ceftriaxone',
    'Tramadol',
    'Codeine',
    'Omeprazole',
    'Pantoprazole',
    'Rabeprazole',
    'Esomeprazole',
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

  // New history option lists
  static const pastDentalHistoryOptions = [
    'Previous RCT', 'Extraction', 'Orthodontic treatment', 'Trauma', 'Bleeding gums', 'Bad breath'
  ];
  static const pastMedicalHistoryOptions = [
    'Diabetes', 'Hypertension', 'Cardiac disease', 'Asthma', 'Thyroid disorder', 'Epilepsy'
  ];
  static const medicationOptions = [
    'Metformin', 'Insulin', 'Aspirin', 'Antihypertensives', 'Inhaled bronchodilators'
  ];
  static const drugAllergyOptions = [
    'Penicillin', 'Sulfa drugs', 'NSAIDs', 'Local anesthetic', 'Latex'
  ];
}
