# Parser autodetection implementation plan

User-authorised scope: automatically detect encoding/separator, test the real Venezia dataset, show results before any commit/push. Keep the existing manual controls and immutable configuration history.

Use a deterministic bounded detector rather than a statistical dependency: BOMs identify UTF-8/UTF-16LE/BE; valid UTF-8 without NUL is accepted as compatible; unsupported/ambiguous byte encodings remain explicit. Compare comma/semicolon/tab/pipe using the same strict quote-aware lexer as previews; require a unique consistent multi-column candidate across at least header plus one data record. A file extension is only a fallback, never evidence. Decimal conventions, scientific roles, dates and schemas are not inferred.

New uploads run detection on their owned copies and freeze chosen settings plus per-resource evidence in configuration revision 1. Archives retain their declaration-driven parser. An explicit Detect format action on a latest existing revision creates a new snapshot for the selected resource. Manual edits preserve the detection evidence, while the interface indicates differences from detected settings. Historical configurations never change.

Files: R/parser_detection.R (bounded pure detector), R/service_workspace.R (registration/detection orchestration), R/repository_configuration.R and input_profiles.R (optional backward-compatible evidence), R/mod_workspace.R (display and guarded explicit rerun). Tests cover BOM variants, UTF-8, quoted separators, ambiguous/single-column/malformed/unsupported input, resource isolation, manual overrides, stale contexts and the exact Venezia file through upload service.

Acceptance: Venezia registers with UTF-16LE/tab automatically and previews 20 rows x 235 columns without manual settings, original SHA-256 unchanged; a previous UTF-8 snapshot remains retrievable after explicit redetection. Run full suite and package check, independent final review, restart only the task-owned local server and show the browser result. No commit or push.
