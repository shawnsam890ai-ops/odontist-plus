import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  static const routeName = '/terms';
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              Text('Welcome to Odontist Plus', style: textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('By creating an account or using the app, you agree to these Terms and Conditions. Please read them carefully.', style: textTheme.bodyMedium),
              const SizedBox(height: 24),
              Text('1. Account & Eligibility', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('• You must provide accurate information during sign up and keep it up to date.\n• You are responsible for maintaining the confidentiality of your account credentials.\n• You must comply with applicable laws and professional regulations.'),
              const SizedBox(height: 16),
              Text('2. Clinical Data & Privacy', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('• You control the data you enter (patients, treatments, billing).\n• Do not upload sensitive personal data without consent.\n• We use Firebase services for authentication, storage, and processing as described by their policies.'),
              const SizedBox(height: 16),
              Text('3. Acceptable Use', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('• Do not misuse the app (e.g., reverse engineering, unauthorized access, abuse).\n• Do not upload unlawful, harmful, or infringing content.'),
              const SizedBox(height: 16),
              Text('4. Subscription & Billing', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('• Trials and subscriptions are managed via our payment partner.\n• Fees are non-refundable except where required by law.\n• Failure to pay may result in limited access or suspension.'),
              const SizedBox(height: 16),
              Text('5. Disclaimers', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('• The app is provided on an “as is” basis without warranties of any kind.\n• We are not liable for clinical decisions, outcomes, or data input by users.'),
              const SizedBox(height: 16),
              Text('6. Termination', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('• We may suspend or terminate access for violations of these terms or unlawful activity.'),
              const SizedBox(height: 16),
              Text('7. Changes to Terms', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('• We may update these terms; continued use means you accept the updated terms.'),
              const SizedBox(height: 16),
              Text('8. Contact', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('• For questions, reach out to the support contact provided in the app or store listing.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('I Understand'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
