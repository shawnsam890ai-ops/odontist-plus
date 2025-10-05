import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_router.dart';
import 'providers/patient_provider.dart';
import 'providers/revenue_provider.dart';
import 'providers/lab_provider.dart';
import 'providers/options_provider.dart';
import 'ui/pages/splash_page.dart';

void main() {
  runApp(const DentalClinicApp());
}

class DentalClinicApp extends StatelessWidget {
  const DentalClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => RevenueProvider()),
        ChangeNotifierProvider(create: (_) => LabProvider()),
        ChangeNotifierProvider(create: (_) => OptionsProvider()),
      ],
      child: Builder(
        builder: (ctx) {
          // Register cross-provider reference once tree is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final opt = ctx.read<OptionsProvider>();
            final pats = ctx.read<PatientProvider>();
            opt.registerPatientProvider(pats);
          });
          return MaterialApp(
        title: 'Dental Clinic',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        ),
        onGenerateRoute: AppRouter.generate,
        initialRoute: SplashPage.routeName,
          );
        }
      ),
    );
  }
}
