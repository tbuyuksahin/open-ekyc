/// Read ICAO 9303 eMRTD chips over any NFC transport.
///
/// * `MrtdReader` opens a BAC session and reads LDS files.
/// * `parseDg1`, `parseDg2`, `Dg11` and `EfCom` decode the files.
/// * `verifyPassiveAuthentication` proves the data was signed by a
///   trusted state.
library;

export 'src/apdu.dart';
export 'src/bac.dart';
export 'src/crypto/des.dart' show constantTimeEquals;
export 'src/errors.dart';
export 'src/lds/dg1.dart';
export 'src/lds/dg11.dart';
export 'src/lds/dg2.dart';
export 'src/lds/ef_com.dart';
export 'src/lds/lds_file.dart';
export 'src/mrtd_reader.dart';
export 'src/pa/algorithms.dart'
    show
        AlgorithmIdentifier,
        EcPublicKeyInfo,
        HashAlgorithm,
        PublicKeyInfo,
        RsaPublicKeyInfo;
export 'src/pa/ef_sod.dart';
export 'src/pa/passive_authentication.dart';
export 'src/pa/x509.dart';
export 'src/secure_messaging.dart';
export 'src/tlv.dart';
