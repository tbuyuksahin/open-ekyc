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
  ),

  /// A passport data page (ICAO TD3): portrait and MRZ on the same page.
  passport(
    aspectRatio: 125 / 88,
    sides: [DocumentSide.front],
    mrzSide: DocumentSide.front,
  );

  const DocumentKind({
    required this.aspectRatio,
    required this.sides,
    required this.mrzSide,
  });

  /// Width divided by height.
  final double aspectRatio;

  /// The sides worth capturing, in order.
  final List<DocumentSide> sides;

  /// The side that carries the machine readable zone.
  final DocumentSide mrzSide;

  /// Whether [side] carries the machine readable zone.
  bool hasMrzOn(DocumentSide side) => side == mrzSide;
}
