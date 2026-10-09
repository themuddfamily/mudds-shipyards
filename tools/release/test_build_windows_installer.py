#!/usr/bin/env python3
"""Focused tests for build_windows_installer.sh and the NSIS script it compiles.

The compile test runs only when makensis is installed; it builds a real
installer from a stub executable and checks the recorded provenance. The
script-content tests always run and pin the contract that matters to players:
per-user install, silent flags honoured, and an uninstaller that never reaches
into %APPDATA% user data.
"""

import base64
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parent.parent
BUILD_SCRIPT = TOOLS_DIR / "build_windows_installer.sh"
NSI = TOOLS_DIR / "installer" / "mudds_shipyards.nsi"
VERIFY_PS1 = TOOLS_DIR / "verify_windows_installer.ps1"
HAVE_MAKENSIS = shutil.which("makensis") is not None


def _head_commit():
    return subprocess.check_output(
        ["git", "-C", str(REPO_ROOT), "rev-parse", "HEAD"], text=True
    ).strip()


class NsisScriptContract(unittest.TestCase):
    def setUp(self):
        self.text = NSI.read_text(encoding="utf-8")

    def test_installs_per_user_without_elevation(self):
        self.assertIn("RequestExecutionLevel user", self.text)
        self.assertIn('InstallDir "$LOCALAPPDATA\\Programs\\', self.text)
        self.assertNotIn("HKLM", self.text)

    def test_uninstaller_only_removes_what_it_wrote(self):
        uninstall = "\n".join(
            line for line in self.text.split('Section "Uninstall"', 1)[1].splitlines()
            if not line.strip().startswith(";")
        )
        self.assertNotIn("RMDir /r", uninstall)
        self.assertNotIn("APPDATA", uninstall)
        self.assertNotIn("app_userdata", uninstall)
        for required in (
            'Delete "$INSTDIR\\${PRODUCT_EXE}"',
            'Delete "$INSTDIR\\${UNINSTALL_EXE}"',
            'DeleteRegKey HKCU "${REG_UNINSTALL_KEY}"',
            'DeleteRegKey HKCU "${REG_APP_KEY}"',
        ):
            self.assertIn(required, uninstall)

    def test_registry_entry_supports_quiet_uninstall_and_provenance(self):
        self.assertIn('"QuietUninstallString" \'"$INSTDIR\\${UNINSTALL_EXE}" /S\'', self.text)
        self.assertIn('"SourceCommit" "${FULL_COMMIT}"', self.text)
        self.assertIn('"UpgradedFrom"', self.text)
        self.assertIn("signing=unsigned", self.text)

    def test_replacement_is_staged_atomic_and_fatal_before_metadata(self):
        install = self.text.split('Section "Install" SEC_MAIN', 1)[1].split('Section "Uninstall"', 1)[0]
        self.assertIn('File "/oname=${PENDING_EXE}" "${SOURCE_EXE}"', install)
        self.assertIn("SetOverwrite try\n  ClearErrors", install)
        self.assertLess(install.index('IfFileExists "$INSTDIR\\${PENDING_EXE}"'), install.index("StrCpy $OwnsPending 1"))
        failed = self.text.split("Function .onInstFailed", 1)[1].split("FunctionEnd", 1)[0]
        self.assertIn("${If} $OwnsPending == 1", failed)
        self.assertIn("IfErrors 0 payload_staged", install)
        self.assertIn("kernel32::MoveFileExW", install)
        self.assertIn("i 9) i .r0 ?e", install)
        self.assertIn("IntCmp $2 40", install)
        self.assertIn("SetErrorLevel 2", install)
        self.assertLess(install.index("payload_replaced:"), install.index('FileOpen $0'))
        self.assertIn('Delete "$INSTDIR\\${PENDING_EXE}"', self.text)

    def test_every_define_is_required(self):
        for define in ("SOURCE_EXE", "SHORT_COMMIT", "FULL_COMMIT", "PRODUCT_VERSION", "OUTPUT_FILE"):
            self.assertRegex(self.text, rf"!ifndef {define}\n\s+!error")


class VerifierContract(unittest.TestCase):
    def test_verifier_covers_install_startup_upgrade_and_uninstall(self):
        text = VERIFY_PS1.read_text(encoding="utf-8")
        for step in (
            "'silent_install'",
            "'installed_files'",
            "'registry_and_shortcuts'",
            "'installed_startup_check'",
            "'silent_upgrade_over_existing'",
            "'silent_uninstall'",
        ):
            self.assertIn(f"Step {step}", text)
        self.assertIn("STARTUP_MENU_READY_OK", text)
        self.assertIn("--headless --audio-driver Dummy --startup-check", text)
        self.assertIn("user_data_preserved=True", text)
        # The verifier never installs into the real per-user Programs folder.
        self.assertIn("$installDir = Join-Path $ProbeRoot 'install'", text)

    def test_cross_build_mode_verifies_each_transition_and_startup(self):
        text = VERIFY_PS1.read_text(encoding="utf-8")
        for option in ("PreviousInstaller", "PreviousExpectedExeSha256", "PreviousExpectedCommit"):
            self.assertIn(f"[string]${option}", text)
        self.assertIn("must be supplied together", text)
        self.assertIn("distinct commits and executable hashes", text)
        self.assertIn("Assert-Installed $ExpectedExeSha256 $ExpectedCommit", text)
        self.assertIn("Assert-RegistryAndShortcuts $ExpectedCommit $initialCommit", text)
        self.assertIn("Assert-Installed $PreviousExpectedExeSha256 $PreviousExpectedCommit", text)
        self.assertIn("Assert-RegistryAndShortcuts $PreviousExpectedCommit $ExpectedCommit", text)
        for stage in ("installed", "upgraded", "rolled-back"):
            self.assertIn(f"Run-Startup '{stage}'", text)
        self.assertIn("$exitCode -ne 0 -or -not $sentinel", text)
        self.assertIn("startup log already exists", text)
        self.assertIn(".Hash -ne $markerHash", text)
        self.assertIn("if ($crossBuild) {\n    Step 'locked_upgrade_preserves_previous'", text)
        locked = text.split("Step 'locked_upgrade_preserves_previous'", 1)[1].split("Step 'silent_upgrade_over_existing'", 1)[0]
        self.assertIn("[IO.FileShare]::None", locked)
        self.assertIn('try { $code = Run-Silent $Installer "/S /D=$installDir" 120000 }', locked)
        self.assertIn("finally { $lock.Dispose() }", locked)
        self.assertIn("$code -ne 2", locked)
        self.assertIn("Assert-Installed $initialHash $initialCommit", locked)
        self.assertIn("locked upgrade changed provenance bytes", locked)
        self.assertIn("locked upgrade changed registry metadata", locked)
        self.assertIn("failed upgrade left pending payload", locked)

    def test_native_log_and_document_acceptance_rejects_real_regressions(self):
        powershell = shutil.which("powershell.exe") or shutil.which("pwsh")
        if not powershell:
            bridge = Path("/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe")
            powershell = str(bridge) if bridge.is_file() else None
        if not powershell:
            self.skipTest("PowerShell is required for executable acceptance checks")
        text = VERIFY_PS1.read_text(encoding="utf-8")
        functions = []
        for name, following in (("Run-Silent", "Assert-UserData"),
                                ("Assert-UserData", "Assert-Installed"),
                                ("Assert-StartupLog", "Assert-NewerDocumentDiagnostics"),
                                ("Seed-ForcedKillFixture", "Read-RecoveryDocument"),
                                ("Read-RecoveryDocument", "Assert-RecoveryPayload"),
                                ("Assert-RecoveryPayload", "Wait-OwnedRecoveryMarker"),
                                ("Wait-OwnedRecoveryMarker", "Run-ForcedKillBoot"),
                                ("Run-ForcedKillBoot", "Assert-StartupLog"),
                                ("Read-InWorldLog", "Read-InWorldToken"),
                                ("Sorted-InWorldValue", "InWorld-LogCounts"),
                                ("Assert-InWorldSelection", "Start-InWorldOwned")):
            functions.append("function " + name + text.split("function " + name, 1)[1].split("function " + following, 1)[0])
        # Execute the production assertion functions against actual files. A
        # documented application warning is allowed; duplicate/missing menu
        # readiness, nonzero exits, engine faults and changed/lost saves fail.
        encoded_source = base64.b64encode(text.encode("utf-8")).decode("ascii")
        parser = (
            "$source = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('"
            + encoded_source + "'))\n"
            "$tokens = $null; $errors = $null\n"
            "[Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors) | Out-Null\n"
            "if ($errors.Count) { throw ($errors | Out-String) }\n"
        )
        script = "$ErrorActionPreference = 'Stop'\n" + parser + "\n".join(functions) + r"""
$root = Join-Path ([IO.Path]::GetTempPath()) ('mudds-verifier-regression-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
try {
    $InWorldRecoveryActivity = 'convoy'
    # A legacy pilot-only payload must never qualify a requested cabin/rest/crew run.
    foreach ($selected in @('pilot', 'cabin', 'rest', 'crew')) {
        $InWorldRecoveryContext = $selected
        Assert-InWorldContext ([pscustomobject]@{recovery_context=$selected})
        foreach ($reported in @('pilot', 'cabin', 'rest', 'crew', '', 'PILOT', 'CABIN', 'REST', 'CREW')) {
            if ($reported -ceq $selected) { continue }
            $rejected = $false
            try { Assert-InWorldContext ([pscustomobject]@{recovery_context=$reported}) } catch { $rejected = $true }
            if (-not $rejected) { throw "wrong recovery context accepted: $selected/$reported" }
        }
        $rejected = $false
        try { Assert-InWorldContext ([pscustomobject]@{}) } catch { $rejected = $true }
        if ($rejected -ne ($selected -ne 'pilot')) { throw "legacy marker acceptance differs: $selected" }
    }
    # Beacon requires an explicit activity/context marker and a pilot-only selection.
    $InWorldRecovery = $true
    $InWorldRecoveryActivity = 'beacon'
    $InWorldRecoveryContext = 'pilot'
    Assert-InWorldSelection
    Assert-InWorldContext ([pscustomobject]@{activity='beacon'; recovery_context='pilot'})
    foreach ($token in @(@{recovery_context='pilot'}, @{activity='convoy'; recovery_context='pilot'}, @{activity='BEACON'; recovery_context='pilot'}, @{activity='beacon'}, @{activity='beacon'; recovery_context='cabin'})) {
        $rejected = $false
        try { Assert-InWorldContext ([pscustomobject]$token) } catch { $rejected = $true }
        if (-not $rejected) { throw 'unsupported beacon marker accepted' }
    }
    foreach ($selected in @('cabin','rest','crew')) {
        $InWorldRecoveryContext = $selected
        $rejected = $false
        try { Assert-InWorldSelection } catch { $rejected = $true }
        if (-not $rejected) { throw 'unsupported beacon context accepted' }
    }
    $InWorldRecoveryContext = 'pilot'
    $InWorldRecovery = $false
    $rejected = $false
    try { Assert-InWorldSelection } catch { $rejected = $true }
    if (-not $rejected) { throw 'beacon without in-world recovery accepted' }
    $InWorldRecoveryActivity = 'convoy'
    Assert-InWorldSelection
    # Minimal genuine terminal shape: test production assertions, changing both
    # token and disk together so structural checks also reject matching bad data.
    $beacon = @{
        schema_version=1; activities=@(@{
            activity_id='cinder_debris_beacon_traversal'; generation=1; state=2
            reward_requested=$true; reward_granted=$false
            progress=@{generation=1; state=2; next_beacon_index=4; beacon_count=4; reward_requested=$false}
        })
    } | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $ready = [pscustomobject]@{boundary=$beacon; receipts=0; runtime_observation=[pscustomobject]@{player_seated=$true; craft_piloted=$true; craft_id='bulwark_heavy_gunship'}}
    $saved = [pscustomobject]@{payload=[pscustomobject]@{
        cinder_beacon_session=$beacon; crash_recovery=[pscustomobject]@{state='running'}
        solo_safe_recovery=[pscustomobject]@{craft_id='bulwark_heavy_gunship'}
        game_flow_reward_store=[pscustomobject]@{reward_counts=[pscustomobject]@{debris_route_navigation_data=0}}
    }}
    Assert-InWorldBeaconArm $saved $ready
    foreach ($mutation in @(
        {$saved.payload.cinder_beacon_session.activities[0].generation=0},
        {$saved.payload.cinder_beacon_session.activities[0].reward_granted=$true},
        {$saved.payload.cinder_beacon_session.activities[0].progress.generation=2},
        {$saved.payload.cinder_beacon_session.activities[0].progress.next_beacon_index=3},
        {$saved.payload.cinder_beacon_session.activities[0].progress.reward_requested=$true},
        {$saved.payload.game_flow_reward_store.reward_counts.debris_route_navigation_data=1},
        {$saved.payload.crash_recovery.state='clean'},
        {$ready.runtime_observation.player_seated=$false},
        {$saved.payload.solo_safe_recovery.craft_id='torrent_provisional'}
    )) {
        $savedBaseline = $saved | ConvertTo-Json -Depth 12
        $readyBaseline = $ready | ConvertTo-Json -Depth 12
        & $mutation
        $rejected = $false
        $ready.boundary = $saved.payload.cinder_beacon_session
        try { Assert-InWorldBeaconArm $saved $ready } catch { $rejected = $true }
        if (-not $rejected) { throw 'invalid beacon unpaid boundary accepted' }
        $saved = $savedBaseline | ConvertFrom-Json
        $ready = $readyBaseline | ConvertFrom-Json
    }
    $paid = $ready.boundary | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $paid.activities[0].reward_granted=$true
    $paid.activities[0].progress.reward_requested=$true
    $final = [pscustomobject]@{payload=[pscustomobject]@{
        cinder_beacon_session=$paid
        game_flow_reward_store=[pscustomobject]@{
            reward_counts=[pscustomobject]@{debris_route_navigation_data=1}
            last_receipt=[pscustomobject]@{activity_id='cinder_debris_beacon_traversal'; activity_generation=1; granted=$true}
        }
    }}
    $recovered = [pscustomobject]@{
        paid_boundary=$paid
        safe_recovery_observation=[pscustomobject]@{player_seated=$true; craft_piloted=$true; piloting=$true; craft_id='bulwark_heavy_gunship'}
        continuation_method='real_safe_home_pilot_resume_then_ordinary_beacon_start_retry'
    }
    $beaconLog = Join-Path $root 'beacon.log'
    $beaconAssertions = @(
        'PASS: a fresh Boot process restores only the genuine unpaid beacon checkpoint and one crash event',
        'PASS: ordinary Resume reacquires the real safe-home pilot and preserves the exact unpaid boundary before retry',
        'PASS: the recovered real pilot accepts ordinary flight input without mutating unpaid beacon progress',
        'PASS: ordinary HUD Start publishes one beacon payment and its existing atomic acknowledgement',
        'PASS: duplicate and late terminal callbacks cannot pay again or change the saved beacon acknowledgement',
        'PASS: beacon restart closes both existing recovery marker owners'
    )
    [IO.File]::WriteAllText($beaconLog, ($beaconAssertions -join "`n") + "`n")
    Assert-InWorldBeaconRecovered $final $ready $recovered $beaconLog
    foreach ($mutation in @(
        {$final.payload.cinder_beacon_session.activities[0].generation=2},
        {$final.payload.cinder_beacon_session.activities[0].reward_granted=$false},
        {$final.payload.cinder_beacon_session.activities[0].progress.reward_requested=$false},
        {$final.payload.game_flow_reward_store.reward_counts.debris_route_navigation_data=2},
        {$final.payload.game_flow_reward_store.last_receipt.activity_generation=2},
        {$recovered.safe_recovery_observation.piloting=$false},
        {$recovered.continuation_method='simulated_payment'}
    )) {
        $finalBaseline = $final | ConvertTo-Json -Depth 12
        $recoveredBaseline = $recovered | ConvertTo-Json -Depth 12
        & $mutation
        $rejected = $false
        $recovered.paid_boundary = $final.payload.cinder_beacon_session
        try { Assert-InWorldBeaconRecovered $final $ready $recovered $beaconLog } catch { $rejected = $true }
        if (-not $rejected) { throw 'invalid saved beacon payment/continuation accepted' }
        $final = $finalBaseline | ConvertFrom-Json
        $recovered = $recoveredBaseline | ConvertFrom-Json
    }
    foreach ($missing in $beaconAssertions) {
        [IO.File]::WriteAllText($beaconLog, (($beaconAssertions | Where-Object { $_ -ne $missing }) -join "`n") + "`n")
        $rejected = $false
        $recovered.paid_boundary = $final.payload.cinder_beacon_session
        try { Assert-InWorldBeaconRecovered $final $ready $recovered $beaconLog } catch { $rejected = $true }
        if (-not $rejected) { throw 'missing real beacon continuation assertion accepted' }
    }
    $InWorldRecoveryActivity = 'mining'
    $InWorldRecoveryContext = 'pilot'
    $InWorldRecovery = $true
    Assert-InWorldSelection
    Assert-InWorldContext ([pscustomobject]@{activity='mining'; recovery_context='pilot'})
    foreach ($token in @(@{recovery_context='pilot'}, @{activity='convoy'; recovery_context='pilot'}, @{activity='MINING'; recovery_context='pilot'}, @{activity='mining'}, @{activity='mining'; recovery_context='cabin'})) {
        $rejected = $false
        try { Assert-InWorldContext ([pscustomobject]$token) } catch { $rejected = $true }
        if (-not $rejected) { throw 'unsupported mining marker accepted' }
    }
    foreach ($selected in @('cabin','rest','crew')) {
        $InWorldRecoveryContext = $selected
        $rejected = $false
        try { Assert-InWorldSelection } catch { $rejected = $true }
        if (-not $rejected) { throw 'unsupported mining context accepted' }
    }
    $InWorldRecoveryContext = 'pilot'
    $InWorldRecovery = $false
    $rejected = $false
    try { Assert-InWorldSelection } catch { $rejected = $true }
    if (-not $rejected) { throw 'mining without recovery accepted' }
    $mining = @{
        schema_version=2; payload_kind='cinder_mining_capacity_receipt'; slot_id='cinder_mining_capacity'
        session=@{state=2; generation=1; elapsed_seconds=6; reward_requested=$false; capacity_paid=$false}; capacity=@{}
    } | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $settings = [pscustomobject]@{values=[pscustomobject]@{graphics_profile='low'}}
    $cargo = [pscustomobject]@{fixture='unrelated'; ore=7}
    $ready = [pscustomobject]@{boundary=$mining; receipts=0; foreign_settings=$settings; foreign_cargo=$cargo; runtime_observation=[pscustomobject]@{player_seated=$true; craft_piloted=$true; craft_id='bulwark_heavy_gunship'}}
    $saved = [pscustomobject]@{payload=[pscustomobject]@{cinder_mining_capacity=$mining; runtime_settings=$settings; mining_probe_foreign_cargo=$cargo; crash_recovery=[pscustomobject]@{state='running'}; solo_safe_recovery=[pscustomobject]@{craft_id='bulwark_heavy_gunship'}}}
    Assert-InWorldMiningArm $saved $ready
    # Godot serializes session numbers as decimals. Real Windows PowerShell
    # preserves their .0 spelling; semantic numeric boundaries still qualify.
    $decimalSession = '{"state":2.0,"generation":1.0,"elapsed_seconds":6.0,"reward_requested":false,"capacity_paid":false}' | ConvertFrom-Json
    $saved.payload.cinder_mining_capacity.session = $decimalSession
    $ready.boundary = $saved.payload.cinder_mining_capacity
    Assert-InWorldMiningArm $saved $ready
    foreach ($mutation in @(
        {$decimalSession.generation=1.5}, {$decimalSession.elapsed_seconds=6.5},
        {$decimalSession.state=[double]::NaN}, {$decimalSession.elapsed_seconds=[double]::PositiveInfinity},
        {$decimalSession.generation='1'}, {$decimalSession.state=$true},
        {$decimalSession.reward_requested=0}, {$decimalSession.capacity_paid='false'},
        {$decimalSession | Add-Member -NotePropertyName extra -NotePropertyValue 1},
        {$decimalSession.PSObject.Properties.Remove('state')},
        {$decimalSession.PSObject.Properties.Remove('state'); $decimalSession | Add-Member -NotePropertyName STATE -NotePropertyValue 2}
    )) {
        $baseline = $decimalSession | ConvertTo-Json -Depth 12
        & $mutation
        $rejected = $false
        try { Assert-InWorldMiningSession $decimalSession $false 1 6 } catch { $rejected = $true }
        if (-not $rejected) { throw 'malformed decimal mining session accepted' }
        $decimalSession = $baseline | ConvertFrom-Json
    }
    $saved.payload.cinder_mining_capacity.session = $decimalSession
    $ready.boundary = $saved.payload.cinder_mining_capacity
    Assert-InWorldMiningArm $saved $ready
    foreach ($mutation in @(
        {$saved.payload.cinder_mining_capacity.schema_version=1},
        {$saved.payload.cinder_mining_capacity.slot_id='other'},
        {$saved.payload.cinder_mining_capacity.payload_kind='other'},
        {$saved.payload.cinder_mining_capacity.session.generation=2},
        {$saved.payload.cinder_mining_capacity.session.elapsed_seconds=5},
        {$saved.payload.cinder_mining_capacity.session.state=1},
        {$saved.payload.cinder_mining_capacity.session.capacity_paid=$true},
        {$saved.payload.cinder_mining_capacity.session.reward_requested=$true},
        {$saved.payload.cinder_mining_capacity.capacity=[pscustomobject]@{granted=$true}},
        {$ready.receipts=1}, {$saved.payload.crash_recovery.state='clean'},
        {$ready.runtime_observation.player_seated=$false}, {$ready.runtime_observation.craft_piloted=$false},
        {$saved.payload.solo_safe_recovery.craft_id='other'},
        {$ready.foreign_settings=[pscustomobject]@{}}, {$ready.foreign_cargo=[pscustomobject]@{}},
        {$saved.payload.runtime_settings=[pscustomobject]@{changed=$true}},
        {$saved.payload.mining_probe_foreign_cargo=[pscustomobject]@{ore=8}}
    )) {
        $savedBaseline = $saved | ConvertTo-Json -Depth 12
        $readyBaseline = $ready | ConvertTo-Json -Depth 12
        & $mutation
        $ready.boundary = $saved.payload.cinder_mining_capacity
        $rejected = $false
        try { Assert-InWorldMiningArm $saved $ready } catch { $rejected = $true }
        if (-not $rejected) { throw 'invalid matching mining unpaid document/token accepted' }
        $saved = $savedBaseline | ConvertFrom-Json
        $ready = $readyBaseline | ConvertFrom-Json
    }
    $paid = $ready.boundary | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $paid.session.capacity_paid=$true; $paid.session.reward_requested=$true
    $paid.capacity = [pscustomobject]@{activity_id='cinder_platform_mining_run'; content_class='NEW'; evidence_status='modern_interpretation'; extraction_seconds=6; reward_receipt=[pscustomobject]@{activity_id='cinder_platform_mining_run'; reward_id='cinder_raw_ore_sample'; granted=$false; replay_allowed=$false}}
    $final = [pscustomobject]@{payload=[pscustomobject]@{cinder_mining_capacity=$paid; runtime_settings=$ready.foreign_settings; mining_probe_foreign_cargo=$ready.foreign_cargo}}
    $recovered = [pscustomobject]@{paid_boundary=$paid; capacity_commits=1; foreign_settings=$ready.foreign_settings; foreign_cargo=$ready.foreign_cargo; safe_recovery_observation=[pscustomobject]@{player_seated=$true; craft_piloted=$true; piloting=$true; craft_id='bulwark_heavy_gunship'}; continuation_method='real_safe_home_pilot_resume_then_ordinary_mining_start_retry'}
    $miningLog = Join-Path $root 'mining.log'
    $miningAssertions = @(
        'PASS: a fresh Boot process restores the genuine unpaid mining completion and one crash event',
        'PASS: ordinary Resume reacquires the real safe-home pilot and preserves exact unpaid mining progress',
        'PASS: the recovered real pilot accepts ordinary throttle without mutating unpaid mining progress',
        'PASS: ordinary HUD Start atomically publishes capacity and the same generation paid acknowledgement once',
        'PASS: duplicate and genuine late unpaid callbacks are refused without another capacity commit',
        'PASS: mining recovery preserves production settings and unrelated cargo fields',
        'PASS: mining restart closes both existing recovery marker owners'
    )
    [IO.File]::WriteAllText($miningLog, ($miningAssertions -join "`n") + "`n")
    Assert-InWorldMiningRecovered $final $ready $recovered $miningLog
    foreach ($mutation in @(
        {$final.payload.cinder_mining_capacity.schema_version=1},
        {$final.payload.cinder_mining_capacity.session.generation=2},
        {$final.payload.cinder_mining_capacity.session.elapsed_seconds=7},
        {$final.payload.cinder_mining_capacity.session.capacity_paid=$false},
        {$final.payload.cinder_mining_capacity.session.reward_requested=$false},
        {$final.payload.cinder_mining_capacity.capacity.extraction_seconds=5},
        {$final.payload.cinder_mining_capacity.capacity.content_class='other'},
        {$final.payload.cinder_mining_capacity.capacity.reward_receipt.granted=$true},
        {$final.payload.cinder_mining_capacity.capacity.reward_receipt.replay_allowed=$true},
        {$final.payload.cinder_mining_capacity.capacity.reward_receipt.reward_id='other'},
        {$recovered.capacity_commits=2}, {$recovered.safe_recovery_observation.piloting=$false},
        {$recovered.continuation_method='simulated'},
        {$final.payload.runtime_settings=[pscustomobject]@{changed=$true}},
        {$recovered.foreign_cargo=[pscustomobject]@{ore=9}}
    )) {
        $finalBaseline = $final | ConvertTo-Json -Depth 12
        $recoveredBaseline = $recovered | ConvertTo-Json -Depth 12
        & $mutation
        $recovered.paid_boundary = $final.payload.cinder_mining_capacity
        $rejected = $false
        try { Assert-InWorldMiningRecovered $final $ready $recovered $miningLog } catch { $rejected = $true }
        if (-not $rejected) { throw 'invalid matching mining paid document/token accepted' }
        $final = $finalBaseline | ConvertFrom-Json
        $recovered = $recoveredBaseline | ConvertFrom-Json
    }
    foreach ($missing in $miningAssertions) {
        [IO.File]::WriteAllText($miningLog, (($miningAssertions | Where-Object { $_ -ne $missing }) -join "`n") + "`n")
        $rejected = $false
        try { Assert-InWorldMiningRecovered $final $ready $recovered $miningLog } catch { $rejected = $true }
        if (-not $rejected) { throw 'missing real mining continuation assertion accepted' }
    }
    [array]::Reverse($miningAssertions)
    [IO.File]::WriteAllText($miningLog, ($miningAssertions -join "`n") + "`n")
    $rejected = $false
    try { Assert-InWorldMiningRecovered $final $ready $recovered $miningLog } catch { $rejected = $true }
    if (-not $rejected) { throw 'unordered real mining continuation assertions accepted' }
    $InWorldRecoveryActivity = 'stationdefense'; $InWorldRecoveryContext = 'pilot'; $InWorldRecovery = $true
    Assert-InWorldSelection
    Assert-InWorldContext ([pscustomobject]@{activity='stationdefense'; recovery_context='pilot'})
    foreach ($selected in @('cabin','rest','crew')) {
        $InWorldRecoveryContext=$selected; $rejected=$false
        try { Assert-InWorldSelection } catch { $rejected=$true }
        if (-not $rejected) { throw 'unsupported defense context accepted' }
    }
    $InWorldRecoveryContext='pilot'; $InWorldRecovery=$false; $rejected=$false
    try { Assert-InWorldSelection } catch { $rejected=$true }
    if (-not $rejected) { throw 'defense without recovery accepted' }
    foreach ($token in @(@{},@{activity='stationdefense'},@{activity='STATIONDEFENSE'; recovery_context='pilot'},@{activity='mining'; recovery_context='pilot'},@{activity='stationdefense'; recovery_context='cabin'})) {
        $rejected=$false
        try { Assert-InWorldContext ([pscustomobject]$token) } catch { $rejected=$true }
        if (-not $rejected) { throw 'unsupported defense marker accepted' }
    }
    $defense = '{"schema_version":1.0,"payload_kind":"nearby_sector_activity_session","slot_id":"station_defense_session","activity_generation":8.0,"session":{"schema_version":2.0,"history":{"activity_id":"shipyard_perimeter_defense","state_id":"completed","generation":2.0,"failure_reason":"","reward_handoff_generation":0.0,"reward_replayable":false},"completion":{"activity_id":"shipyard_perimeter_defense","generation":2.0,"reward_requested":true,"reward_granted":false}}}' | ConvertFrom-Json
    $ready = [pscustomobject]@{boundary=$defense; receipts=0; armed_elapsed_seconds=10.5; foreign_settings=[pscustomobject]@{values=[pscustomobject]@{graphics_profile='high'}}; foreign_cargo=[pscustomobject]@{generation=1.0; progress='actual-production'}; foreign_reward_counts=[pscustomobject]@{debris_route_navigation_data=1}; runtime_observation=[pscustomobject]@{player_seated=$true; craft_piloted=$true; craft_id='bulwark_heavy_gunship'}}
    $saved = [pscustomobject]@{payload=[pscustomobject]@{station_defense_session=$defense; runtime_settings=$ready.foreign_settings; jovian_cargo_session=$ready.foreign_cargo; game_flow_reward_store=[pscustomobject]@{reward_counts=$ready.foreign_reward_counts}; crash_recovery=[pscustomobject]@{state='running'}; solo_safe_recovery=[pscustomobject]@{craft_id='bulwark_heavy_gunship'}}}
    # Genuine store JSON uses 1.0 while GameFlow's ready report uses integer 1.
    # Typed key/value equality must accept that representation difference.
    $saved.payload.game_flow_reward_store.reward_counts = '{"debris_route_navigation_data":1.0}' | ConvertFrom-Json
    Assert-InWorldStationArm $saved $ready
    foreach ($mutation in @(
        {$saved.payload.game_flow_reward_store.reward_counts = [pscustomobject]@{wrong_key=1.0}},
        {$saved.payload.game_flow_reward_store.reward_counts | Add-Member -NotePropertyName invented -NotePropertyValue 1.0},
        {$saved.payload.game_flow_reward_store.reward_counts.debris_route_navigation_data='1'},
        {$saved.payload.game_flow_reward_store.reward_counts.debris_route_navigation_data=1.5},
        {$saved.payload.station_defense_session.schema_version=2.0},
        {$saved.payload.station_defense_session.session.schema_version=3.0},
        {$saved.payload.station_defense_session.session.history.generation=2.5},
        {$saved.payload.station_defense_session.session.history.generation=[double]::NaN},
        {$saved.payload.station_defense_session.session.history.generation=9007199254740992.0},
        {$saved.payload.station_defense_session.session.completion.generation=1.0},
        {$saved.payload.station_defense_session.session.completion.generation='2'},
        {$saved.payload.station_defense_session.session.history.reward_handoff_generation=2.0},
        {$saved.payload.station_defense_session.session.history.state_id='active'},
        {$saved.payload.station_defense_session.session.history.reward_replayable=0},
        {$saved.payload.station_defense_session.session.completion.reward_requested=1},
        {$saved.payload.station_defense_session.session.completion.reward_granted=$true},
        {$saved.payload.station_defense_session.session.history.PSObject.Properties.Remove('generation')},
        {$saved.payload.station_defense_session.session.completion.PSObject.Properties.Remove('generation'); $saved.payload.station_defense_session.session.completion | Add-Member -NotePropertyName GENERATION -NotePropertyValue 2.0},
        {$saved.payload.station_defense_session.session.completion | Add-Member -NotePropertyName extra -NotePropertyValue 1},
        {$saved.payload.station_defense_session.session | Add-Member -NotePropertyName elapsed_seconds -NotePropertyValue 10.5},
        {$ready.armed_elapsed_seconds=9.0}, {$ready.receipts=1},
        {$saved.payload.crash_recovery.state='clean'}, {$ready.runtime_observation.player_seated=$false},
        {$saved.payload.runtime_settings=[pscustomobject]@{changed=$true}},
        {$ready.foreign_reward_counts.debris_route_navigation_data=0}
    )) {
        $savedBaseline=$saved | ConvertTo-Json -Depth 60; $readyBaseline=$ready | ConvertTo-Json -Depth 60
        & $mutation; $ready.boundary=$saved.payload.station_defense_session; $rejected=$false
        try { Assert-InWorldStationArm $saved $ready } catch { $rejected=$true }
        if (-not $rejected) { throw 'invalid matching defense unpaid disk/token accepted' }
        $saved=$savedBaseline | ConvertFrom-Json; $ready=$readyBaseline | ConvertFrom-Json
        Assert-InWorldStationArm $saved $ready
    }
    $paid=$ready.boundary | ConvertTo-Json -Depth 60 | ConvertFrom-Json
    $paid.session.completion.reward_granted=$true; $paid.session.history.reward_handoff_generation=$paid.session.completion.generation
    $final=[pscustomobject]@{payload=[pscustomobject]@{station_defense_session=$paid; runtime_settings=$ready.foreign_settings; jovian_cargo_session=$ready.foreign_cargo; game_flow_reward_store=[pscustomobject]@{reward_counts=[pscustomobject]@{debris_route_navigation_data=1.0; return_defense_report_to_shipyard=1.0}; last_receipt=[pscustomobject]@{activity_id='shipyard_perimeter_defense'; activity_generation=2.0; reward_id='return_defense_report_to_shipyard'; granted=$true; replay_allowed=$false}}}}
    $recovered=[pscustomobject]@{paid_boundary=$paid; payment_commit=[pscustomobject]@{id='game-flow-reward-actual'}; foreign_settings=$ready.foreign_settings; foreign_cargo=$ready.foreign_cargo; foreign_reward_counts=$ready.foreign_reward_counts; safe_recovery_observation=[pscustomobject]@{player_seated=$true; craft_piloted=$true; piloting=$true; craft_id='bulwark_heavy_gunship'}; continuation_method='real_safe_home_pilot_resume_throttle_idle_pilot_exit_then_on_foot_physical_board_HUD_retry'; active_combat_restore='NOT_SUPPORTED'; elapsed_timer_restore='NOT_SUPPORTED'}
    $recovered.foreign_reward_counts = '{"debris_route_navigation_data":1.0}' | ConvertFrom-Json
    $defenseLog=Join-Path $root 'defense.log'
    $defenseAssertions=@(
        'PASS: fresh Boot restores only the exact owed report into safe idle content without old combat, elapsed timer or pilot-claim replay',
        'PASS: ordinary cold Resume reacquires the real safe-home pilot and preserves the unpaid defense report',
        'PASS: the recovered real pilot accepts ordinary throttle while the defense report stays unpaid',
        'PASS: the ordinary idle propulsion and production pilot exit release real seat ownership before the board retry',
        'PASS: the ordinary on-foot physical board HUD retry atomically publishes one reward receipt and the exact earned report acknowledgement',
        'PASS: duplicate reward, stale physical reset and genuine late unpaid checkpoint cannot repay or downgrade the acknowledged defense report',
        'PASS: the existing unrelated earned reward count is preserved',
        'PASS: the report retry preserves actual production settings and cargo progress',
        'PASS: defense restart closes both existing recovery marker owners'
    )
    [IO.File]::WriteAllText($defenseLog, ($defenseAssertions -join "`n")+"`n")
    Assert-InWorldStationRecovered $final $ready $recovered $defenseLog
    foreach ($mutation in @(
        {$final.payload.station_defense_session.session.completion.generation=3.0},
        {$final.payload.station_defense_session.session.completion.reward_granted=$false},
        {$final.payload.station_defense_session.session.history.reward_handoff_generation=0.0},
        {$final.payload.game_flow_reward_store.reward_counts.return_defense_report_to_shipyard=2.0},
        {$final.payload.game_flow_reward_store.reward_counts.debris_route_navigation_data=0.0},
        {$final.payload.game_flow_reward_store.reward_counts.return_defense_report_to_shipyard='1'},
        {$final.payload.game_flow_reward_store.reward_counts | Add-Member -NotePropertyName invented -NotePropertyValue 1.0},
        {$final.payload.game_flow_reward_store.last_receipt.activity_generation=3.0},
        {$final.payload.game_flow_reward_store.last_receipt.granted=1},
        {$final.payload.game_flow_reward_store.last_receipt.replay_allowed=$true},
        {$recovered.payment_commit.id='non-atomic'}, {$recovered.elapsed_timer_restore='PASS'},
        {$recovered.active_combat_restore='PASS'}, {$recovered.safe_recovery_observation.piloting=$false},
        {$recovered.foreign_cargo=[pscustomobject]@{changed=$true}},
        {$recovered.foreign_reward_counts=[pscustomobject]@{wrong_key=1.0}},
        {$recovered.foreign_reward_counts | Add-Member -NotePropertyName invented -NotePropertyValue 1.0},
        {$recovered.foreign_reward_counts.debris_route_navigation_data='1'},
        {$recovered.foreign_reward_counts.debris_route_navigation_data=1.5}
    )) {
        $finalBaseline=$final | ConvertTo-Json -Depth 60; $recoveredBaseline=$recovered | ConvertTo-Json -Depth 60
        & $mutation; $recovered.paid_boundary=$final.payload.station_defense_session; $rejected=$false
        try { Assert-InWorldStationRecovered $final $ready $recovered $defenseLog } catch { $rejected=$true }
        if (-not $rejected) { throw 'invalid matching defense acknowledgement/receipt accepted' }
        $final=$finalBaseline | ConvertFrom-Json; $recovered=$recoveredBaseline | ConvertFrom-Json
        Assert-InWorldStationRecovered $final $ready $recovered $defenseLog
    }
    foreach ($missing in $defenseAssertions) {
        [IO.File]::WriteAllText($defenseLog, (($defenseAssertions | Where-Object {$_ -ne $missing}) -join "`n")+"`n"); $rejected=$false
        try { Assert-InWorldStationRecovered $final $ready $recovered $defenseLog } catch { $rejected=$true }
        if (-not $rejected) { throw 'missing actual defense continuation assertion accepted' }
    }
    [array]::Reverse($defenseAssertions)
    [IO.File]::WriteAllText($defenseLog, ($defenseAssertions -join "`n")+"`n"); $rejected=$false
    try { Assert-InWorldStationRecovered $final $ready $recovered $defenseLog } catch { $rejected=$true }
    if (-not $rejected) { throw 'unordered actual defense continuation accepted' }
    $log = Join-Path $root 'startup.log'
    [IO.File]::WriteAllText($log, "WARNING: Atomic runtime settings load retained authored defaults: store_load_failed / newer_schema`nSTARTUP_MENU_READY_OK: {}`n")
    Assert-StartupLog $log 0 | Out-Null
    foreach ($case in @(@('', 0), @("STARTUP_MENU_READY_OK: {}`nSTARTUP_MENU_READY_OK: {}", 0), @('STARTUP_MENU_READY_OK: {}', 1), @("SCRIPT ERROR: broken`nSTARTUP_MENU_READY_OK: {}", 0), @("ERROR: broken`nSTARTUP_MENU_READY_OK: {}", 0), @("WARNING: ObjectDB instances leaked at exit`nSTARTUP_MENU_READY_OK: {}", 0))) {
        [IO.File]::WriteAllText($log, $case[0])
        $rejected = $false
        try { Assert-StartupLog $log $case[1] | Out-Null } catch { $rejected = $true }
        if (-not $rejected) { throw "invalid startup accepted: $($case[0])" }
    }
    $marker = Join-Path $root 'marker'
    $document = Join-Path $root 'mudds_user_data.json'
    [IO.File]::WriteAllText($marker, 'unchanged marker')
    [IO.File]::WriteAllText($document, 'saved settings and gameplay')
    $markerHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $marker).Hash
    $documentHashes = @{}
    $documentHashes[$document] = (Get-FileHash -Algorithm SHA256 -LiteralPath $document).Hash
    Assert-UserData
    [IO.File]::WriteAllText($document, 'silently reset by startup')
    $rejected = $false
    try { Assert-UserData } catch { $rejected = $true }
    if (-not $rejected) { throw 'changed save accepted with unchanged marker' }
    Remove-Item -LiteralPath $document
    $rejected = $false
    try { Assert-UserData } catch { $rejected = $true }
    if (-not $rejected) { throw 'missing save accepted with unchanged marker' }
    $profileRoot = Join-Path $root 'profile'
    $childReport = Join-Path $root 'child-environment.txt'
    $childSource = "[IO.File]::WriteAllText('$childReport', (`$env:APPDATA + '|' + `$env:LOCALAPPDATA + '|' + `$env:USERPROFILE))"
    $childEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childSource))
    $childExe = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $checkRecovery = $false
    $code = Run-Silent $childExe "-NoProfile -EncodedCommand $childEncoded" 10000
    $inherited = $env:APPDATA + '|' + $env:LOCALAPPDATA + '|' + $env:USERPROFILE
    if ($code -ne 0 -or [IO.File]::ReadAllText($childReport) -ne $inherited) { throw 'default installer environment changed' }
    $checkRecovery = $true
    $code = Run-Silent $childExe "-NoProfile -EncodedCommand $childEncoded" 10000
    $private = (Join-Path $profileRoot 'AppData\Roaming') + '|' + (Join-Path $profileRoot 'AppData\Local') + '|' + $profileRoot
    if ($code -ne 0 -or [IO.File]::ReadAllText($childReport) -ne $private) { throw 'recovery installer environment escaped private profile' }

    # Exercise the existing verifier's OS-kill/abort machinery using an owned
    # real child that commits a document then stays alive. This verifies the
    # harness only; installed-game qualification uses the production executable.
    $ProbeRoot = Join-Path $root 'forced-probe'
    New-Item -ItemType Directory -Path $ProbeRoot | Out-Null
    $document = Join-Path $ProbeRoot 'mudds_user_data.json'
    $UserDataRecoveryFixture = Join-Path $root 'fixture.json'
    $fixture = @{ schema_version = 1; generation = 2; payload = @{ runtime_settings = @{ values = @{ graphics_profile = 'low'; window_mode = 'windowed' } }; tutorial_prompts_seen = @{ seen_ids = @('retained-prompt') } } }
    [IO.File]::WriteAllText($UserDataRecoveryFixture, ($fixture | ConvertTo-Json -Depth 12))
    [IO.File]::WriteAllText($document, 'prior generation 90')
    foreach ($suffix in @('.bak', '.bak.1', '.bak.2', '.bak.3', '.tmp')) {
        [IO.File]::WriteAllText(($document + $suffix), ('prior transaction ' + $suffix))
    }
    [IO.File]::WriteAllText(($document + '.unrelated'), 'retain unrelated user file')
    Seed-ForcedKillFixture
    if ([IO.File]::ReadAllText($document) -ne [IO.File]::ReadAllText($UserDataRecoveryFixture)) { throw 'forced-kill fixture seed changed production document' }
    foreach ($suffix in @('.bak', '.bak.1', '.bak.2', '.bak.3', '.tmp')) {
        if (Test-Path -LiteralPath ($document + $suffix)) { throw 'forced-kill fixture retained incoherent prior transaction sibling' }
        $prior = Join-Path (Join-Path $ProbeRoot 'forced-kill-prior-documents') ('mudds_user_data.json' + $suffix)
        if ([IO.File]::ReadAllText($prior) -ne ('prior transaction ' + $suffix)) { throw 'forced-kill fixture removed prior transaction without witness' }
    }
    if ([IO.File]::ReadAllText(($document + '.unrelated')) -ne 'retain unrelated user file') { throw 'forced-kill fixture seeding changed unrelated file' }
    $interrupted = $fixture | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $interrupted.generation = 3
    $interrupted.payload | Add-Member -NotePropertyName safe_start_recovery -NotePropertyValue @{ state = 'starting'; startup_generation = 1; consecutive_failure_count = 0; safe_settings_recommended = $false }
    $interrupted.payload | Add-Member -NotePropertyName crash_recovery -NotePropertyValue @{ state = 'running'; startup_generation = 1; unclean_start_count = 0 }
    $encodedDocument = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($interrupted | ConvertTo-Json -Depth 12)))
    $childPidPath = Join-Path $ProbeRoot 'child-pid.txt'
    $childLogPath = Join-Path $ProbeRoot 'forced-kill-1-startup.log'
    $childSource = "[IO.File]::WriteAllText('$childPidPath', [string]`$PID); [IO.File]::WriteAllText('$document', [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encodedDocument'))); [IO.File]::WriteAllText('$childLogPath', 'STARTUP begin'); Start-Sleep -Seconds 60"
    $script:childEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childSource))
    function New-OwnedBootInfo([string]$log, [bool]$startupCheck) {
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = $childExe
        $info.Arguments = "-NoProfile -NonInteractive -EncodedCommand $script:childEncoded"
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        return $info
    }
    $StartupTimeoutMs = 10000
    $receipt = Run-ForcedKillBoot 1 $false
    if ($receipt -notmatch 'os_kill_exit=.+interrupted_markers_retained=True') { throw 'owned OS kill receipt missing' }
    $childPid = [int](Get-Content -LiteralPath $childPidPath -Raw)
    if (Get-Process -Id $childPid -ErrorAction SilentlyContinue) { throw 'OS-killed owned child still running' }
    $interrupted.payload.tutorial_prompts_seen.seen_ids = @('reset-prompt')
    $rejected = $false
    try { Assert-RecoveryPayload $interrupted $false } catch { $rejected = $true }
    if (-not $rejected) { throw 'forced-kill lost tutorial progress accepted' }
    # Stale markers must time out, and finally must terminate only this child.
    $StartupTimeoutMs = 500
    $rejected = $false
    try { Run-ForcedKillBoot 2 $false | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'stale interrupted marker accepted as a fresh boot' }
    $childPid = [int](Get-Content -LiteralPath $childPidPath -Raw)
    if (Get-Process -Id $childPid -ErrorAction SilentlyContinue) { throw 'timeout left owned child running' }
    Write-Output 'NATIVE_ACCEPTANCE_REGRESSION_OK'
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force
}
"""
        # The executable acceptance now exceeds Windows' command-line limit;
        # pass a real script file, translating its path only for the WSL bridge.
        with tempfile.TemporaryDirectory(prefix="mudds-verifier-regression-") as tmp:
            script_path = Path(tmp) / "acceptance.ps1"
            script_path.write_text(script, encoding="utf-8")
            launch_path = str(script_path)
            if powershell.startswith("/mnt/"):
                launch_path = subprocess.check_output(
                    ["wslpath", "-w", launch_path], text=True
                ).strip()
            proc = subprocess.run(
                [powershell, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", launch_path],
                capture_output=True, text=True, timeout=30
            )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("NATIVE_ACCEPTANCE_REGRESSION_OK", proc.stdout)

    def test_failure_cleanup_is_guarded_and_preserves_original_diagnostic(self):
        text = VERIFY_PS1.read_text(encoding="utf-8")
        self.assertIn("default user installation already exists", text)
        self.assertIn("probe profile already exists", text)
        self.assertLess(text.index("Step 'preconditions'"), text.index("$script:ownsInstall = $true"))
        self.assertIn("if ($script:ownsInstall)", text)
        cleanup = text.split("function Cleanup-OwnedInstallation {", 1)[1].split("Step 'preconditions'", 1)[0]
        self.assertIn("InstallLocation -ne $installDir", cleanup)
        self.assertIn("no longer belongs to this probe", cleanup)
        self.assertNotIn("Remove-Item -LiteralPath $profileRoot", cleanup)
        self.assertNotIn("Remove-Item -LiteralPath $installDir -Recurse", cleanup)
        self.assertNotIn("Remove-Item -LiteralPath $startMenu -Recurse", cleanup)
        failure = text.split("function Step(", 1)[1].split("function Wait-Gone", 1)[0]
        self.assertLess(failure.index("$entry.detail = $_.Exception.Message"), failure.index("Cleanup-OwnedInstallation"))
        self.assertIn("$result.cleanup.detail = $_.Exception.Message", failure)


class BuildScript(unittest.TestCase):
    def _run(self, *args, env=None):
        merged = dict(os.environ)
        if env:
            merged.update(env)
        return subprocess.run(
            [str(BUILD_SCRIPT), *args], capture_output=True, text=True, env=merged
        )

    def _run_without_compiler(self, *args):
        # Keep real input/provenance commands available while excluding NSIS,
        # even on developer machines where makensis is installed.
        with tempfile.TemporaryDirectory() as bin_dir:
            for command in ("bash", "git", "dirname", "basename", "sed", "head"):
                executable = shutil.which(command)
                self.assertIsNotNone(executable, f"test requires {command}")
                (Path(bin_dir) / command).symlink_to(executable)
            return self._run(*args, env={"PATH": bin_dir})

    def test_rejects_unexported_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "game.exe"
            bad.write_bytes(b"x")
            proc = self._run_without_compiler(str(bad))
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("must be named MuddsShipyards-<7 hex>.exe", proc.stderr)

    def test_rejects_bare_setup_name_that_windows_shims(self):
        full = _head_commit()
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / f"MuddsShipyards-{full[:7]}.exe"
            source.write_bytes(b"x")
            proc = self._run(str(source), str(Path(tmp) / "setup.exe"))
        if not HAVE_MAKENSIS:
            self.skipTest("makensis not installed")
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("Insecure filename", proc.stderr)

    def test_rejects_unknown_revision(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "MuddsShipyards-fffffff.exe"
            bad.write_bytes(b"x")
            proc = self._run_without_compiler(str(bad))
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("is not a commit", proc.stderr)

    def test_valid_input_reports_missing_compiler_without_writing_artifacts(self):
        full = _head_commit()
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / f"MuddsShipyards-{full[:7]}.exe"
            source.write_bytes(b"payload")
            output = Path(tmp) / f"MuddsShipyards-{full[:7]}-setup.exe"
            proc = self._run_without_compiler(str(source), str(output))
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("makensis (NSIS 3) is not installed", proc.stderr)
            self.assertEqual(source.read_bytes(), b"payload")
            self.assertEqual(list(Path(tmp).iterdir()), [source])

    @unittest.skipUnless(HAVE_MAKENSIS, "makensis not installed")
    def test_compiles_installer_and_records_provenance(self):
        full = _head_commit()
        short = full[:7]
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / f"MuddsShipyards-{short}.exe"
            payload = os.urandom(65536)
            source.write_bytes(payload)
            # A bare "setup.exe" trips makensis' insecure-filename warning
            # (Windows loads compatibility shims for it), which -WX rejects.
            output = Path(tmp) / f"MuddsShipyards-{short}-setup.exe"
            proc = self._run(str(source), str(output))
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertTrue(output.is_file())
            self.assertGreater(output.stat().st_size, 65536)
            record = json.loads((Path(tmp) / f"MuddsShipyards-{short}-setup.exe.installer-result.json").read_text())
            self.assertEqual(record["schema_version"], 1)
            self.assertEqual(record["source_commit"], full)
            self.assertEqual(record["source_exe_sha256"], hashlib.sha256(payload).hexdigest())
            self.assertEqual(record["installer_sha256"], hashlib.sha256(output.read_bytes()).hexdigest())
            self.assertEqual(record["installer_bytes"], output.stat().st_size)
            self.assertEqual(record["signing"], "unsigned")
            self.assertEqual(record["native_verification"], "NOT_RUN")
            self.assertRegex(record["build_label"], rf"^\d+\.\d+\.\d+\+{short}$")
            digest_line = (Path(tmp) / f"MuddsShipyards-{short}-setup.exe.sha256").read_text().split()
            self.assertEqual(digest_line, [record["installer_sha256"], output.name])
            # A Windows PE with the NSIS uninstaller resource embedded.
            head = output.read_bytes()[:2]
            self.assertEqual(head, b"MZ")
            self.assertTrue(re.search(rb"Nullsoft", output.read_bytes()[:400000]))


if __name__ == "__main__":
    unittest.main()
