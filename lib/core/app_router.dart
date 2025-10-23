import 'package:flutter/material.dart';
import '../ui/pages/splash_page.dart';
import '../ui/pages/login_page.dart';
import '../ui/pages/dashboard_page.dart';
import '../ui/pages/patient_list_page.dart';
import '../ui/pages/add_patient_page.dart';
import '../ui/pages/patient_detail_page.dart';
import '../ui/pages/patient_lab_work_page.dart';
import '../ui/pages/edit_patient_page.dart';
import '../ui/pages/manage_patients_modern.dart';
import '../ui/pages/pending_approval_page.dart';
import '../ui/pages/admin_users_page.dart';
import '../ui/pages/auth/signup_page.dart';
import '../ui/pages/auth/terms_page.dart';
import '../ui/pages/auth/email_otp_page.dart';
import '../ui/pages/auth/phone_otp_page.dart';

class AppRouter {
  static Route<dynamic> generate(RouteSettings settings) {
    switch (settings.name) {
      case SplashPage.routeName:
        return MaterialPageRoute(builder: (_) => const SplashPage());
      case LoginPage.routeName:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case DashboardPage.routeName:
        return MaterialPageRoute(builder: (_) => const DashboardPage());
      case PendingApprovalPage.routeName:
        return MaterialPageRoute(builder: (_) => const PendingApprovalPage());
      case SignupPage.routeName:
        return MaterialPageRoute(builder: (_) => const SignupPage());
      case TermsPage.routeName:
        return MaterialPageRoute(builder: (_) => const TermsPage());
      case EmailOtpPage.routeName:
        return MaterialPageRoute(builder: (_) => const EmailOtpPage());
      case PhoneOtpPage.routeName:
        return MaterialPageRoute(builder: (_) => const PhoneOtpPage());
      case AdminUsersPage.routeName:
        return MaterialPageRoute(builder: (_) => const AdminUsersPage());
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
      case EditPatientPage.routeName:
        final args = settings.arguments as Map<String, dynamic>?;
        final patientId = args?['patientId'] as String?;
        if (patientId == null) {
          return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Missing patient id'))));
        }
        return MaterialPageRoute(builder: (_) => EditPatientPage(patientId: patientId));
      case ManagePatientsModern.routeName:
        return MaterialPageRoute(builder: (_) => const ManagePatientsModern());
      default:
        return MaterialPageRoute(
            builder: (_) => Scaffold(
                  body: Center(child: Text('No route defined for ${settings.name}')),
                ));
    }
  }
}
