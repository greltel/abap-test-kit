# Changelog

All notable changes to this repository are listed here. Versions follow
[Semantic Versioning](https://semver.org); how a release is made is described in
[CONTRIBUTING.md](CONTRIBUTING.md#releasing).

## Unreleased

### Added

Test doubles on top of `CL_ABAP_TESTDOUBLE`.

- `ZCL_ATK` with `dummy( )`, `stub( )`, `spy( )` and `mock( )` for global interfaces and
  global classes that are not final.
- Rules with `when( )`, `with( )`, `returns( )`, `sets( )` and `raises( )`; the most specific
  rule wins, and a call that matches no rule of a method fails the test.
- Spy checks with `was_called( )->with( )->times( )` and `was_not_called( )`, after the act
  step.
- Mock expectations with `expect_call( )->times( )` and `verify( )`.
- Method names, parameter names and values checked with RTTI, with suggestions for
  misspelled names; values converted without loss.
- `ZCX_ATK` and message class `ZATK`: every problem says what went wrong and how to fix it.
- Unit tests against the real `CL_ABAP_TESTDOUBLE`, and package `ZATK_DEMO` with the same
  scenarios tested with the classic framework and with the library.
- abaplint in ABAP Cloud mode on every push.
