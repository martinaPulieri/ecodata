# Missing-information clarification workflow

> Use superpowers:executing-plans. User authorised implementation of the
> previously described workflow. Do not stage, commit or push before approval.

Goal: derive missing prerequisites, explain dependent checks, offer suggestions
without applying them and save exact approved answers as configuration revisions.
Architecture: existing R/Shiny workspace + Step 2B reader; approved receipt JSON
in append-only configuration snapshots. SQLite remains v2.
Spec: latest user request and the preceding workflow explanation in chat.

Tasks:
- [x] Typed questions/drafts/approval services with tests first.
  R/clarification_questions.R, R/service_clarifications.R, configuration
  inheritance and prerequisites; parser/date/missing archive-key answers,
  source-repair notes, explicit approval and no writes during preparation.
- [x] Shiny clarification tab with reason, dependency, editable answer,
  suggestions, review modal, approve/cancel and receipt history. Context,
  latest revision, actor and lifecycle guards. shiny::testServer tests.
- [x] Documentation/help, updated roadmap, isolated Venezia/synthetic acceptance,
  full tests, installed-package check, browser inspection and fresh final review.

Expected: draft/cancel create zero revisions; approval creates exactly one with
actor, time, evidence, source and previous configuration; original hashes stay
fixed; dependent prerequisites wait until approved while independent checks
remain available; an explanatory note never promotes an unreadable source.
Known descriptor keys cannot be overridden; missing keys may be supplied with
explicit user provenance. Old configurations and approvals remain readable.
Review focus: unrelated settings/mappings, multiple sessions and context changes,
source tampering, stale approvals after parser edits and unsupported archives.

Verification: 662 assertions; installed-package Status: OK; isolated Venezia/synthetic acceptance passed. Browser visual inspection remains unavailable due Windows sandbox error 1920; Shiny module interactions are automated and the local app is running. No staging/commit/push. See ecoplatform-r/docs/verification/2026-11-25-clarifications.md.

Publication approval (25 November 2026): the user approved committing and pushing
Step 2B, clarification workflow and ZIP support without meta.xml to martinaPulieri/ecodata.
Final combined verification: 772 assertions, zero failures/errors/warnings/skips; installed-package Status: OK.
