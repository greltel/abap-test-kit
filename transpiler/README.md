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
| `abap_transpile.json` (root) | Transpiler configuration: sources, libraries, setup hook, skipped tests |
| `fetch_open_abap_core.mjs` | Fetches open-abap-core and open-abap-xco into `deps/`, each at a pinned commit |
| `run_unit_tests.mjs` | Test runner with a readable report and exit code 1 on failure |
| `setup.mjs` | Loads `atdf/atdf_runtime.mjs` into `globalThis.atdfRuntime` before the ABAP objects load |
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

Once the pull request is merged: move the pin of open-abap-core, delete `atdf/` and `setup.mjs`,
remove `options.setup` and the `transpiler/atdf` and `abaplint-stubs` libraries from
`abap_transpile.json` (open-abap-core then ships every object in `abaplint-stubs/`; abaplint keeps
reading the folder), and remove the skipped test below. Then run the tests.

## No runtime patches

Since @abaplint/transpiler 2.14.3 the transpiler and its runtime cover everything ATK needs:
`distance( )` (abaplint/transpiler#1982), `IS INSTANCE OF` an interface (#1979), distinct values
of an `ENUM` without `STRUCTURE` (#1983), constants of a local interface used from another include
(#1984), and a unit test runner that skips `FOR TESTING` helper classes (#1981). Keep
`@abaplint/runtime` and `@abaplint/transpiler-cli` at 2.14.3 or later.

## Skipped tests

Listed under `options.skip` in `abap_transpile.json`; it runs on a real system.

- `ZCL_ATK LTC_PARAMETER_SHAPES->GIVEN_GENERIC_DIGITS_WORKS`: a generic `n` parameter is emitted
  like `N LENGTH 1`, so the ATDF stand-in cuts the value.

## Known gaps worth reporting upstream

- `@abaplint/transpiler`: `CALL METHOD var->(name)` does not escape a variable named like a
  JavaScript reserved word (`double` becomes `double.get()` while the parameter is `$double`;
  still the case in 2.14.3). ATK named the private parameter `atdf_double` to work around it.
