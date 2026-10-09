# Off-stack unit tests

The ABAP Unit tests of the ABAP Test Kit run without an SAP system: the sources are
transpiled to JavaScript with the [abaplint transpiler](https://github.com/abaplint/transpiler)
and executed on Node.js against [open-abap-core](https://github.com/open-abap/open-abap-core),
the open-source implementation of the SAP standard classes, and
[open-abap-xco](https://github.com/open-abap/open-abap-xco) for the XCO call stack.

```
npm ci            # toolchain: @abaplint/cli, @abaplint/transpiler-cli, @abaplint/runtime
npm run lint      # abaplint, ABAP Cloud rules (abaplint.json)
npm test          # fetch open-abap-core and open-abap-xco, transpile, run every ABAP Unit test
npm run unit      # run again without transpiling
npm run unit:verbose
node transpiler/run_unit_tests.mjs --filter LTC_STUB --verbose
```

CI: `.github/workflows/unit.yml`. Everything here is tooling; abapGit never imports it
(its starting folder is `/src/`) and abaplint never lints it (`abaplint.json` reads `/src/`).

## Files

| File | Purpose |
|---|---|
| `abap_transpile.json` (root) | Transpiler configuration: sources, libraries, setup hooks, skipped tests |
| `fetch_open_abap_core.mjs` | Fetches open-abap-core and open-abap-xco into `deps/`, each at a pinned commit |
| `run_unit_tests.mjs` | Test runner with a readable report and exit code 1 on failure |
| `setup.mjs` | Runtime patches applied before (`setup`) and after (`afterLoad`) the ABAP objects load; also loads `atdf/atdf_runtime.mjs` into `globalThis.atdfRuntime` |
| `atdf/cl_abap_testdouble.clas.abap` | CL_ABAP_TESTDOUBLE for the transpiler; delegates to `atdf/atdf_runtime.mjs` |
| `atdf/atdf_runtime.mjs` | JavaScript stand-in for the ABAP Test Double Framework |

The `IF_ABAP_TESTDOUBLE_*` interfaces and `CX_ATD_EXCEPTION_CORE` come from `/abaplint-stubs/`,
which the transpiler reads too; only `CL_ABAP_TESTDOUBLE` and the ABAP Unit classes are excluded
from there, because they need behaviour.

## Why a stand-in for the ATDF

open-abap-core does not ship `CL_ABAP_TESTDOUBLE` yet; it is proposed in
[open-abap/open-abap-core#1296](https://github.com/open-abap/open-abap-core/pull/1296). Until
that is merged, `atdf_runtime.mjs` builds the double as a JavaScript class from the interface
metadata the transpiler emits (`abap.Classes[<INTERFACE>].METHODS`). It implements what ATK and
the demo tests use:

- `create( )` for interfaces;
- `configure_call( )` with `ignore_all_parameters`, `ignore_parameter`, `times`, `returning`,
  `raise_exception`, `set_answer`, `and_expect( )->is_called_once / is_called_times / is_never_called`;
- the ATDF two-step (the next call on the double registers the configuration), matching of
  importing arguments against the registration call, and `verify_expectations( )`, which fails
  the test through `CL_ABAP_UNIT_ASSERT`;
- `IF_ABAP_TESTDOUBLE_ARGUMENTS` and `IF_ABAP_TESTDOUBLE_RESULT` for answers, with the same
  conversion of arguments to the formal parameter type a method call does.

Not implemented: doubling classes, matchers, events, `set_parameter( )`. A test that needs
them fails with `CX_ATD_EXCEPTION_CORE` and a message that names the missing feature.

Once the pull request is merged: move the pin of open-abap-core, delete `atdf/` and the
import of `atdf_runtime.mjs` in `setup.mjs`, and remove the `transpiler/atdf` and
`abaplint-stubs` libraries from `abap_transpile.json` (open-abap-core then ships every object
in `abaplint-stubs/`; abaplint keeps reading the folder). Then run the tests.

## Runtime patches in `setup.mjs`

| Patch | Gap |
|---|---|
| `distance( )` built-in | not implemented in @abaplint/runtime |
| `IS INSTANCE OF <interface>` | the runtime uses a JavaScript `instanceof`, false for every interface |
| `LIF_ROLE` enum members get distinct values | the transpiler emits every `ENUM` member as an integer with no value, and references members of a local interface under a name it never defines. **Keep the member list in `setup.mjs` in sync with `LIF_ROLE` in `zcl_atk.clas.locals_imp.abap`.** |

## Skipped tests

Listed under `options.skip` in `abap_transpile.json`; it runs on a real system.

- `ZCL_ATK LTC_PARAMETER_SHAPES->GIVEN_GENERIC_DIGITS_WORKS`: a generic `n` parameter is emitted
  like `N LENGTH 1`, so the ATDF stand-in cuts the value.

## Known gaps worth reporting upstream

1. `@abaplint/transpiler`: `TYPES BEGIN OF ENUM` members all get the initial value; members of
   an enum in a local interface are emitted as `lif_x.lif_x$member` but referenced as `lif_x.member`.
2. `@abaplint/transpiler`: `CALL METHOD var->(name)` does not escape a variable named like a
   JavaScript reserved word (`double` became `double.get()` while the parameter is `$double`).
   ATK renamed the private parameter to `atdf_double` to work around it.
3. `@abaplint/runtime`: `distance( )` and `IS INSTANCE OF` an interface.
