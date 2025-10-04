/// Enhanced enums with intrinsic label fields to avoid reliance on extensions
/// (prevents NoSuchMethodError when an extension import is accidentally omitted).
enum TreatmentType {
  general('General'),
  orthodontic('Orthodontic'),
  rootCanal('Root Canal'),
  labWork('Lab Work');

  const TreatmentType(this.label);
  final String label;
}

enum Sex {
  male('M'),
  female('F'),
  other('Other');

  const Sex(this.label);
  final String label;
}

enum InvestigationType {
  iopar('IOPAR'),
  opg('OPG'),
  cbct('CBCT');

  const InvestigationType(this.label);
  final String label;
}

enum BracketType {
  metalRegular('Metal Regular'),
  metalPremium('Metal Premium');

  const BracketType(this.label);
  final String label;
}
