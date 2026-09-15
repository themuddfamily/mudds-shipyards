; Mudd's Shipyards per-user Windows installer.
;
; Compiled by tools/release/build_windows_installer.sh with makensis (NSIS 3),
; which supplies every define below. The installer is unsigned: a build that
; carries no Authenticode signature is still an unsigned artifact and SmartScreen
; will say so. It installs for the current user only (no elevation), never
; touches the player's saved settings/saves under %APPDATA%\Godot, and can be
; driven silently: `Setup.exe /S /D=C:\path` installs, `uninstall.exe /S`
; removes. Both paths are exercised natively by verify_windows_installer.ps1.

!ifndef SOURCE_EXE
  !error "SOURCE_EXE must point at the exported MuddsShipyards-<commit>.exe"
!endif
!ifndef SHORT_COMMIT
  !error "SHORT_COMMIT (seven hex characters) is required"
!endif
!ifndef FULL_COMMIT
  !error "FULL_COMMIT (forty hex characters) is required"
!endif
!ifndef PRODUCT_VERSION
  !error "PRODUCT_VERSION (e.g. 0.12.0) is required"
!endif
!ifndef OUTPUT_FILE
  !error "OUTPUT_FILE is required"
!endif

!define PRODUCT_NAME "Mudds Shipyards"
!define PRODUCT_PUBLISHER "Mudds Shipyards"
!define PRODUCT_EXE "MuddsShipyards.exe"
!define UNINSTALL_EXE "uninstall.exe"
!define REG_UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\MuddsShipyards"
!define REG_APP_KEY "Software\Mudds Shipyards"
!define BUILD_LABEL "${PRODUCT_VERSION}+${SHORT_COMMIT}"

Unicode true
Name "${PRODUCT_NAME} ${BUILD_LABEL}"
OutFile "${OUTPUT_FILE}"
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\Programs\${PRODUCT_NAME}"
InstallDirRegKey HKCU "${REG_UNINSTALL_KEY}" "InstallLocation"
SetCompressor /SOLID lzma
SetCompressorDictSize 32
ShowInstDetails show
ShowUninstDetails show
BrandingText "${PRODUCT_NAME} checkpoint ${SHORT_COMMIT} (unsigned)"

VIProductVersion "${PRODUCT_VERSION}.0"
VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "CompanyName" "${PRODUCT_PUBLISHER}"
VIAddVersionKey "FileDescription" "${PRODUCT_NAME} installer (${BUILD_LABEL})"
VIAddVersionKey "FileVersion" "${PRODUCT_VERSION}.0"
VIAddVersionKey "ProductVersion" "${BUILD_LABEL}"
VIAddVersionKey "LegalCopyright" "Unsigned checkpoint build; no distribution rights implied"

!include "MUI2.nsh"
!include "FileFunc.nsh"

!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "${PRODUCT_NAME}"
!define MUI_WELCOMEPAGE_TEXT "This installs the unsigned checkpoint build ${BUILD_LABEL} for the current Windows user only.$\r$\n$\r$\nNo administrator rights are needed. Existing settings and saves are kept.$\r$\n$\r$\nSource commit: ${FULL_COMMIT}"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${PRODUCT_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${PRODUCT_NAME}"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Var PreviousCommit

Function .onInit
  ; An upgrade over a previous per-user install records what it replaced. The
  ; player's user data lives under %APPDATA%\Godot\app_userdata and is not
  ; part of this install location, so an upgrade never rewrites it.
  ReadRegStr $PreviousCommit HKCU "${REG_APP_KEY}" "SourceCommit"
FunctionEnd

Section "Install" SEC_MAIN
  SetOutPath "$INSTDIR"
  SetOverwrite on
  File "/oname=${PRODUCT_EXE}" "${SOURCE_EXE}"

  ; Machine-readable provenance beside the executable, for support bundles.
  FileOpen $0 "$INSTDIR\source-commit.txt" w
  FileWrite $0 "product=${PRODUCT_NAME}$\r$\n"
  FileWrite $0 "version=${PRODUCT_VERSION}$\r$\n"
  FileWrite $0 "build_label=${BUILD_LABEL}$\r$\n"
  FileWrite $0 "source_commit=${FULL_COMMIT}$\r$\n"
  FileWrite $0 "signing=unsigned$\r$\n"
  FileClose $0

  WriteUninstaller "$INSTDIR\${UNINSTALL_EXE}"

  CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
  CreateShortcut "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk" "$INSTDIR\${PRODUCT_EXE}" "" "$INSTDIR\${PRODUCT_EXE}" 0
  CreateShortcut "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall ${PRODUCT_NAME}.lnk" "$INSTDIR\${UNINSTALL_EXE}"

  WriteRegStr HKCU "${REG_APP_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${REG_APP_KEY}" "SourceCommit" "${FULL_COMMIT}"
  WriteRegStr HKCU "${REG_APP_KEY}" "BuildLabel" "${BUILD_LABEL}"
  ${If} $PreviousCommit != ""
    WriteRegStr HKCU "${REG_APP_KEY}" "UpgradedFrom" "$PreviousCommit"
  ${Else}
    DeleteRegValue HKCU "${REG_APP_KEY}" "UpgradedFrom"
  ${EndIf}

  WriteRegStr HKCU "${REG_UNINSTALL_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "${REG_UNINSTALL_KEY}" "DisplayVersion" "${BUILD_LABEL}"
  WriteRegStr HKCU "${REG_UNINSTALL_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "${REG_UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${REG_UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\${PRODUCT_EXE}"
  WriteRegStr HKCU "${REG_UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\${UNINSTALL_EXE}"'
  WriteRegStr HKCU "${REG_UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\${UNINSTALL_EXE}" /S'
  WriteRegDWORD HKCU "${REG_UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${REG_UNINSTALL_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "${REG_UNINSTALL_KEY}" "EstimatedSize" "$0"
SectionEnd

Section "Uninstall"
  ; Only what the installer wrote is removed. Player settings and saves under
  ; %APPDATA%\Godot\app_userdata\Mudds Shipyards are deliberately left alone;
  ; crash logs the game wrote beside the executable, if any, are removed with it.
  Delete "$INSTDIR\${PRODUCT_EXE}"
  Delete "$INSTDIR\source-commit.txt"
  Delete "$INSTDIR\${UNINSTALL_EXE}"
  RMDir "$INSTDIR"

  Delete "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall ${PRODUCT_NAME}.lnk"
  RMDir "$SMPROGRAMS\${PRODUCT_NAME}"

  DeleteRegKey HKCU "${REG_UNINSTALL_KEY}"
  DeleteRegKey HKCU "${REG_APP_KEY}"
SectionEnd
