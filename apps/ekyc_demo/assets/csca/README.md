# Trusted CSCA certificates

Put PEM files (`*.pem`) of the Country Signing CA certificates you trust
here. They are loaded at startup by `loadCscaStore`.

None are committed on purpose: certificates must come from an
authoritative source (the ICAO PKD, or a state's published master list)
and be reviewed before you trust them. Without them, real documents are
reported as "signature checked, issuer not confirmed" instead of
"verified". Your server should hold the authoritative trust list anyway.
