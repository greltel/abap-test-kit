# Changelog

All notable changes to this repository are listed here. Versions follow
[Semantic Versioning](https://semver.org); how a release is made is described in
[CONTRIBUTING.md](CONTRIBUTING.md#releasing).

## Unreleased

### Changed

- README: section *The same mistake, both messages* - three mistakes made with
  `CL_ABAP_TESTDOUBLE` and with the library, with the texts ABAP Unit shows for each.

## [1.1.0] - 2026-09-27

### Added

- Every recorded call carries the method of the code under test that made it and the
  line within that method, read from the XCO call stack while the double answers
  (`from ZCL_ORDER_SERVICE=>ZIF_ORDER_SERVICE~CANCEL, line 6 of the method`). A failure
  at the call - an unmatched or unwanted call, a dummy that is called - has it as the fact
  `Called from:`; the matching and closest calls of a spy or mock failure show it after
  their arguments.

### Changed

- **Breaking:** every step of a spy check checks on its own. `was_called( )` fails the test
  at once unless the method was called at least once, each `with( )` fails unless a recorded
  call has the arguments named so far, and `times( n )` needs `n` of 1 or more - `times( 0 )`
  is rejected, `was_not_called( )` is the check for a method that must not be called. Before,
  a check without `times( )` checked nothing. New problems `no_call_recorded` (027/124) and
  `no_matching_call` (028/125); `negative_expected_calls` (016/113) is gone, `times( )` of a
  spy and of a mock both raise `invalid_expected_calls`.
- A failure reported to ABAP Unit has what went wrong as its message and the fix and the
  facts as its detail, so the failure list stays readable and the rest shows under it
  (Analysis in the SAP GUI, Details in ADT). `zcx_atk->get_text( )` is unchanged.
- The facts about a value that does not fit name the type of the value and what the
  parameter would hold instead as labeled sentences (`The value has the type:`,
  `Instead, the parameter would hold:`), so long type names are no longer cut at the
  50 characters of a message placeholder.
- The failure of `was_called( )` on a method that was never called names the other methods
  the double received calls for, with their counts, or says that the double received no
  call at all. The arguments of a call of a method without inputs read `none`, not `any`.
- 168 unit tests.

### Fixed

- A `with( )` condition on an optional parameter the caller left out is never met, not even
  with an initial value: the method may have seen its `DEFAULT`, which the double cannot know.
- A call goes to an expectation that still waits for a call before a more specific one that got
  all its calls, as documented; the failure of an unmet expectation lists the calls that
  expectation answered, not the calls a twin expectation took.
- Parameters typed with the generic `c`, `n`, `p` or `x` accept values of any length; before,
  `CREATE DATA` silently gave them the standard length and every longer value was refused.
- A table value in another row order than the sorted table type of the parameter is accepted.
- A condition on a generic parameter also matches when the value of the call fits the type of
  the condition the other way round (`'4711'` against a numeric text).
- A method named with the prefix of the doubled interface itself (`'ZIF_ORDERS~GET_ORDER'`),
  or by an alias declared in the interface, is found.
- A failure to read the call stack no longer fails the call; the origin is left out.
- An enumerated value is only compared with a value of its own type.
- Fix texts for `with( )`, `sets( )` and `returns( )` name the right alternative, and an
  interface without instance methods lists `none` instead of nothing.
- The unit tests of `ZCL_ATK` no longer depend on the demo package.

## [1.0.0] - 2026-09-26

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
- `ZCX_ATK` and message class `ZATK`: every text has three parts, in this order - what
  went wrong, how to fix it, and the facts: the actual arguments, the rules or expectations
  of the method and where the closest one differs, the matching or closest calls, what a
  value that does not fit would become, the parameters or outputs a method has, the
  exceptions it declares. An optional parameter the caller left out is shown as
  `(not supplied)`.
- 133 unit tests against the real `CL_ABAP_TESTDOUBLE`, and package `ZATK_DEMO` with the same
  scenarios tested with the classic framework and with the library.
- abaplint in ABAP Cloud mode and the unit tests off-stack (abaplint transpiler,
  open-abap-core) on every push.
