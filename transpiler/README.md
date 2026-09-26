# Off-stack unit tests

The ABAP Unit tests of the ABAP Test Kit run without an SAP system: the sources are
transpiled to JavaScript with the [abaplint transpiler](https://github.com/abaplint/transpiler)
and executed on Node.js against [open-abap-core](https://github.com/open-abap/open-abap-core),
the open-source implementation of the SAP standard classes.

```
npm ci            # toolchain: @abaplint/cli, @abaplint/transpiler-cli, @abaplint/runtime
npm run lint      # abaplint, ABAP Cloud rules (abaplint.json)
npm test          # fetch open-abap-core, transpile, run every ABAP Unit test
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
| `fetch_open_abap_core.mjs` | Fetches open-abap-core into `deps/` at a pinned commit |
| `run_unit_tests.mjs` | Test runner with a readable report and exit code 1 on failure |
| `setup.mjs` | Runtime patches applied before (`setup`) and after (`afterLoad`) the ABAP objects load |
| `atdf/cl_abap_testdouble.clas.abap` | CL_ABAP_TESTDOUBLE for the transpiler; delegates to `atdf/atdf_runtime.mjs` |
| `atdf/atdf_runtime.mjs` | JavaScript stand-in for the ABAP Test Double Framework |
| `xco/` | Stand-ins for the XCO classes ATK reads the call stack with (`xco_cp`, `xco_cp_call_stack` and what their chain returns); open-abap-core has no XCO. Off-stack the stack has no lines, so a call has no origin |
| `open-abap-patches/` | Patched copies of open-abap-core classes (the originals are excluded in `abap_transpile.json`) |

The `IF_ABAP_TESTDOUBLE_*` interfaces and `CX_ATD_EXCEPTION_CORE` come from `/abaplint-stubs/`,
which the transpiler reads too; only `CL_ABAP_TESTDOUBLE` and the ABAP Unit classes are excluded
from there, because they need behaviour.

## Why a stand-in for the ATDF

open-abap-core does not ship `CL_ABAP_TESTDOUBLE`, and it cannot be written in ABAP: it has to
build an object that implements an arbitrary interface at runtime. `atdf_runtime.mjs` builds
that object as a JavaScript class from the interface metadata the transpiler emits
(`abap.Classes[<INTERFACE>].METHODS`). It implements what ATK and the demo tests use:

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

## Patched open-abap-core classes

Each file in `open-abap-patches/` is the upstream file with a marked change. They were taken
from the commit pinned in `fetch_open_abap_core.mjs`; when moving the pin, diff each one
against its new upstream version.

| Class | Change | Needed by |
|---|---|---|
| `cl_abap_typedescr` | constant `typekind_xsequence`; `describe_by_name` resolves `\CLASS=X\TYPE=Y` and `\INTERFACE=X\TYPE=Y` | `lcl_doubled_method`, `lcl_doubled_type` |
| `cl_abap_datadescr` | `applies_to_data` implemented (upstream: todo) | `lcl_value_conversion` for structures |
| `cl_abap_objectdescr` | generic parameter types `ANY`, `DATA`, `SIMPLE` are generic descriptions, not `C LENGTH 4` | rules on generic parameters |
| `cl_abap_classdescr` | `get_super_class_type` implemented (upstream: todo) | `check_declares`, the `CX_NO_CHECK` walk |
| `kernel_create_data_handle` | `REF TO <interface>` handles; every generic handle raises `cx_sy_create_data_error` | doubles returning doubles, generic parameters |

## Runtime patches in `setup.mjs`

| Patch | Gap |
|---|---|
| `distance( )` built-in | not implemented in @abaplint/runtime |
| `numc = decfloat34` (also `p`, `f`) compares numerically | the runtime compares the strings `0000004711` and `4711` |
| `IS INSTANCE OF <interface>` | the runtime uses a JavaScript `instanceof`, false for every interface |
| `LIF_ROLE` enum members get distinct values | the transpiler emits every `ENUM` member as an integer with no value, and references members of a local interface under a name it never defines. **Keep the member list in `setup.mjs` in sync with `LIF_ROLE` in `zcl_atk.clas.locals_imp.abap`.** |
| `IMPLEMENTED_INTERFACES` of interfaces that include interfaces | the transpiler emits an interface with `INTERFACES` inside without its components, so open-abap's RTTI lists no component interfaces and the ATDF stand-in cannot build their methods. **Keep the list `INTERFACE_COMPONENTS` in `setup.mjs` in sync with the fixtures in `src/test/`.** The stand-in then implements the component methods too and reports them to the answer as `ZIF_COMPONENT~METHOD`, which is what ATK expects from the real framework - verify on a system when `ltc_component_interface` fails there. |

## Skipped tests

Listed under `options.skip` in `abap_transpile.json`; all of them run on a real system.

- `ZCL_ATK LTC_STUB->WHEN_RAISES_THEN_CALLER_GETS` and
  `ZCL_ATK_DEMO_ORDER_SERVICE LTC_WITH_ATK->GIVEN_UNKNOWN_ORDER_THEN_RAISE` need the `RAISING`
  clause of a method from RTTI (`cl_abap_objectdescr->methods[]-exceptions`). The transpiler
  does not emit that metadata (`buildMethods` in `@abaplint/transpiler` writes parameters
  only), so open-abap-core cannot fill it. Until it does, only `CX_NO_CHECK` exceptions pass
  `check_declares` off-stack; the other tests of `raises( )` use `ZCX_ATK` for that reason.
- `ZCL_ATK LTC_DOUBLED_TYPE->GIVEN_STATIC_METHOD_IGNORED` needs `methods[]-is_class`, which
  the transpiler does not emit either.
- `ZCL_ATK LTC_SPY->WHEN_UNWANTED_NAMES_CALLER`, `ZCL_ATK LTC_STUB->WHEN_UNMATCHED_NAMES_CALLER` and
  `ZCL_ATK LTC_CALL_SITE->WHEN_ASKED_THEN_NAMES_CALLER` read the real call stack through XCO; the
  stand-in in `xco/` returns no frames. The rest of `ltc_call_site` runs off-stack on recorded
  stack lines.
- `ZCL_ATK LTC_PARAMETER_SHAPES->GIVEN_OPTIONAL_LEFT_OUT_FAILS` needs
  `parameters[]-is_optional`. The transpiler emits `is_optional` for every parameter as blank:
  `buildMethods` compares the parameter name in its original case with the upper-case names
  of `getOptional( )`. And open-abap-core's `cl_abap_objectdescr` does not copy the flag
  into `methods[]-parameters[]` anyway.

## Known gaps worth reporting upstream

1. `@abaplint/transpiler`: `TYPES BEGIN OF ENUM` members all get the initial value; members of
   an enum in a local interface are emitted as `lif_x.lif_x$member` but referenced as `lif_x.member`.
2. `@abaplint/transpiler`: `CALL METHOD var->(name)` does not escape a variable named like a
   JavaScript reserved word (`double` became `double.get()` while the parameter is `$double`).
   ATK renamed the private parameter to `atdf_double` to work around it.
3. `@abaplint/transpiler`: method metadata has no `RAISING` list and no static flag, and
   `is_optional` is always blank (see skipped tests).
4. `@abaplint/transpiler`: an interface with `INTERFACES` inside is emitted without
   `IMPLEMENTED_INTERFACES` (see the runtime patches).
5. `@abaplint/runtime`: `distance( )`, `numc` vs decimal comparisons, `IS INSTANCE OF` interface.
6. `open-abap-core`: the five patched classes above; `cl_abap_objectdescr` does not fill
   `is_optional` and `is_class` of methods and parameters.
