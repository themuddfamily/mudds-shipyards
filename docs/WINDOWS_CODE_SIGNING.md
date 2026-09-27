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

A publicly trusted Authenticode certificate (OV or EV) exported as a PFX/PKCS#12
file is required. Keep it outside the repository.

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
`"trusted_signing_claimed": false`: `osslsigncode verify` on Linux checks the
signature and chain against the local CA bundle, but only a native Windows check
(`Get-AuthenticodeSignature`, SmartScreen reputation) qualifies trust. That gate
stays `NOT_RUN` until performed on Windows.

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

- Acquire a publicly trusted code-signing certificate (not done).
- Native Windows check of a signed build: `Get-AuthenticodeSignature` reports
  `Valid`, the installer's UAC/SmartScreen prompt names the publisher (NOT_RUN).
- Hardware-token (EV) signing needs a PKCS#11 flow (`osslsigncode -pkcs11engine`),
  which this script does not implement yet.
