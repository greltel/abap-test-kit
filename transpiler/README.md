# Off-stack unit tests

The ABAP Unit tests of the ABAP Test Kit run without an SAP system: the sources are
transpiled to JavaScript with the [abaplint transpiler](https://github.com/abaplint/transpiler)
and executed on Node.js against [open-abap-core](https://github.com/open-abap/open-abap-core),
the open-source implementation of the SAP standard classes, including `CL_ABAP_TESTDOUBLE`, and
[open-abap-xco](https://github.com/open-abap/open-abap-xco) for the XCO call stack.

```
npm ci            # toolchain: @abaplint/cli, @abaplint/transpiler-cli, @abaplint/runtime
npm run lint      # fetch open-abap-core and open-abap-xco, abaplint with ABAP Cloud rules
npm test          # fetch, transpile, run every ABAP Unit test
npm run unit      # run again without transpiling
npm run unit:verbose
node transpiler/run_unit_tests.mjs --filter LTC_STUB --verbose
```

CI: `.github/workflows/abaplint.yml` and `.github/workflows/unit.yml`. Everything here is
tooling; abapGit never imports it (its starting folder is `/src/`) and abaplint never lints it
(`abaplint.json` reads `/src/`).

## Files

| File | Purpose |
|---|---|
| `abap_transpile.json` (root) | Transpiler configuration: sources and libraries |
| `fetch_open_abap_core.mjs` | Fetches open-abap-core and open-abap-xco into `deps/`, each at a pinned commit; `npm run lint` and `npm test` run it first |
| `run_unit_tests.mjs` | Test runner: runs every test, prints the ABAP exception text of a failure, exits with 1 if any test failed. The generated `output/index.mjs` runs the tests too, but stops at the first failure |

## Dependencies

Both the transpiler and abaplint read open-abap-core at the commit pinned in
`fetch_open_abap_core.mjs`:

- the transpiler runs the tests against its classes, `CL_ABAP_TESTDOUBLE` (since
  open-abap/open-abap-core#1296) and `CL_ABAP_UNIT_ASSERT` among them;
- abaplint (`abaplint.json`) takes the signatures of the test double framework and of ABAP Unit
  from it, next to [abaplint/deps](https://github.com/abaplint/deps), which has neither. Without
  `deps/` (the abaplint app on pull requests) abaplint clones the current open-abap-core instead.

`@abaplint/runtime` and `@abaplint/transpiler-cli` must be 2.14.3 or later: that release covers
everything ATK needs, so there are no runtime patches - `distance( )` (abaplint/transpiler#1982),
`IS INSTANCE OF` an interface (#1979), distinct values of an `ENUM` without `STRUCTURE` (#1983),
constants of a local interface used from another include (#1984), and a unit test runner that
skips `FOR TESTING` helper classes (#1981).

To move to a newer open-abap-core or open-abap-xco: change the commit in
`fetch_open_abap_core.mjs` and run `npm run ci`.

## Skipped tests

None. A test that cannot run off-stack goes under `options.skip` in `abap_transpile.json`, with
the reason here; it still has to pass on a real system.

## Known gaps worth reporting upstream

- `@abaplint/transpiler`: `CALL METHOD var->(name)` does not escape a variable named like a
  JavaScript reserved word (`double` becomes `double.get()` while the parameter is `$double`;
  still the case in 2.14.3). ATK named the private parameter `atdf_double` to work around it.
