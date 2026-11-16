import 'package:icao_mrz/icao_mrz.dart';

/// A side of an identity document.
enum DocumentSide {
  /// The side with the portrait (the data page of a passport).
  front,

  /// The reverse of a card.
  back,
}

/// The physical document being captured.
enum DocumentKind {
  /// An ID-1 card (ICAO TD1): portrait on the front, MRZ on the back.
  idCard(
    aspectRatio: 85.6 / 53.98,
    sides: [DocumentSide.front, DocumentSide.back],
    mrzSide: DocumentSide.back,
    mrzFormat: MrzFormat.td1,
    mrzZoneHeight: 17.9 / 53.98,
  ),

  /// A passport data page (ICAO TD3): portrait and MRZ on the same page.
  passport(
    aspectRatio: 125 / 88,
    sides: [DocumentSide.front],
    mrzSide: DocumentSide.front,
    mrzFormat: MrzFormat.td3,
    mrzZoneHeight: 23.2 / 88,
  );

  const DocumentKind({
    required this.aspectRatio,
    required this.sides,
    required this.mrzSide,
    required this.mrzFormat,
    required this.mrzZoneHeight,
  });

  /// Width divided by height.
  final double aspectRatio;

  /// The sides worth capturing, in order.
  final List<DocumentSide> sides;

  /// The side that carries the machine readable zone.
  final DocumentSide mrzSide;

  /// The layout of its machine readable zone.
  final MrzFormat mrzFormat;

  /// Height of the machine readable zone as a fraction of the document
  /// height, from ICAO 9303.
  final double mrzZoneHeight;

  /// Whether [side] carries the machine readable zone.
  bool hasMrzOn(DocumentSide side) => side == mrzSide;
}
