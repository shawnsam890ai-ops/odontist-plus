import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_router.dart';
import 'providers/patient_provider.dart';
import 'providers/revenue_provider.dart';
import 'providers/lab_provider.dart';
import 'providers/options_provider.dart';
import 'providers/appointment_provider.dart';
import 'providers/clinic_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/staff_attendance_provider.dart';
import 'providers/doctor_attendance_provider.dart';
import 'providers/doctor_provider.dart';
import 'providers/lab_registry_provider.dart';
import 'providers/medicine_provider.dart';
import 'providers/utility_provider.dart';
import 'ui/pages/splash_page.dart';
import 'core/app_theme.dart';
import 'providers/auth_provider.dart';
// Firebase initialization will be added after FlutterFire configure.

void main() {
  runApp(const DentalClinicApp());
}

class DentalClinicApp extends StatelessWidget {
  const DentalClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
    providers: [
  // To enable Firebase auth, replace the line below with:
  // ChangeNotifierProvider(create: (_) => AuthProvider(backend: FirebaseAuthBackend())),
  ChangeNotifierProvider(create: (_) => AuthProvider()),
  ChangeNotifierProvider(create: (_) => PatientProvider()),
  ChangeNotifierProvider(create: (_) => RevenueProvider()),
        ChangeNotifierProvider(create: (_) => LabProvider()),
        ChangeNotifierProvider(create: (_) => OptionsProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => ClinicProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
  ChangeNotifierProvider(create: (_) => StaffAttendanceProvider()),
        ChangeNotifierProvider(create: (_) => DoctorAttendanceProvider()),
  ChangeNotifierProvider(create: (_) => DoctorProvider()),
    ChangeNotifierProvider(create: (_) => LabRegistryProvider()),
    ChangeNotifierProvider(create: (_) => MedicineProvider()),
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
            final opt = ctx.read<OptionsProvider>();
            final pats = ctx.read<PatientProvider>();
            opt.registerPatientProvider(pats);
            // Register revenue into providers that need cross-updates
            final rev = ctx.read<RevenueProvider>();
            pats.registerRevenueProvider(rev);
            ctx.read<StaffAttendanceProvider>().registerRevenueProvider(rev);
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
          });
          return MaterialApp(
            title: 'Dental Clinic',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            onGenerateRoute: AppRouter.generate,
            initialRoute: SplashPage.routeName,
          );
        }
      ),
    );
  }
}
