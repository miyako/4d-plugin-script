![version](https://img.shields.io/badge/version-16%2B-8331AE)
![platform](https://img.shields.io/static/v1?label=platform&message=win-32%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-script)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-script/total)

# 4d-plugin-script

This plugin lets 4D evaluate script code through the Windows Active Scripting engine (`IActiveScript`/`IActiveScriptParse`, the COM technology behind Windows Script Host, JScript, and VBScript). You pass it the name of an installed scripting engine and a snippet of code; it runs the snippet as a single expression and hands the result back to 4D as `Text`. It does not implement a scripting language itself — it is a thin bridge to whatever `IActiveScript`-compatible engine is registered on the machine (JScript and VBScript ship with Windows; other languages work too if their engine is registered under Windows' Active Scripting COM machinery).

| Command | Returns | Purpose |
|---|---|---|
| [Script parse](#script-parse) | Text | Evaluate a script expression with a named scripting engine and return the result as text |

**Platforms:** Windows only (win-32 \| win-64)

---

## Requirements & platform notes

- **Windows only.** The plugin is built entirely on Windows' Active Scripting COM interfaces (`ole2.h`/`activscp.h`); there is no macOS build and none is planned — this is a Windows-specific technology, not a cross-platform gap.
- **The engine must actually be registered on the machine running 4D.** `Script parse`'s first parameter accepts, in order of attempt: a COM ProgID (`"JScript"`, `"VBScript"`), a CLSID string (`"{xxxxxxxx-...}"`), or a file extension that Windows associates with a script engine (`".js"`, `".vbs"`). If none of these resolve to a registered engine, the command returns an empty string — there is no error raised in 4D.
- **VBScript is being phased out by Microsoft.** As of 2026, VBScript is in the middle of a multi-phase deprecation: it currently ships enabled by default as a Feature on Demand, but Microsoft's published timeline calls for it to be disabled by default and eventually removed from Windows in upcoming releases. If you depend on `Script parse ("vbscript"; ...)` or `Script parse (".vbs"; ...)`, confirm VBScript is still enabled on your deployment target rather than assuming it ships by default going forward; JScript's long-term status hasn't been announced with the same specificity, so don't assume parity between the two.
- **Both parameters are mandatory Text values.** There is no optional form and no default engine.
- **Only scalar, string, and date results come back as text.** If the evaluated expression's result is an object (for example, a JScript `Date` value returned directly, as in the plugin's own `Script parse ("JScript";"Date()")` example — see below), the command returns an empty string. See "Error handling" below.
- **Each call is a single, one-shot expression evaluation**, not a persistent session — `SCRIPTTEXT_ISEXPRESSION` is used internally, so there's no state (variables, functions) carried over between separate `Script parse` calls, even with the same engine name.

---

## Script parse

### Syntax

```
Script parse ( engine ; script ) → Result
```

| Parameter | Type | Description |
|---|---|---|
| `engine` | Text | Identifies the scripting engine to use: a ProgID (`"JScript"`, `"VBScript"`), a CLSID string, or a file extension mapped to an engine in the Windows registry (`.js`, `.vbs`, etc.) |
| `script` | Text | The script expression to evaluate |
| Result | Text | The evaluated result, converted to text. Empty if the engine couldn't be resolved, the script failed, or the result isn't a type this command converts (see below) |

### Description

`Script parse` resolves `engine` to a COM class ID for a Windows Active Scripting engine, creates an instance of it, and evaluates `script` as a single expression. The result is converted to `Text` according to its underlying type:

- Numbers (integer and floating-point, signed and unsigned, 16/32/64-bit) are converted with their natural decimal representation.
- Dates (`VT_DATE`) are converted to an ISO‑8601‑style string: `YYYY-MM-DDTHH:mm:ss.sss`.
- Strings (`VT_BSTR`) are passed through as-is.
- An empty/null script result (`VT_EMPTY`/`VT_NULL`) converts to an empty string, indistinguishable from a failure — see "Error handling" below.
- Any other result type — notably an object result (`VT_DISPATCH`, e.g. a JScript `Date` object returned directly rather than converted to a string) — is **not** converted and comes back as an empty string. If you need an object's value, convert it to a string or primitive inside the script itself (e.g. call `.toString()`/`.valueOf()` in JScript, or use `CStr(...)` in VBScript) rather than returning the object directly.

`engine` is looked up once per call, in this order: as a ProgID, then as a CLSID string, then as a file-extension-to-engine registry mapping. Whichever resolves first is used.

### Example

From the plugin's own `README.md`:

```4d
$result:=Script parse ("JScript";"Date()")
$result:=Script parse (".js";"1+2")

$result:=Script parse ("vbscript";"Now")
$result:=Script parse (".vbs";"Now")

$result:=Script parse ("JScript";"var a;a = 1;a++;a;")
$result:=Script parse ("vbscript";"4*atn(1.0)")
```

Note that the first line (`Date()`) returns an empty string per the object-result caveat above; the other lines return their expected text values.

A couple of additional illustrative variations, built only from the same documented behavior:

```4d
// Force a JScript object result to a string so it actually comes back as text
$result:=Script parse ("JScript";"Date().toString()")

// Same idea in VBScript
$result:=Script parse ("vbscript";"CStr(Now)")
```

```4d
// engine can also be looked up by file extension instead of ProgID
$result:=Script parse (".vbs";"1 + 2 * 3")
```

---

## Error handling & troubleshooting

- **An unresolved engine name fails silently.** If `engine` doesn't match a registered ProgID, CLSID, or file-extension association, `Script parse` returns an empty string with no 4D error — there's no way to distinguish this from a script that legitimately evaluated to nothing. If you're getting unexpected empty results, first confirm the engine is actually registered on that machine (e.g. check `HKEY_CLASSES_ROOT` for the ProgID, or that the corresponding scripting DLL is installed).
- **A script syntax or runtime error also fails silently.** Parse/evaluation errors are captured internally but not surfaced to 4D or reported anywhere — a bad script and an engine that isn't installed look identical from 4D's side (empty result).
- **Returning an object from the script yields an empty string, not an error.** This is the most common surprise: `Date()` in JScript returns a `Date` object, not a string, so it converts to nothing. Always convert the script's final expression to a string, number, or date explicitly (`.toString()`, `CStr(...)`, etc.) before returning it.
- **VBScript may not be available on newer Windows deployments going forward** given Microsoft's phased deprecation (see "Requirements" above) — treat `"vbscript"`/`".vbs"` as a caveat to re-verify per target machine, not a permanent guarantee.
- **This command has no Mac equivalent.** If your 4D project needs to run cross-platform, gate any code path that calls `Script parse` behind a platform check rather than assuming it's available everywhere.

---

## Quick reference

```4d
// JScript expression, forcing a string result
$js:=Script parse ("JScript";"(1+2).toString()")

// VBScript expression via file-extension lookup
$vbs:=Script parse (".vbs";"CStr(4*atn(1.0))")

// Current date/time as text, from either engine
$now_js:=Script parse ("JScript";"new Date().toString()")
$now_vbs:=Script parse ("vbscript";"CStr(Now)")
```

## Release maintenance

**Bump version** and **Build** are independent manual Actions workflows. Select
the desired branch in the Actions UI; neither workflow is restricted to `master`.
Bump version retains the patch/minor/major choice, validates coordinated source
metadata, commits only `Script.xcodeproj/project.pbxproj`, `Info.plist` and the
source `English.lproj/InfoPlist.strings`, and pushes only the explicitly selected
branch, nonforce with follow-tags disabled.
It rejects a branch that moved since dispatch or during preparation. A pre-push
hook also requires the receive-pack advertised old SHA to equal the selected
SHA, rejecting advances, rewinds, deletions and same-result races between the
last check and the push advertisement. Git's normal nonforce update checks
remain in effect. It creates no tag and does not start Build. Dispatch again
from the current branch if a concurrent update prevents the bump.

The source authority is the single strict `X.Y.Z` shared by all six
`MARKETING_VERSION` and six `CURRENT_PROJECT_VERSION` settings and the source
plist's `CFBundleShortVersionString` (and `CFBundleVersion` when present).
Supported plist references to either coordinated Xcode setting, and
current-project references to `MARKETING_VERSION`, are preserved. Unknown,
cyclic, malformed or drifted versions fail before bump/build. The former bump
header promised coordinated current-project versions but its code only changed
marketing versions; the migration repairs that drift to the existing marketing
version, without incrementing it. The source localized short version and
`CFBundleGetInfoString` version are also coordinated: their stale `1.0` values
otherwise override the displayed bundle version. The copyright year is retained.
Prebuilt bundle metadata, dependency versions and 4D format versions are not
release-version inputs.

**Build** has no inputs beyond the branch selector and runs only via
`workflow_dispatch`. Every checkout uses the selected immutable `github.sha`,
not a moving branch or tag. It retains the Windows x64 build, macOS universal
build, merged bundle, signature verification, ZIP/DMG notarization and DMG
stapling. The macOS bundle is still built and distributed even though the
Active Scripting command implementation is Windows-only. Assets remain
`Script-X.Y.Z.zip` and `Script-X.Y.Z.dmg`; certificate/notary secret names and
native dependencies are unchanged.

Build runs are serialized repository-wide across branches. Before building,
and again after every required native/signing/notary/package gate immediately
before publication, authenticated paginated release-list checks include drafts.
An existing remote tag or same-tag draft/published release blocks publication;
API errors (including 404), authentication/network failures and malformed pages
fail closed. Publication creates `vX.Y.Z` at the selected SHA using a create-only
Git ref POST, verifies the remote SHA, then creates a published non-prerelease
using a REST POST with explicit tag, commit and name. Notes remain empty, as in
the original workflow (no generated notes). Asset POSTs target only the newly
returned release ID; nothing is overwritten.

**Partial publication recovery:** there is no automatic deletion, editing,
rollback or retry. A failed tag/release/upload request can leave a tag, a
published release without assets, or a release with only some assets. Inspect
the Actions error and remote tag/release/assets before making a human recovery
decision; a lost response may still mean the server accepted the request.
Rerunning Build for the same version intentionally fails on that retained state.
Do not delete or retarget published versions automatically; reconcile partial
state explicitly outside these workflows, or bump source metadata and publish
a fresh version once the incident is understood.

Local lifecycle checks (no native builds, signing, dispatch or publication):

```sh
python3 -m unittest discover -s .github/tests -v
actionlint .github/workflows/*.yml
```
