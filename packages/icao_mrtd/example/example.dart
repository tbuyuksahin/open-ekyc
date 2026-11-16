// The example prints to show the API; never log real chip data.
// ignore_for_file: avoid_print
import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:icao_mrtd/testing.dart';
import 'package:icao_mrz/icao_mrz.dart';

Future<void> main() async {
  const lines = [
    'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
    'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
  ];
  final key = Mrz.parse(lines).key;

  // A virtual chip signed by a throw-away CSCA stands in for a real
  // document; with a phone, pass your NFC transceiver instead.
  final pki = TestPki(cscaKey: TestKeyType.ecdsaP256);
  final dg1 = LdsBuilder.dg1(lines);
  final chip = VirtualMrtd(
    key: key,
    files: {
      LdsFile.dg1: dg1,
      LdsFile.sod: LdsBuilder.sod(
        dataGroups: {1: dg1},
        signer: pki.documentSigner,
      ),
    },
  );

  final reader = MrtdReader(chip);
  await reader.openSession(key);
  final readDg1 = await reader.readFile(LdsFile.dg1);
  final sod = EfSod.parse(await reader.readFile(LdsFile.sod));

  final result = verifyPassiveAuthentication(
    sod: sod,
    dataGroups: {1: readDg1},
    trustStore: CscaStore([pki.csca.certificate]),
  );
  print('Passive Authentication: ${result.status.name}');
  print('Failures: ${result.failures}');
}
