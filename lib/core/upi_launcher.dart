import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launches a UPI payment intent using the common URI format.
/// Defaults to placeholder payee address if none provided.
Future<void> launchUPIPayment({
  BuildContext? context,
  String pa = 'dentist@upi',
  String pn = 'Dental Clinic',
  double? amount,
  String cu = 'INR',
  String? note,
}) async {
  final params = <String, String>{
    'pa': pa,
    'pn': pn,
    'cu': cu,
  };
  if (amount != null && amount > 0) {
    params['am'] = amount.toStringAsFixed(0);
  }
  if (note != null && note.trim().isNotEmpty) {
    params['tn'] = note;
  }
  final query = params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
  final uri = Uri.parse('upi://pay?$query');
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No UPI app available')));
      }
    }
  } catch (e) {
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('UPI launch failed: $e')));
    }
  }
}
