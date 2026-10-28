# Windows code signing

Mudd's Shipyards Windows artifacts (the exported `MuddsShipyards-<commit>.exe`,
the NSIS installer and its embedded uninstaller) can be Authenticode-signed
with [osslsigncode](https://github.com/mtrojnar/osslsigncode) from Linux.

**Status: no trusted certificate is configured for this project.** Every build
published so far is unsigned. The tooling below is ready for a real
certificate, and has a development mode that exists only to exercise the
pipeline. A dev-signed file is *not* a signed release: Windows does not trust
the throwaway certificate, SmartScreen still warns, and every record the
tooling writes labels it `UNTRUSTED`.

## Tools

| Script | Purpose |
| --- | --- |
| `tools/release/sign_windows_artifacts.sh` | Sign and/or verify `.exe` files; writes a JSON verification record. |
| `tools/release/build_windows_installer.sh` | Builds the installer; signs when `MUDDS_INSTALLER_SIGN` is set. |

Install the signer once: `sudo apt-get install -y osslsigncode` (openssl is
needed too, for dev mode).

## Signing with a real certificate

The implemented signer accepts an Authenticode certificate and key supplied as
a PFX/PKCS#12 file. Keep it outside the repository. The owner must provide its
public identity and authorized credential access; hardware-token signing needs
the separate capability noted below.

```bash
export MUDDS_SIGNING_PFX=/secure/path/mudds-codesign.pfx
export MUDDS_SIGNING_PASSWORD='…'                      # read from env, never argv
export MUDDS_SIGNING_TIMESTAMP_URL=http://timestamp.digicert.com   # optional RFC 3161 TSA

# Sign a single exported executable and verify it:
tools/release/sign_windows_artifacts.sh builds/windows/MuddsShipyards-abc1234.exe

# Or sign everything while building the installer:
MUDDS_INSTALLER_SIGN=pfx tools/release/build_windows_installer.sh \
    builds/windows/MuddsShipyards-abc1234.exe
```

With `MUDDS_INSTALLER_SIGN=pfx` the installer build:

1. signs the exported EXE in place, before it is embedded (so the installed
   game is signed too);
2. signs the uninstaller through makensis' `!uninstfinalize` hook, before it is
   embedded in the installer (NSIS 3.08 or newer);
3. signs the finished installer and runs `osslsigncode verify` on it and on the
   EXE, writing `<installer>.signing-result.json` and
   `<exe>.signing-result.json`;
4. records `"signing": "authenticode-pfx"` in `<installer>.installer-result.json`
   and in the installed `source-commit.txt`.

The password is written to a mode-600 file in a private temporary directory
(removed on exit) and passed with `-readpass`; it never appears on a command
line. Timestamping is strongly recommended for real releases so signatures stay
valid after the certificate expires; it needs network access to the TSA.

A PFX run still records `"trust": "PFX_SUPPLIED_WINDOWS_TRUST_NOT_RUN"` and
`"trusted_signing_claimed": false`. Its implicit local verification does not
enforce the expected publisher, certificate fingerprint or declared CA context.
SIGN-FINAL requires the explicit applicable-tool checks below. Native Windows
execution and mandatory human review remain owner-excluded; Windows trust-store
and SmartScreen observations remain factual `NOT_RUN`, not newly required gates.

## Development mode (untrusted, pipeline testing only)

```bash
unset MUDDS_SIGNING_PFX
tools/release/sign_windows_artifacts.sh --dev-self-signed MuddsShipyards-abc1234.exe
MUDDS_INSTALLER_SIGN=dev-self-signed tools/release/build_windows_installer.sh MuddsShipyards-abc1234.exe
```

`--dev-self-signed` creates (or reuses, while more than a day from expiry) a
30-day self-signed code-signing certificate named
`CN=Mudds Shipyards DEV UNTRUSTED` in `MUDDS_DEV_SIGNING_DIR`
(default `~/.cache/mudds-shipyards/dev-signing`, mode 700, files mode 600). It
refuses to put that directory inside the repository and refuses to run while
`MUDDS_SIGNING_PFX` is set, so a release run cannot silently fall back to it.
Verification trusts only that dev certificate (`-CAfile`). Records say
`"trust": "UNTRUSTED_DEV_SELF_SIGNED"` and the installer is labelled
`dev-self-signed-UNTRUSTED`. Never publish a dev-signed build as signed.

## Verification record

`sign_windows_artifacts.sh` writes (schema_version 1):

```json
{
  "schema_version": 1,
  "mode": "pfx | dev-self-signed | verify-only | verify-only-dev-self-signed",
  "trust": "PFX_SUPPLIED_WINDOWS_TRUST_NOT_RUN | UNTRUSTED_DEV_SELF_SIGNED | …",
  "trusted_signing_claimed": false,
  "timestamp_url": null,
  "artifacts": [{"path": "…", "sha256_before": "…", "sha256_after": "…",
                 "signed_by_this_run": true,
                 "verify": {"tool": "osslsigncode verify", "exit_code": 0,
                            "status": "ok", "signer_subject": "…", "log_tail": []}}],
  "all_verified": true,
  "native_windows_verification": "NOT_RUN"
}
```

The script exits 0 only when every artifact verified, 1 when a verification
failed (the JSON is still written), and 2 for usage/environment errors.
`--dry-run` validates arguments, environment and artifacts and prints the plan
without signing or writing anything. `--verify-only` checks existing
signatures.

## Remaining gates

- Obtain the owner's certificate identity, expected publisher and authorized
  signing access; bind the actual applicable trust context below.
- Complete applicable-tool verification of all three signed members and their
  final package identity. Native Windows facts remain excluded/`NOT_RUN`.
- Hardware-token (EV) signing needs a PKCS#11 flow (`osslsigncode -pkcs11engine`),
  which this script does not implement yet.

## SIGN-FINAL: finite artifacts, trust context and acceptance

This is the contract for the existing SIGN-FINAL goal. Prerequisites are the
frozen PACKAGE-FINAL candidate and INSTALL-WIN-FINAL's compilation/extraction
capability, with rights decisions retained by their existing owners. It defines
no new signing targets or authorization to sign, install or publish now.

Let C be the frozen full source commit and S its seven-character prefix. Exact
actual paths and byte hashes bind at selection; no future final hash is invented.

| Existing member | Default selected path / matching embedded bytes |
| --- | --- |
| Game | `builds/windows/MuddsShipyards-S.exe`; installed `MuddsShipyards.exe`, extracted staging name `MuddsShipyards.exe.pending` |
| Setup | `builds/windows/MuddsShipyards-S-setup.exe`; an explicitly bound second builder argument may supply the existing installer naming variant |
| Uninstaller | `<exact-setup-path>.uninstall.exe`; must equal the finalized embedded `uninstall.exe` |

The existing builder signs the game, signs the temporary NSIS uninstaller,
copies that finalized uninstaller, embeds it, signs setup, then verifies all
three and writes their post-sign sizes/SHA256 in the existing schema1
`<setup>.installer-result.json`. Its three existing signing-result files and
`<setup>.sha256` remain the record owners. Do not sign the exported uninstaller
after embedding or call pre-sign game hashes the signed result. Source identity
C and version must agree across the game, setup and installed metadata.

**Exact owner inputs:** expected public leaf certificate PEM, its SHA256 over
DER bytes, exact publisher subject in RFC2253 form, authorized credential access
outside the repo, and the applicable signer CA bundle plus TSA bundle when
timestamped, with their provenance.
Record the selected timestamp URL or explicit absence. A certificate/key input
alone is not a decision that its issuer is trusted. If the owner supplies a
hardware key instead of PFX, implement that production path before selection;
do not export a key or silently substitute development credentials.

**Applicable verification recipe.** Pin an installed osslsigncode version that
supports the following upstream-documented flags. For each of the three actual
paths, run from the selected proof directory with these literal input variables:

```bash
osslsigncode verify -in "$SIGNED_MEMBER" \
  -CAfile "$SIGNER_CA_BUNDLE" -TSA-CAfile "$TSA_CA_BUNDLE" \
  -require-leaf-hash "sha256:$EXPECTED_LEAF_SHA256" -verbose
openssl x509 -in "$EXPECTED_CERT_PEM" -noout -subject -nameopt RFC2253
openssl x509 -in "$EXPECTED_CERT_PEM" -outform DER | sha256sum
sha256sum -- "$SIGNED_MEMBER"
```

`-CAfile` binds signer trust, `-TSA-CAfile` timestamp trust and
`-require-leaf-hash` the DER-encoded signer certificate. Verification must exit0;
do not use timestamp/revocation-ignore flags. These options and exit semantics
come from the [upstream osslsigncode manual](https://github.com/mtrojnar/osslsigncode/blob/master/osslsigncode.md).
The actual selected tool must expose them; upstream syntax is not proof an
uninstalled/older tool supports the command. Omit only the TSA-bundle option
when the selected artifact has no timestamp; do not ignore an existing one.

Require the public certificate DER hash/publisher to match the owner's exact
values, and all three member verifiers to pin that leaf and succeed against
the declared bundles/time/revocation context. Retain full stdout/stderr and
actual exit codes, not only the current signer's twelve-line log tail. Record
tool/OpenSSL version, bundle paths/byte hashes, UTC verification time, timestamp
presence/authority/result and network/revocation availability. An unavailable
chain/revocation input is an unresolved verification result, not a pass; no
adding the development leaf to trusted roots to make verification succeed.
An absent optional timestamp is recorded honestly and makes no future-expiry
promise. The default target is one expected leaf signature per member; if the
candidate actually contains additional signatures, enumerate and verify each
using the selected tool's indexed operation before accepting all members.

This proves identity and cryptographic trust in the declared applicable context.
It does not assert Windows-store trust, SmartScreen reputation, native execution
or human inspection. Existing JSON fields retaining Windows `NOT_RUN` and
`trusted_signing_claimed=false` must remain honest; they do not substitute for
the applicable result or become a reason to lift the execution exclusion.

**Named Codex pipeline gaps:** the current signing wrapper neither pins an
expected leaf/publisher nor records explicit signer/TSA bundles and full logs.
Extend that existing wrapper/result consumer for these production checks; no
new validator/schema family. Current PATH has no osslsigncode at this mapping;
install/pin the required tool before a selected run, not as a new owner policy.

Both `tools/release/package_inventory.py:find_pck` and the artifact check in
`tools/release/release_candidate.py` require the GDPC trailer at literal EOF.
An appended Authenticode certificate table is therefore a likely incompatible
layout; this is a source inference, not a tested signed-Godot failure. Add
bounded PE-certificate-aware PCK handling in these existing readers, preserving
exact payload bounds/digests and rejection of malformed/overlapping/truncated
tables, before claiming signed-package inventory parity. The existing signer
argument tests and mocked NSIS ordering do not prove real signed-Godot startup.

Signing changes EXE bytes. Rebuild the existing two-file checkpoint ZIP from
the signed game/notes; regenerate complete inventories/candidate records and
final checksums from the resulting bytes. Keep complete source/payload parity
and strict package startup checks on those exact final artifacts. The existing
release_candidate SHA256SUMS covers only its EXE/release JSON; final distribution
must also bind actual setup/uninstaller/archives under the existing release
handoff. Extraction must reproduce the signed game and finalized uninstaller
byte-for-byte. No stale unsigned ZIP/inventory/startup hash qualifies them.

**Limits and result location:** retain INSTALL-WIN-FINAL's600s compile limit,
all existing export/startup/package caps and owned cleanup. At selection bind
one900s inner/960s outer signing/build/verification target, including that
unchanged compile cap, with the actual absolute deadline and independent abort;
do not borrow time from excluded native runs. If unfinished or a predicate
fails, preserve the first failure and stop under the existing correction rules.
The existing adjacent result files own member hashes; full verification output
and public identity/context inputs go under
`/srv/mudds-work/sign-final/` for the frozen candidate. Never store private keys,
passwords or credential dumps in that proof. Exact selected command paths,
three-member success, unchanged verified bytes and matching packaged artifacts
are required. Missing credentials/context, reader/caller support or actual
verification keeps SIGN-FINAL OPEN. DISTRIBUTE remains the separate authorized
publication/downloaded-byte step; this definition selects none of those actions.
