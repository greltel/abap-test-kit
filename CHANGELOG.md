# Changelog

## 0.1.0 - unreleased

Phase 1: test doubles over `CL_ABAP_TESTDOUBLE`.

- `ZCL_ATK` with `dummy( )`, `stub( )`, `spy( )` and `mock( )` for global interfaces and
  non-final global classes.
- Rules with `when( )`, `with( )`, `returns( )`, `sets( )` and `raises( )`; the most specific
  rule wins, and a call that matches no rule of a method fails the test.
- Spy checks with `was_called( )->with( )->times( )` and `was_not_called( )`, after the act
  step.
- Mock expectations with `expect_call( )->times( )` and `verify( )`.
- Names checked with RTTI and suggestions for misspellings; values converted without loss.
- `ZCX_ATK` and message class `ZATK`: every problem says what went wrong and how to fix it.
- Own ABAP Unit tests (on the real ATDF) and a before/after demo package.
- abaplint in ABAP Cloud mode in CI.
