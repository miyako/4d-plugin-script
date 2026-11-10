# Native ownership audit

## Immutable scope and provenance

Issue: [#2](https://github.com/miyako/4d-plugin-script/issues/2).
Baseline: `059fefc51cf4f7791d8ab7b682087361c9b6af20`.
Guidance: `miyako/skills/4d-skills/skills/4dplugin/SKILL.md` at
`e6b492fcb81e5e1a7f7db723594b420e63bf6eb9`, read through the immutable contents
API, without another checkout. The SDK says `rev : v14`; this is not a
verified upstream SDK release identifier.

The complete bundled SDK is compiled, unmodified, in the regression host.
The driver checks these Git blob IDs before compiling:

| File under `4D Plugin API/` | Baseline blob |
|---|---|
| `4DPluginAPI.c` | `29788ed041effaf67269ccd93f971e8aee2ce5f8` |
| `4DPluginAPI.h` | `9054b45ffc7ff6f5b8d57529a3788a55d977b314` |
| `EntryPoints.h` | `730f2f77ff2713fb2fe4b7d6562baeedf5f664cb` |
| `Flags.h` | `10a83185333dac06a62dda61b9f9428243d1e2ee` |
| `PrivateTypes.h` | `77053dc0c0a3718d2d3b6f158371a6af78c6ae66` |
| `PublicTypes.h` | `2bb392e73e9c556c274fe0a75b3a6b83e310b77c` |
| `4DPluginAPI.def` | `996ecc4ab11ad165de9192eba2e7478db141c757` |

Prior host structure was read from `miyako/4d-plugin-process` at
`928f2e7d648bbadbc13a6b1bccfd14ff24cede08`
(`.github/tests/ownership_host.mm`, `ownership_platform.h`,
`test_ownership.py`, `Classes/CommandArguments.h`, `C_PICTURE.cpp` and
`C_POINTER.cpp`). Contracts, source roots, SDK implementation hash, pointer
reference tests and dispatcher expectations here are specific to Script;
results from the prior repository are not evidence for this repository.

## Complete tracked native/build inventory

The baseline has 43 tracked native source/header/export/prefix files: 18
translation units, 23 headers, one export definition and one prefix header.
There are no additional tracked native implementations hidden in the bundled
example database. The following inventory includes dormant capabilities;
indexed absence of call sites is not a safety proof.

| Paths | Ownership surface and production reachability |
|---|---|
| `4DPlugin.cpp`, `4DPlugin.h` | Actual exported dispatch and Windows COM/Active Scripting implementation. Only selector 1, `Script_parse`. |
| `4D Plugin_Prefix.pch` | Carbon include; no ownership logic. |
| Seven SDK files listed above | Complete engine forwarding, ABI/types, export entry `FourDPackex`; protected and unchanged. |
| `4D Plugin API/Classes/C_TYPES.h` | C++ string/vector aliases, package pointer and platform imports; unchanged. |
| `Classes/C_TEXT.cpp`, `.h` | Sole wrapper instantiated by the production command. Deep-copies parameter UTF-16 into C++ storage; engine-backed content setters for output/return. Already noncopyable at baseline. Dormant Objective-C path/string conversion helpers. |
| `Classes/ARRAY_TEXT.cpp`, `.h` | Compiled, not called by dispatcher. Borrowed array elements copied into independent C++ strings; distinct owned SDK allocation transferred for each output element, including element zero. No post-transfer dispose. |
| `Classes/ARRAY_BOOLEAN.cpp`, `.h` | Compiled dormant owner of heap `CboolArray`; borrowed SDK input copied to vector, scalar element setters. |
| `Classes/ARRAY_DATE.cpp`, `.h` | Compiled dormant owner of heap `CDateArray`; copies value-type `C_DATE` elements. |
| `Classes/ARRAY_INTEGER.cpp`, `.h` | Compiled dormant owner of heap `CShortArray`; scalar element setters. |
| `Classes/ARRAY_LONGINT.cpp`, `.h` | Compiled dormant owner of heap `CIntArray`; scalar element setters. |
| `Classes/ARRAY_REAL.cpp`, `.h` | Compiled dormant owner of heap `CDoubleArray`; scalar element setters. |
| `Classes/ARRAY_TIME.cpp`, `.h` | Compiled dormant owner of heap `CIntArray`; scalar element setters. |
| `Classes/C_BLOB.cpp`, `.h` | Compiled dormant `C_BLOB` owns heap `CBytes`; `CBytes` itself owns a vector by value and remains copyable. SDK handles are borrowed on input and independently allocated for output/return. Hex/base64 helpers use C_TEXT. |
| `Classes/C_PICTURE.cpp`, `.h` | Compiled dormant `CPicture` owns a picture reference and heap CBytes; `C_PICTURE` owns heap CPicture. All file/format/size/thumbnail/transform command helpers included in audit. |
| `Classes/C_POINTER.cpp`, `.h` | Compiled dormant borrowed pointer wrapper and variable/field reference construction. No pointer ownership acquired by constructor/destructor. |
| `Classes/C_DATE.cpp`, `.h`; `C_INTEGER.cpp`, `.h`; `C_LONGINT.cpp`, `.h`; `C_REAL.cpp`, `.h`; `C_TIME.cpp`, `.h` | Compiled value-only scalar wrappers, no owned SDK strings. C_DATE must remain copyable for ARRAY_DATE. |

All `Classes/` paths in the table are under `4D Plugin API/`.
`Script.xcodeproj/project.pbxproj` Sources phase and both
`Script.vcxproj` and dormant `Script.vc10.vcxproj` list the same SDK C file,
16 wrapper CPP files and `4DPlugin.cpp`. Both `.filters` files are IDE
memberships, not additional implementations. `Script.sln` selects
`Script.vcxproj`. The test compiles all 18 actual translation units together,
including the actual dispatcher and all wrapper consumers; it does not
replace SDK functions or compile extracted SDK fragments.

Root `manifest.json` and the tracked prebuilt bundle's resource manifest both
declare only `Script parse(&T;&T):T`: two scalar text parameters and scalar
text return, no exported array/property/collection/callback surfaces.
`4DPlugin.cpp` confirms the sole selector and `#if VERSIONWIN` body.
No object/collection getter API or wrapper is present in this exact SDK;
object/collection owner counts are **not applicable**, not simulated coverage.
No actual copy/assignment call site for any of the ten newly noncopyable
classes was found in the tracked implementations. Their implicit-copy
defect is a dormant capability, not a production copy reproduced in 4D.

## Exact SDK contracts and fixes

Line references here refer to the immutable baseline `4DPluginAPI.c`.

| Contract | Evidence and consequence |
|---|---|
| `PA_CreateUnistring`, `PA_SetUnistring`, `PA_DisposeUnistring` (244-270) | Engine creation/content replacement/disposal; struct assignment is not a deep copy. The host exercises allocated and null empty representations. |
| `PA_CreateVariable` (3523 onward), `PA_SetStringVariable` (3826-3831) | Creating a text variable creates an empty owned string. Setter shallow-assigns without disposing that owner. Picture setter likewise shallow-assigns. Initialize command argument slots Undefined, then assign each new owner once. |
| `PA_GetStringInArray` (4266 onward), `PA_SetStringInArray` (4444 onward) | Borrowed getter; accepted setter disposes old element then transfers struct. Kind Unicode, nonnull data, `0 <= index <= count`, nonnull descriptor required. Rejection does not consume. ARRAY_TEXT already follows normal successful-transfer ownership; no blanket disposal change. |
| `PA_GetPictureVariable` (3730 onward), `PA_DuplicatePicture` (447-454) | Getter borrowed; duplicate with retainOnly=1 retains. Retain output before argument cleanup; release temporary creation owner after setPicture's retain. |
| `PA_ConvertCharsetToCharset` (4775-4794) | Explicitly returns bytes, not UTF-16 units. `createCopy` divides by `sizeof(PA_Unichar)` before CUTF16String construction, checks error first. Capacity includes room for a terminator. |
| `PA_ExecuteCommandByID` (5257-5290) | Returns a variable; successful return cleaned regardless of kind. On handle failure raw fType remains zero (SDK normalizes zero as string); do not inspect/adopt/clear failure output. CommandArguments checks the saved error before touching the return and cleans its established argument owners on success/exception. |
| `PA_GetPointerValue` (2035 onward), header line 409 | Owning value with explicit cleanup requirement; not reference metadata. Old wrapper read its value union as a variable definition and leaked the owner. |
| `PA_SetVariableOrFieldReference` (3923-3944), header lines 587-591 | Explicit SDK command-argument reference constructor: scopes 0..3 map to raw reference kinds 26,9,35,13; filler 1; name/index/scope/tag copied from pointer. No engine call, allocation or failure output. Named-variable wrapper now uses this exact helper; invalid scope is rejected before the helper's unchecked table index. |
| `PA_SetTableFieldVariable` (3914-3920), `PA_GetPointerKind` (2055-2067) | Existing field branch already produces kind 3/filler 1/table/field/zero reserved field, matching SDK reference representation. It remains unchanged; null/default wrapper remains a no-op. |

`CPicture::fromFileAtPath` previously disposed the same shallow string once
explicitly and again through args[0], leaked the overwritten empty owner,
and omitted output-picture cleanup. Its new scoped arguments own the path
once and retain the output in setPicture before clearing args[1].
`setBytes` now releases its temporary creation reference through a scoped
owner after setPicture retains it. The five picture command paths share one
noncopyable scoped argument helper, check execution errors before output
adoption and release successful owning returns.

Deleted-copy declarations, matching existing C_TEXT prior art, prevent
double destruction of the seven array heap pointers, C_BLOB's CBytes pointer,
CPicture's CBytes/picture owners and C_PICTURE's CPicture pointer.
No SDK/ABI headers, manifests, product projects, resources or binaries changed.

## Reproducible offline evidence

Run on macOS:

```sh
python3 .github/tests/test_ownership.py -v
```

For comparison, extract immutable baseline sources with `git archive` into
a separate temporary directory, then run the **same final harness** with
`OWNERSHIP_SOURCE_ROOT` pointing there. Do not copy the final harness into
the baseline or alter its SDK to make it compile. Local final results:

| Same final harness | Cases | Passed | Failed |
|---|---:|---:|---:|
| Archived baseline 059fefc | 75 | 16 | 59 |
| Fixed actual source | 75 | 75 | 0 |

Named failures include `path` duplicate/unowned string disposal,
`copy` ASCII ASan heap-buffer-overflow, `bytes` extra retained picture
reference, `pointer` unexpected owning lookup instead of reference metadata,
`pointer-invalid` missing invalid-scope rejection, all ten individually
named shallow-copy capabilities, and picture command failure/return-owner
imbalances. Controls that pass unchanged on baseline and fix: two macOS
no-op dispatch cases, two array transfer cases, eight scalar lifetime cases,
one SDK failure-predicate characterization, field reference metadata,
C_TEXT's existing noncopyability and copyable value-type traits (16 total).

Fixtures exercise exact ASCII/BMP/supplementary/empty text with both empty
engine representations, UTF-16 lengths/terminators, converter bytes/capacity,
replacement/churn/shrink/clear, independent array elements and rejected
kind/data/index/null descriptor, picture output retention after wrapper
destruction, successful Undefined/string/picture command returns, command
handle failure, poisoned failed command return, conversion and picture
creation failure. Each successful case requires explicit zero string,
picture and handle owner balances.

ASan/UBSan are enabled. Alignment sanitization alone is disabled for this
packed legacy SDK ABI; leak sanitizer is disabled on macOS, with explicit
owner/ref counters instead. All platform URL/image boundaries are redirected
by a force-included header **before compiling every source**. Unexpected
SDK selectors fail closed, and undefined imports are checked for real
script/process/shell/automation/path APIs. No real script was evaluated,
no process/application was queried or launched, no AppleEvent was sent,
and no private database/user-data fixture was opened.

The actual macOS PluginMain/dispatcher is executed with synthetic parameters
and verified to remain a no-op. **This is not Windows Script_parse coverage.**
The Windows-only COM/registry/Active Scripting code is statically traced:
C_TEXT copies input buffers, and success-path BSTR results are copied to
CUTF16String before VariantClear. Windows failure-output/EXCEPINFO string
cleanup and native COM engine behavior have not been executed or certified
by this harness; they require a separate synthetic Windows boundary host.
No Windows 4D crash is claimed reproduced.

## Build safety and explicit deferrals

Before validation, both existing workflows, release/source-version scripts,
solution/project memberships and Xcode phases were inspected.
`Bump version` and `Build` trigger only through manual workflow_dispatch.
Build signs, packages, notarizes and publishes binaries; it was not invoked.
Xcode has sources/headers/frameworks/resources/Rez/copy phases (no shell
phase), but writes into the example database's Plugins directory.
MSBuild imports standard/user props and targets. Neither product build was
run; unsigned direct clang compilation writes only into a temporary directory.
The new Native ownership workflow has read-only contents permission and
only runs this synthetic host on supported `macos-latest`, with narrowly
filtered pull-request and exact audit/default-branch push events.

Allocation/resize OOM is **not certified**. In the actual SDK, failed handle
resize can still change array logical count while physical storage remains
unchanged. The characterization test proves this discrepancy and repairs
only its synthetic descriptor for cleanup; wrappers are not then executed
on that inconsistent array. Void wrapper/SDK APIs provide no safe general
failure-preservation boundary. Initial empty picture/string creation and
successful picture-metadata ownership likewise are not inferred safe from
passing normal tests. In particular PA_GetPictureData's comments describe
metadata but do not establish its successful return's ownership; the host
tests error-before-metadata-use using poisoned output and does not invent a
successful metadata cleanup contract. These limits need concrete SDK/host
contract evidence, not SDK rewrites or empty-success fallbacks.
