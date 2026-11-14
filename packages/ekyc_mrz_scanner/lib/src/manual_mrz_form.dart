import 'package:ekyc_mrz_scanner/src/mrz_input.dart';
import 'package:flutter/services.dart';
import 'package:icao_mrz/icao_mrz.dart';
import 'package:material_ui/material_ui.dart';

/// Texts of [ManualMrzForm]. The defaults are English; pass your own
/// localized values.
@immutable
class MrzFormLabels {
  /// Creates labels, defaulting to English.
  const MrzFormLabels({
    this.instructions =
        'Enter the document number, date of birth and expiry date exactly '
        'as printed on the document.',
    this.documentNumber = 'Document number',
    this.dateOfBirth = 'Date of birth',
    this.dateOfExpiry = 'Expiry date',
    this.dateHint = 'DD.MM.YYYY',
    this.invalidNumber = 'Use only letters and digits.',
    this.invalidDate = 'Enter a valid date as DD.MM.YYYY.',
    this.birthInFuture = 'The date of birth cannot be in the future.',
    this.expiryBeforeBirth = 'The expiry date must be after the birth date.',
    this.submit = 'Continue',
    this.scanWithCamera = 'Scan with the camera',
  });

  /// Shown above the fields.
  final String instructions;

  /// Document number field label.
  final String documentNumber;

  /// Date of birth field label.
  final String dateOfBirth;

  /// Expiry date field label.
  final String dateOfExpiry;

  /// Placeholder of the date fields.
  final String dateHint;

  /// Error for a malformed document number.
  final String invalidNumber;

  /// Error for a malformed or impossible date.
  final String invalidDate;

  /// Error for a birth date after today.
  final String birthInFuture;

  /// Error for an expiry date on or before the birth date.
  final String expiryBeforeBirth;

  /// Submit button.
  final String submit;

  /// Button that switches back to the camera.
  final String scanWithCamera;
}

/// The three fields that make up the chip access (BAC) key, with
/// validation.
///
/// The fields are cleared when the form is disposed so the values do not
/// linger in memory longer than needed.
class ManualMrzForm extends StatefulWidget {
  /// Creates the form.
  const ManualMrzForm({
    required this.onSubmit,
    this.onScan,
    this.prefill,
    this.errorText,
    this.labels = const MrzFormLabels(),
    this.now,
    super.key,
  });

  /// Receives the key built from valid input.
  final ValueChanged<MrzKey> onSubmit;

  /// Shows a button to go back to the camera when set.
  final VoidCallback? onScan;

  /// Values to start with, for example after a failed chip read.
  final MrzKey? prefill;

  /// An error to show above the fields.
  final String? errorText;

  /// Texts.
  final MrzFormLabels labels;

  /// "Today", for validating the birth date; injected by tests.
  final DateTime? now;

  @override
  State<ManualMrzForm> createState() => _ManualMrzFormState();
}

class _ManualMrzFormState extends State<ManualMrzForm> {
  final _form = GlobalKey<FormState>();
  late final _number = TextEditingController(
    text: widget.prefill?.documentNumber.replaceAll('<', ''),
  );
  late final _dob = TextEditingController(
    text: _format(widget.prefill?.dateOfBirth.asBirthDate()),
  );
  late final _doe = TextEditingController(
    text: _format(widget.prefill?.dateOfExpiry.asExpiryDate()),
  );

  static String _format(DateTime? d) => d == null ? '' : MrzInput.formatDate(d);

  @override
  void dispose() {
    for (final c in [_number, _dob, _doe]) {
      c
        ..clear()
        ..dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final key = MrzInput.toKey(
      documentNumber: _number.text,
      dateOfBirth: MrzInput.parseDate(_dob.text),
      dateOfExpiry: MrzInput.parseDate(_doe.text),
    );
    if (key != null) widget.onSubmit(key);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.labels;
    final now = widget.now ?? DateTime.now();
    final dateFormatter = FilteringTextInputFormatter.allow(RegExp('[0-9.]'));
    final error = widget.errorText;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          if (error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(error),
              ),
            ),
          Text(l.instructions),
          TextFormField(
            controller: _number,
            decoration: InputDecoration(labelText: l.documentNumber),
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            validator: (v) =>
                MrzInput.isValidNumber(v ?? '') ? null : l.invalidNumber,
          ),
          TextFormField(
            controller: _dob,
            decoration: InputDecoration(
              labelText: l.dateOfBirth,
              hintText: l.dateHint,
            ),
            keyboardType: TextInputType.datetime,
            inputFormatters: [dateFormatter],
            enableSuggestions: false,
            validator: (v) {
              final date = MrzInput.parseDate(v ?? '');
              if (date == null) return l.invalidDate;
              if (date.isAfter(now)) return l.birthInFuture;
              return null;
            },
          ),
          TextFormField(
            controller: _doe,
            decoration: InputDecoration(
              labelText: l.dateOfExpiry,
              hintText: l.dateHint,
            ),
            keyboardType: TextInputType.datetime,
            inputFormatters: [dateFormatter],
            enableSuggestions: false,
            validator: (v) {
              final date = MrzInput.parseDate(v ?? '');
              if (date == null) return l.invalidDate;
              final dob = MrzInput.parseDate(_dob.text);
              if (dob != null && !date.isAfter(dob)) {
                return l.expiryBeforeBirth;
              }
              return null;
            },
          ),
          FilledButton(onPressed: _submit, child: Text(l.submit)),
          if (widget.onScan != null)
            OutlinedButton.icon(
              onPressed: widget.onScan,
              icon: const Icon(Icons.document_scanner_outlined),
              label: Text(l.scanWithCamera),
            ),
        ],
      ),
    );
  }
}
