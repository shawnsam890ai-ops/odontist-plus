import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_router.dart';
import 'core/constants.dart';
import 'providers/patient_provider.dart';
import 'providers/revenue_provider.dart';
import 'providers/lab_provider.dart';
import 'providers/options_provider.dart';
import 'providers/appointment_provider.dart';
import 'providers/clinic_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/staff_attendance_provider.dart';
import 'providers/holidays_provider.dart';
import 'providers/doctor_attendance_provider.dart';
import 'providers/doctor_provider.dart';
import 'providers/lab_registry_provider.dart';
import 'providers/medicine_provider.dart';
import 'providers/utility_provider.dart';
import 'ui/pages/splash_page.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/app_settings_provider.dart';
import 'services/notification_service.dart';
import 'providers/license_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/auth_backend_firebase.dart';
// Firebase initialization will be added after FlutterFire configure.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DentalClinicApp());
}

class DentalClinicApp extends StatelessWidget {
  const DentalClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
  return MultiProvider(
    providers: [
  ChangeNotifierProvider(create: (_) => AuthProvider(backend: FirebaseAuthBackend())),
  ChangeNotifierProvider(create: (_) => PatientProvider()),
  ChangeNotifierProvider(create: (_) => RevenueProvider()),
        ChangeNotifierProvider(create: (_) => LabProvider()),
        ChangeNotifierProvider(create: (_) => OptionsProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => ClinicProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
  ChangeNotifierProvider(create: (_) => StaffAttendanceProvider()),
    ChangeNotifierProvider(create: (_) => HolidaysProvider()),
        ChangeNotifierProvider(create: (_) => DoctorAttendanceProvider()),
  ChangeNotifierProvider(create: (_) => DoctorProvider()),
    ChangeNotifierProvider(create: (_) => LabRegistryProvider()),
    ChangeNotifierProvider(create: (_) => MedicineProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
  ChangeNotifierProvider(create: (_) => LicenseProvider()),
    // Utility depends on RevenueProvider instance
    ChangeNotifierProxyProvider<RevenueProvider, UtilityProvider>(
      create: (ctx) => UtilityProvider(revenue: ctx.read<RevenueProvider>()),
      update: (ctx, revenue, prev) => prev ?? UtilityProvider(revenue: revenue),
    ),
      ],
      child: Builder(
        builder: (ctx) {
          // Register cross-provider reference once tree is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Auth first
            ctx.read<AuthProvider>().ensureLoaded();
            // Refresh license status after auth state is known
            ctx.read<LicenseProvider>().refresh();
            ctx.read<LicenseProvider>().startAutoRefresh(every: const Duration(minutes: 30));
            // Load theme choice
            ctx.read<ThemeProvider>().ensureLoaded();
            // Load app settings
            ctx.read<AppSettingsProvider>().ensureLoaded();
            final opt = ctx.read<OptionsProvider>();
            final pats = ctx.read<PatientProvider>();
            // Load patients from storage/Firestore
            pats.ensureLoaded();
            opt.registerPatientProvider(pats);
            // Load OptionsProvider with defaults (including medicine contents)
            opt.ensureLoaded(
              defaultComplaints: AppConstants.chiefComplaints,
              defaultOralFindings: AppConstants.oralFindings,
              defaultPlan: AppConstants.generalTreatmentPlanOptions,
              defaultTreatmentDone: AppConstants.generalTreatmentDoneOptions,
              defaultMedicines: AppConstants.prescriptionMedicines,
              defaultPastDental: AppConstants.pastDentalHistoryOptions,
              defaultPastMedical: AppConstants.pastMedicalHistoryOptions,
              defaultMedicationOptions: AppConstants.medicationOptions,
              defaultDrugAllergies: AppConstants.drugAllergyOptions,
              defaultMedicineContents: AppConstants.medicineContents,
              defaultRcDoctors: const [],
              defaultProsthoDoctors: const [],
              defaultLabNames: const ['Maxima Lab', 'Crown Lab', 'Digital Dental Lab'],
              defaultNatureOfWork: const ['PFM Crown', 'Zirconia Crown', 'Sunflex RPD', 'Metal Partial', 'Complete Denture', 'Bridge Work'],
              defaultToothShades: const ['A1', 'A2', 'A3', 'B1', 'B2', 'C1', 'C2'],
            );
            // Register revenue into providers that need cross-updates
            final rev = ctx.read<RevenueProvider>();
            pats.registerRevenueProvider(rev);
            ctx.read<StaffAttendanceProvider>().registerRevenueProvider(rev);
            // Load staff + attendance from Firestore
            ctx.read<StaffAttendanceProvider>().ensureLoaded();
            // Holidays provider currently standalone; no cross-registration required
            // Load persisted doctors and ledger
            ctx.read<DoctorProvider>().load();
            // Load lab registry
            ctx.read<LabRegistryProvider>().ensureLoaded();
            // Load revenue so dashboard shows persisted totals
            ctx.read<RevenueProvider>().ensureLoaded();
            // Load medicines
            ctx.read<MedicineProvider>().ensureLoaded();
            // Load utilities
            ctx.read<UtilityProvider>().ensureLoaded();
            // Load inventory
            ctx.read<InventoryProvider>().ensureLoaded();
            // Load appointments from Firestore
            ctx.read<AppointmentProvider>().ensureLoaded();
            // Initialize local notifications
            NotificationService.instance.init();
          });
          final theme = ctx.watch<ThemeProvider>();
          return MaterialApp(
            title: 'Odontist Plus',
            theme: theme.lightTheme,
            darkTheme: theme.darkTheme,
            // Force light mode regardless of the device's system theme
            themeMode: ThemeMode.light,
            builder: (context, child) {
              // Clamp text scale to keep UI readable on very small/large screens
              final mq = MediaQuery.of(context);
              final clampedScale = mq.textScaleFactor.clamp(0.90, 1.30);
              return MediaQuery(
                data: mq.copyWith(textScaleFactor: clampedScale),
                child: child ?? const SizedBox.shrink(),
              );
            },
            onGenerateRoute: AppRouter.generate,
            initialRoute: SplashPage.routeName,
          );
        }
      ),
    );
  }
}
