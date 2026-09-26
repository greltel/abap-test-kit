# Changelog

All notable changes to this repository are listed here. Versions follow
[Semantic Versioning](https://semver.org); how a release is made is described in
[CONTRIBUTING.md](CONTRIBUTING.md#releasing).

## Unreleased

Content of the coming `1.0.0` release.

### Added

Test doubles on top of `CL_ABAP_TESTDOUBLE`.

- `ZCL_ATK` with `dummy( )`, `stub( )`, `spy( )` and `mock( )` for global interfaces. Classes
  are rejected with a message that points to an interface or to `CL_ABAP_TESTDOUBLE`.
- Rules with `when( )`, `with( )`, `returns( )`, `sets( )` and `raises( )`; the most specific
  rule wins, and a call that matches no rule of a method fails the test.
- Spy checks with `was_called( )->with( )->times( )` and `was_not_called( )`, after the act
  step.
- Mock expectations with `expect_call( )->times( )` and `verify( )`. Two expectations for the
  same method are two calls: a call goes to the most specific expectation that still waits for
  a call.
- Methods of component interfaces (`INTERFACES` inside the doubled interface), named with or
  without their interface prefix.
- Method names, parameter names and values checked with RTTI, with suggestions for
  misspelled names; values converted without loss.
- `ZCX_ATK` and message class `ZATK`: every text has three parts on their own lines - what
  went wrong, how to fix it, and the facts: the actual arguments, the rules or expectations
  of the method and where the closest one differs, the matching or closest calls, what a
  value that does not fit would become, the parameters or outputs a method has, the
  exceptions it declares. An optional parameter the caller left out is shown as
  `(not supplied)`.
- 133 unit tests against the real `CL_ABAP_TESTDOUBLE`, and package `ZATK_DEMO` with the same
  scenarios tested with the classic framework and with the library.
- abaplint in ABAP Cloud mode and the unit tests off-stack (abaplint transpiler,
  open-abap-core) on every push.
