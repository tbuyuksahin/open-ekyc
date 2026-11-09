/// Elementary files of the eMRTD application (ICAO 9303-10).
enum LdsFile {
  /// EF.COM: LDS version and list of present data groups.
  com(0x011E, 0x60),

  /// EF.SOD: document security object used for Passive Authentication.
  sod(0x011D, 0x77),

  /// DG1: the MRZ.
  dg1(0x0101, 0x61),

  /// DG2: encoded face.
  dg2(0x0102, 0x75),

  /// DG3: encoded fingerprints (requires Extended Access Control).
  dg3(0x0103, 0x63),

  /// DG7: displayed signature.
  dg7(0x0107, 0x67),

  /// DG11: additional personal details.
  dg11(0x010B, 0x6B),

  /// DG12: additional document details.
  dg12(0x010C, 0x6C),

  /// DG14: security options (Chip Authentication, PACE info).
  dg14(0x010E, 0x6E),

  /// DG15: Active Authentication public key.
  dg15(0x010F, 0x6F);

  const LdsFile(this.fileId, this.tag);

  /// The two-byte file identifier used with SELECT.
  final int fileId;

  /// The outer tag of the file contents.
  final int tag;

  /// The data group number, or `null` for EF.COM and EF.SOD.
  int? get dataGroup => switch (this) {
    com || sod => null,
    _ => fileId & 0xFF,
  };

  /// The data group file for [number], if supported.
  static LdsFile? forDataGroup(int number) {
    for (final f in values) {
      if (f.dataGroup == number) return f;
    }
    return null;
  }

  /// The file whose outer tag is [tag], if any. EF.COM lists data groups
  /// by tag.
  static LdsFile? forTag(int tag) {
    for (final f in values) {
      if (f.tag == tag) return f;
    }
    return null;
  }
}
