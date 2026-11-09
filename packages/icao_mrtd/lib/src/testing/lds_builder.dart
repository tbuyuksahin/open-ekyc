import 'dart:convert';
import 'dart:typed_data';

import 'package:icao_mrtd/src/lds/lds_file.dart';
import 'package:icao_mrtd/src/pa/algorithms.dart';
import 'package:icao_mrtd/src/testing/der_writer.dart';
import 'package:icao_mrtd/src/testing/test_pki.dart';
import 'package:icao_mrtd/src/tlv.dart';

/// Builders for LDS files with synthetic content, for tests and demos.
abstract final class LdsBuilder {
  /// EF.COM listing [groups].
  static Uint8List com(List<LdsFile> groups) => encodeTlv(0x60, [
    ...encodeTlv(0x5F01, ascii.encode('0107')),
    ...encodeTlv(0x5F36, ascii.encode('040000')),
    ...encodeTlv(0x5C, [for (final g in groups) g.tag]),
  ]);

  /// DG1 holding the MRZ [lines].
  static Uint8List dg1(List<String> lines) =>
      encodeTlv(0x61, encodeTlv(0x5F1F, ascii.encode(lines.join())));

  /// DG2 holding [image] in an ISO/IEC 19794-5 record.
  static Uint8List dg2(
    Uint8List image, {
    bool jpeg2000 = false,
    int width = 240,
    int height = 320,
    int featurePoints = 0,
  }) {
    final imageInfo = ByteData(12)
      ..setUint8(0, 1) // full frontal
      ..setUint8(1, jpeg2000 ? 1 : 0)
      ..setUint16(2, width)
      ..setUint16(4, height);
    final facialInfo = ByteData(20)..setUint16(4, featurePoints);
    final points = Uint8List(featurePoints * 8)
      ..fillRange(0, featurePoints * 8, 0xFF);
    final recordLength = 20 + points.length + 12 + image.length;
    facialInfo.setUint32(0, recordLength);
    final header = ByteData(14)
      ..setUint32(8, 14 + recordLength)
      ..setUint16(12, 1);
    final record = Uint8List.fromList([
      ...ascii.encode('FAC'), 0, ...ascii.encode('010'), 0, //
      ...header.buffer.asUint8List(8),
      ...facialInfo.buffer.asUint8List(),
      ...points,
      ...imageInfo.buffer.asUint8List(),
      ...image,
    ]);
    return encodeTlv(
      0x75,
      encodeTlv(0x7F61, [
        ...encodeTlv(0x02, [1]),
        ...encodeTlv(0x7F60, [
          ...encodeTlv(0xA1, encodeTlv(0x80, [1, 1])),
          ...encodeTlv(0x5F2E, record),
        ]),
      ]),
    );
  }

  /// DG11 with the given UTF-8 fields.
  static Uint8List dg11({
    String? fullName,
    String? personalNumber,
    String? fullDateOfBirth,
    String? placeOfBirth,
  }) {
    final fields = <int, String?>{
      0x5F0E: fullName,
      0x5F10: personalNumber,
      0x5F2B: fullDateOfBirth,
      0x5F11: placeOfBirth,
    }..removeWhere((_, v) => v == null);
    return encodeTlv(0x6B, [
      ...encodeTlv(0x5C, [
        for (final t in fields.keys) ...[t >> 8, t & 0xFF],
      ]),
      for (final MapEntry(:key, :value) in fields.entries)
        ...encodeTlv(key, utf8.encode(value!)),
    ]);
  }

  /// A minimal JPEG-shaped byte string (SOI marker, payload, EOI marker).
  static Uint8List fakeJpeg([int size = 64]) => Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, //
    for (var i = 0; i < size; i++) i & 0xFF,
    0xFF, 0xD9,
  ]);

  /// EF.SOD over [dataGroups], signed by [signer].
  ///
  /// The `corrupt*` flags let tests break individual steps.
  static Uint8List sod({
    required Map<int, Uint8List> dataGroups,
    required TestIdentity signer,
    HashAlgorithm hash = HashAlgorithm.sha256,
    bool includeCertificate = true,
    bool corruptSignature = false,
    bool corruptMessageDigest = false,
  }) {
    final hashAlg = Der.algorithm(hash.oid);
    final lds = Der.seq([
      Der.smallInt(0),
      hashAlg,
      Der.seq([
        for (final MapEntry(:key, :value) in dataGroups.entries)
          Der.seq([Der.smallInt(key), Der.octets(hash.hash(value))]),
      ]),
    ]);
    final digest = hash.hash(lds);
    if (corruptMessageDigest) digest[0] ^= 0xFF;
    final attributes = [
      Der.seq([
        Der.oid(Oids.contentType),
        Der.set([Der.oid(Oids.ldsSecurityObject)]),
      ]),
      Der.seq([
        Der.oid(Oids.messageDigest),
        Der.set([Der.octets(digest)]),
      ]),
    ];
    final signedAttrs = Der.set(attributes);
    final signature = signer.sign(signedAttrs);
    if (corruptSignature) signature[signature.length - 3] ^= 0x01;
    final cert = signer.certificate;
    final signerInfo = Der.seq([
      Der.smallInt(1),
      Der.seq([cert.issuer.encoded, Der.integer(cert.serialNumber)]),
      hashAlg,
      Uint8List.fromList(signedAttrs)..[0] = 0xA0,
      Der.algorithm(signer.signatureOid),
      Der.octets(signature),
    ]);
    final signedData = Der.seq([
      Der.smallInt(3),
      Der.set([hashAlg]),
      Der.seq([
        Der.oid(Oids.ldsSecurityObject),
        Der.explicit(0, Der.octets(lds)),
      ]),
      if (includeCertificate) Der.explicit(0, cert.encoded),
      Der.set([signerInfo]),
    ]);
    return encodeTlv(
      0x77,
      Der.seq([Der.oid(Oids.signedData), Der.explicit(0, signedData)]),
    );
  }
}
