// The example prints to show the API; never log real MRZ data.
// ignore_for_file: avoid_print
import 'package:icao_mrz/icao_mrz.dart';

void main() {
  final mrz = Mrz.parse(const [
    'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
    'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
  ]);

  print('Valid: ${mrz.isValid}');
  print('Holder: ${mrz.secondaryIdentifier} ${mrz.primaryIdentifier}');
  print('Born: ${mrz.dateOfBirth.asBirthDate()}');
  print('BAC input: ${mrz.key.information}');
}
