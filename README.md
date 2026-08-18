# cc-signatif

SIGNATIF — Sealed Interoperable Graduated Non-repudiable Anchored Trust
Infrastructure Framework (ISO/TC 154 working draft).

From Latin *signare*, "to mark with a seal, to sign": trustworthiness is
established by what is verifiably signed, not by who is trusted.

- Standard source: `spec/signatif-standard/`
- Website: https://signatif.github.io (and https://www.signatif.org)

## Building the standard

The standard is written in Metanorma AsciiDoc and compiled with
[Metanorma](https://www.metanorma.org) (ISO flavor):

```
gem install metanorma metanorma-iso
cd spec/signatif-standard
metanorma document.adoc
```

Outputs (`document.html`, `document.xml`, `document.pdf`) are generated
in place. Every push and pull request is compiled by CI; a change that
breaks the build cannot merge.

## How the document is organized

- `document.adoc` — the document skeleton and include order.
- `sections/*.adoc` — clauses and annexes in source order.
- `sections/data/*-rc.yaml` — requirements classes (`/req/...`): one
  file per clause, one entry per requirement.
- `sections/data/*-cc.yaml` — conformance classes (`/conf/...`) and
  their abstract tests, targeting the requirements.
- `sections/templates/*.liquid` — the templates that render the YAML
  into formal requirement and conformance blocks inside the clauses.

Requirements and conformance tests live in structured YAML so they stay
machine-readable; edit the YAML to change a requirement, and the clause
text and Annex A render from it. The registry currently holds 113
requirements across 14 classes, each paired with a conformance test.

## Contributing

Changes go through pull requests. Keep requirement statements
self-contained and testable (`shall`), put explanation in guidance, and
compile locally before pushing.
