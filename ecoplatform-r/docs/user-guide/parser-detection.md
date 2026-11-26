# Automatic encoding and separator detection

## Using the application

For a new CSV/TSV upload, press Register inputs as usual. The first configuration applies supported encoding/separator evidence automatically and displays a detection summary above the parser controls. No manual settings are required when both components are unambiguous.

For a previously registered file, select its latest configuration in Data and configuration and press **Detect format**. This saves a new revision; the old UTF-8/default snapshot remains retrievable. Then press Generate preview. Historical configurations cannot be silently edited or redetected.

Manual overrides remain available. Save them explicitly as a new revision. The original detection evidence is retained separately; the summary identifies manual differences in encoding/separator instead of claiming the override was detected. Changing a dropdown alone still writes nothing.

## Venezia dataset acceptance

File: VE_12_ACTRMO0038_Dati macrozoobenthos Venezia 2011.csv.

- Encoding: UTF-16LE, identified by the FF FE byte-order mark.
- Separator: tab, the unique consistent multi-column candidate in the quote-aware sample.
- Initial configuration: revision 1 already uses the detected settings.
- Preview: 20 rows and 235 columns, with no manual parser settings supplied.
- Source SHA-256: 400b674669fbb216af1ab3836050cb4a4689aa58dc04f1d9433d6880f30afa20, unchanged by registration, detection and preview.
- A separately tested legacy UTF-8 configuration is repaired by explicit redetection into revision 2 while revision 1 stays unchanged.

Reproduce from ecoplatform-r/ with `Rscript --vanilla tools/test-autodetection-venezia.R`. Set ECODATA_VENEZIA_FILE if the original dataset is elsewhere. The script uses a fresh temporary runtime and writes only technical acceptance evidence under evidence/autodetection; it does not add the dataset to Git.

## Detection rules and limitations

The detector reads at most 1 MiB by default (configurable up to 2 MiB), records the sample size/hash, algorithm version and per-component evidence, and binds the result to the registered resource's full SHA-256. A UTF-8/UTF-16LE/UTF-16BE BOM identifies the byte order. Without a BOM, NUL-free valid UTF-8 is considered compatible. UTF-32 BOMs are recognised but unsupported; UTF-16 without a BOM and legacy encodings are not guessed. In particular, windows-1252 and latin1 can be indistinguishable from bytes alone.

After decoding, comma, semicolon, tab and pipe are compared using the existing strict quoted-field lexer. A separator needs at least two sampled records, more than one column and consistent field counts, with exactly one viable candidate. A tie, one-column text, header-only input, malformed quoting or insufficient sample yields a review message. For a truncated sample only a final incomplete Unicode code point may be trimmed for detection; complete-file malformed bytes are never discarded.

Trimming is allowed only for structurally valid incomplete UTF-8 sequences or UTF-16 units/surrogate prefixes. Intrinsically invalid bytes and isolated low surrogates remain errors. A truncated final lexical record is excluded from separator scoring, preserving quote-aware complete record boundaries; it cannot turn an ambiguous sample into a false unique match.

Only detected components replace prior settings. Unresolved components keep the existing value/default and remain visibly flagged. ZIP/DwC-A members retain their declaration-driven configuration. Decimal conventions, quote conventions, scientific roles, schema, units and date interpretation are not automatically inferred; existing quote settings are respected when redetecting separators.

Detection is based on a bounded sample, not proof of whole-file structural validity. It does not alter original bytes and is not scientific validation.
