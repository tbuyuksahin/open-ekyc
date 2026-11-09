/// Test doubles for code that reads eMRTD chips: a virtual chip, LDS file
/// builders and a throw-away PKI.
///
/// Never ship these in production code paths.
library;

export 'src/testing/lds_builder.dart';
export 'src/testing/test_pki.dart' show TestIdentity, TestKeyType, TestPki;
export 'src/testing/virtual_mrtd.dart' show TagLostException, VirtualMrtd;
