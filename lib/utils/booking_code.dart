bool isLegacyKdtBookingCode(String? code) {
  final savedCode = code?.trim() ?? '';
  return savedCode.isEmpty || savedCode.toUpperCase().startsWith('KDT-');
}

String appointmentBookingCode(String appointmentId) {
  var hash = 17;
  for (final codeUnit in appointmentId.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  final sequence = (1000 + hash % 9000).toString();
  final reference = (10000000 + hash % 90000000).toString();
  return 'EMR-$sequence-$reference';
}

String canonicalBookingCode({
  required String appointmentId,
  String? storedCode,
}) {
  if (isLegacyKdtBookingCode(storedCode)) {
    return appointmentBookingCode(appointmentId);
  }
  return storedCode!.trim();
}
