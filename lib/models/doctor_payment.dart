class DoctorPaymentTracker {
  final String doctorName;
  double totalDue; // Accumulated from sessions (future calculation)
  double paid; // Payments recorded

  DoctorPaymentTracker({required this.doctorName, this.totalDue = 0, this.paid = 0});

  double get balance => totalDue - paid;
}
