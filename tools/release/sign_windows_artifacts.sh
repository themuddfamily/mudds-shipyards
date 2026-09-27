#!/usr/bin/env bash
# Authenticode-sign Windows release artifacts with osslsigncode, then verify.
#
# usage: sign_windows_artifacts.sh [options] <artifact.exe>...
#
#   (default)            sign with the PFX named by MUDDS_SIGNING_PFX, whose
#                        password is read from MUDDS_SIGNING_PASSWORD
#   --dev-self-signed    sign with a throwaway self-signed code-signing
#                        certificate generated under a private directory
#                        (MUDDS_DEV_SIGNING_DIR, default
#                        ${XDG_CACHE_HOME:-~/.cache}/mudds-shipyards/dev-signing).
#                        PIPELINE TESTING ONLY: Windows does not trust it and
#                        SmartScreen treats the file as unsigned-equivalent.
#   --timestamp-url URL  RFC 3161 timestamp authority (default
#                        MUDDS_SIGNING_TIMESTAMP_URL; omitted when empty)
#   --result PATH        verification JSON (default
#                        <first artifact>.signing-result.json)
#   --verify-only        do not sign; only verify and write the JSON
#   --dry-run            validate arguments, environment and artifacts, print
#                        the plan, and change nothing
#   --sign-in-place      sign only (no verify/JSON); used by makensis
#                        !uninstfinalize to sign the embedded uninstaller
#
# Artifacts are signed in place (via a temporary sibling that replaces the
# original only after osslsigncode succeeds). The password never appears on a
# command line: it is written to a mode-600 file in a private temp directory
# that is removed on exit. This script never claims trusted signing: a PFX run
# records the certificate subject and leaves Windows trust NOT_RUN, and a dev
# run is labelled UNTRUSTED everywhere it is reported.
set -euo pipefail

die() {
	printf 'sign-windows-artifacts: ERROR: %s\n' "$*" >&2
	exit 2
}

note() {
	printf 'sign-windows-artifacts: %s\n' "$*" >&2
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" \
	|| die "cannot resolve script directory"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

mode="pfx"
timestamp_url="${MUDDS_SIGNING_TIMESTAMP_URL:-}"
result_path=""
verify_only=0
dry_run=0
sign_in_place=0
artifacts=()

while (( $# > 0 )); do
	case "$1" in
		--dev-self-signed) mode="dev-self-signed"; shift ;;
		--timestamp-url)
			(( $# >= 2 )) || die "--timestamp-url needs a URL"
			timestamp_url="$2"; shift 2 ;;
		--timestamp-url=*) timestamp_url="${1#*=}"; shift ;;
		--result)
			(( $# >= 2 )) || die "--result needs a path"
			result_path="$2"; shift 2 ;;
		--result=*) result_path="${1#*=}"; shift ;;
		--verify-only) verify_only=1; shift ;;
		--dry-run) dry_run=1; shift ;;
		--sign-in-place) sign_in_place=1; shift ;;
		-h|--help)
			sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
			exit 0 ;;
		--) shift; artifacts+=("$@"); break ;;
		-*) die "unknown option: $1" ;;
		*) artifacts+=("$1"); shift ;;
	esac
done

(( ${#artifacts[@]} > 0 )) || die "usage: $0 [--dev-self-signed] [--timestamp-url URL] [--result PATH] [--verify-only] [--dry-run] <artifact.exe>..."
(( verify_only + sign_in_place <= 1 )) || die "--verify-only and --sign-in-place are mutually exclusive"
if (( sign_in_place )) && [[ -n "$result_path" ]]; then
	die "--sign-in-place writes no result; drop --result"
fi
if [[ -n "$timestamp_url" && ! "$timestamp_url" =~ ^https?://[A-Za-z0-9.-]+(:[0-9]+)?(/[^[:space:]]*)?$ ]]; then
	die "timestamp URL must be an http(s) URL (got '$timestamp_url')"
fi

resolved=()
for artifact in "${artifacts[@]}"; do
	[[ -f "$artifact" ]] || die "artifact not found: $artifact"
	# makensis hands !uninstfinalize a temporary uninstaller name without .exe.
	if (( ! sign_in_place )); then
		[[ "$artifact" == *.exe ]] || die "artifact must be a Windows .exe: $artifact"
	fi
	head_bytes="$(head -c 2 -- "$artifact" | od -An -c | tr -d ' \n')"
	[[ "$head_bytes" == "MZ" ]] || die "artifact is not a PE executable (no MZ header): $artifact"
	resolved+=("$(cd -- "$(dirname -- "$artifact")" && pwd -P)/$(basename -- "$artifact")")
done
artifacts=("${resolved[@]}")

if [[ -z "$result_path" ]] && (( ! sign_in_place )); then
	result_path="${artifacts[0]}.signing-result.json"
fi

dev_dir=""
pfx_path=""
if [[ "$mode" == "dev-self-signed" ]]; then
	dev_dir="${MUDDS_DEV_SIGNING_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/mudds-shipyards/dev-signing}"
fi
if (( ! verify_only )); then
	if [[ "$mode" == "dev-self-signed" ]]; then
		[[ -z "${MUDDS_SIGNING_PFX:-}" ]] \
			|| die "--dev-self-signed refuses to run while MUDDS_SIGNING_PFX is set; unset it to test the pipeline"
		case "$dev_dir" in /*) ;; *) die "MUDDS_DEV_SIGNING_DIR must be absolute" ;; esac
		if [[ -n "$REPO_ROOT" ]]; then
			case "$(realpath -m -- "$dev_dir")/" in
				"$REPO_ROOT"/*) die "dev signing directory must be outside the repository ($dev_dir)" ;;
			esac
		fi
	else
		pfx_path="${MUDDS_SIGNING_PFX:-}"
		[[ -n "$pfx_path" ]] || die "MUDDS_SIGNING_PFX is not set (use --dev-self-signed for an untrusted pipeline test)"
		[[ -f "$pfx_path" && -r "$pfx_path" ]] || die "MUDDS_SIGNING_PFX is not a readable file: $pfx_path"
		[[ "${MUDDS_SIGNING_PASSWORD+set}" == "set" ]] || die "MUDDS_SIGNING_PASSWORD is not set"
	fi
fi

trust_label="PFX_SUPPLIED_WINDOWS_TRUST_NOT_RUN"
if [[ "$mode" == "dev-self-signed" ]]; then
	trust_label="UNTRUSTED_DEV_SELF_SIGNED"
fi
if (( verify_only )); then
	if [[ "$mode" == "dev-self-signed" ]]; then
		mode="verify-only-dev-self-signed"
	else
		mode="verify-only"
		trust_label="VERIFY_ONLY_WINDOWS_TRUST_NOT_RUN"
	fi
fi

if (( dry_run )); then
	have_tool="no"
	command -v osslsigncode >/dev/null 2>&1 && have_tool="yes"
	printf 'DRY RUN: nothing will be signed or written\n'
	printf 'mode=%s\n' "$mode"
	printf 'trust=%s\n' "$trust_label"
	printf 'timestamp_url=%s\n' "${timestamp_url:-none}"
	printf 'osslsigncode_available=%s\n' "$have_tool"
	[[ -n "$dev_dir" ]] && printf 'dev_signing_dir=%s\n' "$dev_dir"
	[[ -n "$pfx_path" ]] && printf 'pfx=%s\n' "$pfx_path"
	(( sign_in_place )) || printf 'result=%s\n' "$result_path"
	for artifact in "${artifacts[@]}"; do
		if (( verify_only )); then
			printf 'would_verify=%s\n' "$artifact"
		else
			printf 'would_sign=%s\n' "$artifact"
		fi
	done
	exit 0
fi

command -v osslsigncode >/dev/null 2>&1 \
	|| die "osslsigncode is not installed (Debian/Ubuntu: apt-get install -y osslsigncode)"
command -v python3 >/dev/null 2>&1 || die "python3 is required to write the result JSON"

work_dir="$(mktemp -d)"
chmod 700 "$work_dir"
cleanup() {
	rm -rf -- "$work_dir"
}
trap cleanup EXIT

pass_file="$work_dir/pass"
ca_file=""

ensure_dev_certificate() {
	local saved_umask
	saved_umask="$(umask)"
	umask 077
	mkdir -p -- "$dev_dir"
	chmod 700 -- "$dev_dir"
	local key="$dev_dir/dev-codesign.key.pem"
	local cert="$dev_dir/dev-codesign.cert.pem"
	local pfx="$dev_dir/dev-codesign.pfx"
	local pass="$dev_dir/dev-codesign.pass"
	if [[ -f "$pfx" && -f "$cert" && -f "$pass" ]] \
		&& openssl x509 -checkend 86400 -noout -in "$cert" >/dev/null 2>&1; then
		:
	else
		command -v openssl >/dev/null 2>&1 || die "openssl is required for --dev-self-signed"
		note "generating a throwaway UNTRUSTED self-signed code-signing certificate in $dev_dir"
		openssl rand -hex 24 > "$pass"
		openssl req -x509 -newkey rsa:3072 -sha256 -days 30 -nodes \
			-keyout "$key" -out "$cert" \
			-subj "/CN=Mudds Shipyards DEV UNTRUSTED/O=Mudds Shipyards development only" \
			-addext "basicConstraints=critical,CA:FALSE" \
			-addext "keyUsage=critical,digitalSignature" \
			-addext "extendedKeyUsage=codeSigning" >/dev/null 2>&1 \
			|| die "openssl could not create the dev certificate"
		openssl pkcs12 -export -out "$pfx" -inkey "$key" -in "$cert" \
			-passout "file:$pass" >/dev/null 2>&1 \
			|| die "openssl could not package the dev certificate"
		chmod 600 -- "$key" "$cert" "$pfx" "$pass"
	fi
	umask "$saved_umask"
	pfx_path="$pfx"
	cp -- "$pass" "$pass_file"
	ca_file="$cert"
}

if (( verify_only )) && [[ -n "$dev_dir" && -f "$dev_dir/dev-codesign.cert.pem" ]]; then
	# Verifying a dev-signed artifact trusts only the throwaway dev certificate.
	ca_file="$dev_dir/dev-codesign.cert.pem"
fi
if (( ! verify_only )); then
	if [[ "$mode" == "dev-self-signed" ]]; then
		ensure_dev_certificate
	else
		( umask 077; printf '%s' "$MUDDS_SIGNING_PASSWORD" > "$pass_file" )
	fi
	chmod 600 -- "$pass_file"
fi

sign_one() {
	local artifact="$1"
	local staged="$work_dir/$(basename -- "$artifact").signed"
	local args=(sign -pkcs12 "$pfx_path" -readpass "$pass_file" -h sha256
		-n "Mudds Shipyards")
	if [[ -n "$timestamp_url" ]]; then
		args+=(-ts "$timestamp_url")
	fi
	rm -f -- "$staged"
	if ! osslsigncode "${args[@]}" -in "$artifact" -out "$staged" > "$work_dir/sign.log" 2>&1; then
		cat "$work_dir/sign.log" >&2
		die "osslsigncode could not sign $artifact"
	fi
	[[ -s "$staged" ]] || die "osslsigncode produced no output for $artifact"
	# Replace the original only after a complete signed file exists.
	cp -p -- "$artifact" "$artifact.signing-tmp"
	cat -- "$staged" > "$artifact.signing-tmp"
	mv -f -- "$artifact.signing-tmp" "$artifact"
	rm -f -- "$staged"
}

if (( sign_in_place )); then
	for artifact in "${artifacts[@]}"; do
		sign_one "$artifact"
		note "signed $(basename -- "$artifact") ($trust_label)"
	done
	exit 0
fi

records_file="$work_dir/records.tsv"
: > "$records_file"
overall=0
for artifact in "${artifacts[@]}"; do
	before="$(sha256sum -- "$artifact" | cut -d' ' -f1)"
	signed="false"
	if (( ! verify_only )); then
		sign_one "$artifact"
		signed="true"
	fi
	after="$(sha256sum -- "$artifact" | cut -d' ' -f1)"
	verify_args=(verify -in "$artifact")
	if [[ -n "$ca_file" ]]; then
		verify_args+=(-CAfile "$ca_file")
	fi
	verify_log="$work_dir/verify-$(basename -- "$artifact").log"
	set +e
	osslsigncode "${verify_args[@]}" > "$verify_log" 2>&1
	verify_exit=$?
	set -e
	(( verify_exit == 0 )) || overall=1
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$artifact" "$before" "$after" "$signed" "$verify_exit" "$verify_log" >> "$records_file"
done

python3 - "$result_path" "$records_file" "$mode" "$trust_label" "$timestamp_url" \
	"$(osslsigncode --version 2>&1 | head -n 1)" <<'PY'
import json
import sys

path, records_file, mode, trust, timestamp_url, tool_version = sys.argv[1:]
artifacts = []
with open(records_file, encoding="utf-8") as handle:
    for line in handle:
        artifact, before, after, signed, verify_exit, verify_log = line.rstrip("\n").split("\t")
        with open(verify_log, encoding="utf-8", errors="replace") as log:
            log_text = log.read()
        subject = ""
        for log_line in log_text.splitlines():
            stripped = log_line.strip()
            if stripped.lower().startswith("subject:"):
                subject = stripped.split(":", 1)[1].strip()
                break
        artifacts.append({
            "path": artifact,
            "sha256_before": before,
            "sha256_after": after,
            "signed_by_this_run": signed == "true",
            "verify": {
                "tool": "osslsigncode verify",
                "exit_code": int(verify_exit),
                "status": "ok" if int(verify_exit) == 0 else "failed",
                "signer_subject": subject,
                "log_tail": log_text.splitlines()[-12:],
            },
        })
record = {
    "schema_version": 1,
    "mode": mode,
    "trust": trust,
    "trusted_signing_claimed": False,
    "timestamp_url": timestamp_url or None,
    "osslsigncode_version": tool_version,
    "artifacts": artifacts,
    "all_verified": all(item["verify"]["status"] == "ok" for item in artifacts),
    "native_windows_verification": "NOT_RUN",
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(record, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

if [[ "$mode" == "dev-self-signed" ]]; then
	note "UNTRUSTED dev self-signed signature applied; this is not a release signature"
fi
note "wrote $result_path"
if (( overall != 0 )); then
	note "verification FAILED for at least one artifact (see $result_path)"
	exit 1
fi
exit 0
