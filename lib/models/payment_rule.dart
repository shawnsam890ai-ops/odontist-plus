enum PaymentMode { fixed, percent }

class PaymentRule {
  final PaymentMode mode;
  // amount if fixed; percent (0-100) if percent
  final double value;
  // Optional: clinic price for this procedure (used for UI default calculations)
  final double? clinicPrice;

  const PaymentRule.fixed(this.value, {this.clinicPrice}) : mode = PaymentMode.fixed;
  const PaymentRule.percent(this.value, {this.clinicPrice}) : mode = PaymentMode.percent;

  // Return (doctorShare, clinicShare) for a given charge amount
  (double doctor, double clinic) split(double charge) {
    if (mode == PaymentMode.fixed) {
      final double d = value <= charge ? value : charge;
      return (d, charge - d);
    }
    final double pct = (value / 100).clamp(0, 1);
    final double d = charge * pct;
    return (d, charge - d);
  }
}
