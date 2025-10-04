import 'package:flutter/material.dart';
import '../ui/pages/splash_page.dart';
import '../ui/pages/login_page.dart';
import '../ui/pages/dashboard_page.dart';
import '../ui/pages/patient_list_page.dart';
import '../ui/pages/add_patient_page.dart';
import '../ui/pages/patient_detail_page.dart';
import '../ui/pages/patient_lab_work_page.dart';

class AppRouter {
  static Route<dynamic> generate(RouteSettings settings) {
    switch (settings.name) {
      case SplashPage.routeName:
        return MaterialPageRoute(builder: (_) => const SplashPage());
      case LoginPage.routeName:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case DashboardPage.routeName:
        return MaterialPageRoute(builder: (_) => const DashboardPage());
      case PatientListPage.routeName:
        return MaterialPageRoute(builder: (_) => const PatientListPage());
      case AddPatientPage.routeName:
        return MaterialPageRoute(builder: (_) => const AddPatientPage());
      case PatientDetailPage.routeName:
        final args = settings.arguments as Map<String, dynamic>?;
        final patientId = args?['patientId'] as String?;
        return MaterialPageRoute(builder: (_) => PatientDetailPage(patientId: patientId));
      case PatientLabWorkPage.routeName:
        final args = settings.arguments as Map<String, dynamic>?;
        final patientId = args?['patientId'] as String?;
        return MaterialPageRoute(builder: (_) => PatientLabWorkPage(patientId: patientId));
      default:
        return MaterialPageRoute(
            builder: (_) => Scaffold(
                  body: Center(child: Text('No route defined for ${settings.name}')),
                ));
    }
  }
}
