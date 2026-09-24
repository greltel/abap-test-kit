# ABAP Test Kit
[![ABAP Cloud](https://img.shields.io/badge/ABAP-Cloud%20Ready-green)](https://abaplint.app/stats/greltel/abap-test-kit/object_classifications)
[![ABAP Version](https://img.shields.io/badge/ABAP-7.58%2B-blue)](https://abaplint.app/stats/greltel/abap-test-kit/statement_compatibility)
[![Code Statistics](https://img.shields.io/badge/CodeStatistics-abaplint-blue)](https://abaplint.app/stats/greltel/abap-test-kit)
[![License](https://img.shields.io/badge/License-MIT-green)](https://github.com/greltel/abap-test-kit/blob/main/LICENSE)
[![Release](https://img.shields.io/github/v/release/greltel/abap-test-kit?label=release)](https://github.com/greltel/abap-test-kit/releases)
[![abaplint](https://github.com/greltel/abap-test-kit/actions/workflows/abaplint.yml/badge.svg)](https://github.com/greltel/abap-test-kit/actions/workflows/abaplint.yml)
# Table of contents

1. [ABAP Test Kit](#abap-test-kit)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Versioning](#versioning)
5. [License](#license)
6. [Contributors-Developers](#contributors-developers)
7. [Available Test Doubles](#available-test-doubles)
8. [Before and After](#before-and-after)
9. [Design Goals-Features](#design-goals-features)
10. [To-Do](#to-do)

# ABAP Test Kit

A small library that makes ABAP Unit tests with test doubles shorter and easier to read, for
development on SAP S/4HANA and SAP BTP ABAP Environment.

It is built on top of SAP's ABAP Test Double Framework (`CL_ABAP_TESTDOUBLE`): the framework
still creates the doubles and intercepts the calls, the library adds a fluent API to configure
and check them, and messages that say what went wrong and how to fix it. It is meant both for
developers who write their first unit test and for those who want their tests shorter and more
descriptive.

The library is written against the **ABAP for Cloud Development** language version, follows
**Clean Core** principles, and consumes **released APIs only**.

# Prerequisites

* SAP S/4HANA 2023 (or higher) OR SAP BTP ABAP Environment
* ABAP language version: ABAP for Cloud Development
* ABAP Test Double Framework (`CL_ABAP_TESTDOUBLE`)
* Statement compatibility from v758 and Cloud

# Installation

Install via [abapGit](https://abapgit.org) into a package flagged as
**ABAP Cloud** in the customer namespace, e.g. `ZATK`. abapGit creates two
sub-packages next to the library:

| Package | Content |
|---|---|
| `ZATK` | The library: `ZCL_ATK`, the `ZIF_ATK_*` interfaces, `ZCX_ATK` and message class `ZATK` |
| `ZATK_TEST` | Fixtures for the unit tests of the library |
| `ZATK_DEMO` | A small order service, tested once with the classic framework and once with the library |

After the pull, run the unit tests of the package; all of them should pass.
`ZCL_ATK` is a test class (`FOR TESTING`), so only test code can use it.

# Versioning

Releases are tagged `vMAJOR.MINOR.PATCH` and listed in
[CHANGELOG.md](CHANGELOG.md), which also carries the changes on `main` that are
not released yet under **Unreleased**. One version covers the whole
repository: in abapGit open the repository, choose *Switch tag* and pick the
release; *Switch branch* to `main` follows the latest state. The rules for what
bumps which part of the version are in [CONTRIBUTING.md](CONTRIBUTING.md#releasing).

# License

This project is licensed under the [MIT License](https://github.com/greltel/abap-test-kit/blob/main/LICENSE).

# Contributors-Developers

The repository was created by [George Drakos](https://www.linkedin.com/in/george-drakos/).

# Available Test Doubles

Object names follow `ZCL_ATK` / `ZIF_ATK_*` / `ZCX_ATK`.

| Double | Entry point | Interface | Description |
|---|---|---|---|
| [Dummy](#dummy) | `zcl_atk=>dummy( )` | `ZIF_ATK_DUMMY` | Fills a parameter of the code under test that the scenario never uses; any call fails the test |
| [Stub](#stub) | `zcl_atk=>stub( )` | `ZIF_ATK_STUB` | Answers calls with the values, output parameters or exceptions the test defines |
| [Spy](#spy) | `zcl_atk=>spy( )` | `ZIF_ATK_SPY` | A stub that records every call, so the test checks the calls after the act step |
| [Mock](#mock) | `zcl_atk=>mock( )` | `ZIF_ATK_MOCK` | Strict double: every call is declared up front, any other call fails at once |

Every double follows the same shape: `ZCL_ATK` is the only entry point and takes
the name of a global interface, or of a global class that is not final, not
`CREATE PRIVATE` and has no mandatory constructor parameters. Public instance
methods that are not final can be configured; static, final and private
methods cannot be doubled by the test double framework. `instance( )`
hands out the object that is injected into the code under test. Rules and
checks are fluent interfaces, method names, parameter names and values are
checked against the doubled type while the test is set up, and errors surface
through one exception class, `ZCX_ATK`.

## Dummy

The code under test needs the collaborator, for example as a constructor
parameter, but the scenario never calls it. Any call fails the test and names
the method that was called.

| Interface | Purpose |
|---|---|
| `ZIF_ATK_DUMMY` | `instance( )` |

```abap
DATA(unused_log) = zcl_atk=>dummy( 'ZIF_AUDIT_LOG' ).

cut = NEW zcl_order_service( repository = CAST #( repository->instance( ) )
                             audit_log  = CAST #( unused_log->instance( ) ) ).
```

## Stub

Answers the questions of the code under test. `when( )` starts a rule for one
method, `with( )` narrows it to an argument value, and `returns( )`, `sets( )`
or `raises( )` define the answer; `sets( )` covers EXPORTING and CHANGING
parameters alike. Parameters without `with( )` match any value. When several
rules match a call, the one with the most `with( )` conditions wins, on a tie
the one written last. Once a method has rules, a call that matches none of them
fails the test; a method without rules returns initial values. Values are
converted to the type of the parameter without loss: `'4711'` for a numeric
text becomes `0000004711`, while `'47A1'`, a text longer than the parameter or
decimals that would be rounded are rejected. `raises( )` accepts only exceptions
the method declares, or `CX_NO_CHECK` ones.

| Interface | Purpose |
|---|---|
| `ZIF_ATK_STUB` | `instance( )`, `when( )` |
| `ZIF_ATK_CALL_RULE` | Fluent: `with( )`, `returns( )`, `sets( )`, `raises( )` |

```abap
DATA(repository) = zcl_atk=>stub( 'ZIF_ORDER_REPOSITORY' ).

repository->when( 'GET_ORDER' )->with( parameter = 'ORDER_ID' value = '4711' )->returns( open_order ).
repository->when( 'GET_ORDER' )->returns( unknown_order ).

repository->when( 'READ_TOTALS' )->sets( parameter = 'NET' value = 100 )->sets( parameter = 'TAX' value = 24 ).

repository->when( 'GET_ORDER' )->with( parameter = 'ORDER_ID' value = '0000' )->raises( NEW zcx_order_not_found( ) ).
```

## Spy

A stub that also records every call. The test checks the calls after the act
step with `was_called( )`, narrows the check with `with( )` and closes it with
`times( )`, which performs the check - `times( 0 )` and `was_not_called( )`
both check that no matching call happened. A failed check shows the expected
arguments, the closest actual call and the parameters that differ.

| Interface | Purpose |
|---|---|
| `ZIF_ATK_SPY` | `instance( )`, `when( )`, `was_called( )`, `was_not_called( )` |
| `ZIF_ATK_CALL_VERIFICATION` | Fluent: `with( )`, closed with `times( )` |

```abap
DATA(audit_log) = zcl_atk=>spy( 'ZIF_AUDIT_LOG' ).

cut->cancel( '4711' ).

audit_log->was_called( 'WRITE'
  )->with( parameter = 'ORDER_ID' value = '4711'
  )->with( parameter = 'ACTION' value = `CANCELLED`
  )->times( 1 ).

audit_log->was_not_called( 'DELETE' ).
```

```text
WRITE: expected 1 matching call(s), but found 0. Check the code under test, or adjust with( )
and times( ). Expected arguments: ACTION = 'CANCELLED', ORDER_ID = '0000004711'. Closest actual
call: ACTION = 'CANCELED', ORDER_ID = '0000004711'. Differs in: ACTION.
```

## Mock

A strict double for scenarios where any unplanned call is a bug. Every expected
call is declared with `expect_call( )` before the act step; a call that was not
declared fails the test at once, and `verify( )` reports declared calls that did
not happen as often as declared. Without `times( )` an expectation expects
exactly one call, and it can answer like a stub rule.

| Interface | Purpose |
|---|---|
| `ZIF_ATK_MOCK` | `instance( )`, `expect_call( )`, `verify( )` |
| `ZIF_ATK_CALL_EXPECTATION` | Fluent: `with( )`, `times( )`, `returns( )`, `sets( )`, `raises( )` |

```abap
DATA(audit_log) = zcl_atk=>mock( 'ZIF_AUDIT_LOG' ).
audit_log->expect_call( 'WRITE' )->with( parameter = 'ACTION' value = `CANCELLED` ).

cut->cancel( '4711' ).

audit_log->verify( ).
```

## Error messages

Every mistake in a test surfaces through `ZCX_ATK`, whose text says what went
wrong, how to fix it and, where it helps, the arguments involved. Close
misspellings of method and parameter names get a suggestion. The texts live in
message class `ZATK`; exceptions of the test double framework never reach the
test untranslated. Failures during the act step are recorded without stopping
the code under test, so a `CATCH cx_root` in the code under test cannot hide
them.

```text
ZCL_ORDER_SERVICE is a final class, so no double can extend it. Extract an interface from
ZCL_ORDER_SERVICE and let the code depend on it.
```

# Before and After

Package `ZATK_DEMO` holds a small order service, `ZCL_ATK_DEMO_ORDER_SERVICE`:
it reads an order from a repository and, when it cancels an open order, writes
the cancellation to an audit log. Both collaborators are injected through the
constructor. Its test include tests the same scenarios twice, in
`ltc_with_raw_atdf` with the classic ABAP Test Double Framework and in
`ltc_with_atk` with the library; the examples below are taken from there.

```abap
" Before
repository = CAST zif_atk_demo_order_repo( cl_abap_testdouble=>create( 'ZIF_ATK_DEMO_ORDER_REPO' ) ).
audit_log  = CAST zif_atk_demo_audit_log( cl_abap_testdouble=>create( 'ZIF_ATK_DEMO_AUDIT_LOG' ) ).
cut = NEW zcl_atk_demo_order_service( repository = repository
                                      audit_log  = audit_log ).
```

```abap
" After
repository = zcl_atk=>stub( 'ZIF_ATK_DEMO_ORDER_REPO' ).
audit_log  = zcl_atk=>spy( 'ZIF_ATK_DEMO_AUDIT_LOG' ).
cut = NEW zcl_atk_demo_order_service( repository = CAST #( repository->instance( ) )
                                      audit_log  = CAST #( audit_log->instance( ) ) ).
```

## Return a value for a specific argument

```abap
" Before
cl_abap_testdouble=>configure_call( repository )->returning( lth_orders=>cancelled_order( ) ).
repository->get_order( '4711' ).

DATA(is_cancelled) = cut->is_cancelled( '4711' ).

cl_abap_unit_assert=>assert_true( act = is_cancelled msg = `A cancelled order must be reported as cancelled` ).
```

```abap
" After
repository->when( 'GET_ORDER' )->with( parameter = 'ORDER_ID' value = '4711' )->returns( lth_orders=>cancelled_order( ) ).

DATA(is_cancelled) = cut->is_cancelled( '4711' ).

cl_abap_unit_assert=>assert_true( act = is_cancelled msg = `A cancelled order must be reported as cancelled` ).
```

The configuration is one statement, and the second line of the classic version -
a call that only records its arguments - is gone.

## Raise an exception

```abap
" Before
cl_abap_testdouble=>configure_call( repository )->raise_exception( NEW zcx_atk_demo_not_found( ) ).
repository->get_order( '4711' ).
```

```abap
" After
repository->when( 'GET_ORDER' )->raises( NEW zcx_atk_demo_not_found( ) ).
```

The recording call of the classic version declares `RAISING zcx_atk_demo_not_found`,
so the test method needs a `RAISING` clause for a line that never raises. The
library also checks that `GET_ORDER` declares the exception.

## Check that a method was called once, with the right arguments

```abap
" Before
cl_abap_testdouble=>configure_call( repository )->returning( lth_orders=>open_order( ) ).
repository->get_order( '4711' ).
cl_abap_testdouble=>configure_call( audit_log )->and_expect( )->is_called_times( 1 ).
audit_log->write( order_id = '4711'
                  action   = zif_atk_demo_audit_log=>action-cancelled ).

cut->cancel( '4711' ).

cl_abap_testdouble=>verify_expectations( audit_log ).
```

```abap
" After
repository->when( 'GET_ORDER' )->returns( lth_orders=>open_order( ) ).

cut->cancel( '4711' ).

audit_log->was_called( 'WRITE'
  )->with( parameter = 'ORDER_ID' value = '4711'
  )->with( parameter = 'ACTION' value = zif_atk_demo_audit_log=>action-cancelled
  )->times( 1 ).
```

Five statements become two, and the check is written after the act step
instead of before it. When it fails, the message shows the closest actual call
(see [Spy](#spy)).

## Check that a method was not called

```abap
" Before
cl_abap_testdouble=>configure_call( repository )->returning( lth_orders=>cancelled_order( ) ).
repository->get_order( '4711' ).
cl_abap_testdouble=>configure_call( audit_log )->ignore_all_parameters( )->and_expect( )->is_never_called( ).
audit_log->write( order_id = '4711'
                  action   = `` ).

cut->cancel( '4711' ).

cl_abap_testdouble=>verify_expectations( audit_log ).
```

```abap
" After
repository->when( 'GET_ORDER' )->returns( lth_orders=>cancelled_order( ) ).

cut->cancel( '4711' ).

audit_log->was_not_called( 'WRITE' ).
```

No placeholder arguments for a call that must not happen, and no
`ignore_all_parameters( )` or `verify_expectations( )`.

## Every call declared up front

The classic framework has no strict mode: a call without a matching
configuration returns initial values. With the library, a mock fails the test
at the undeclared call:

```abap
" After
DATA(strict_log) = zcl_atk=>mock( 'ZIF_ATK_DEMO_AUDIT_LOG' ).
strict_log->expect_call( 'WRITE' )->with( parameter = 'ACTION' value = zif_atk_demo_audit_log=>action-cancelled ).

service->cancel( '4711' ).

strict_log->verify( ).
```

## A call with arguments no rule matches

The configuration is for order `4711`, but the code under test asks for `0815`.
The classic framework finds no matching configuration and returns an initial
order, and the test fails later, if at all. A stub with rules for `GET_ORDER`
fails the test at the call:

```text
GET_ORDER was called with arguments that match none of its rules. Add a rule for these
arguments, or check the code under test. Actual arguments: ORDER_ID = '0000000815'.
```

## Summary

In the four scenarios that exist in both test classes, the doubles need 6
statements instead of 14, and none of them is a call that only records
arguments. One difference to keep in mind: method and parameter names are
strings. The classic framework catches a misspelled name at activation, the
library the first time the test runs, with a suggestion for the closest name.

# Design Goals-Features

* ABAP Cloud / Clean Core compatibility — passes the ATC variant `ABAP_CLOUD_DEVELOPMENT_DEFAULT`
* Released APIs only (release contract C1), no dependencies besides SAP's own classes
* Built on `CL_ABAP_TESTDOUBLE` — no own mocking engine; both can be used in the same test class
* Tests in arrange-act-assert order: spies are checked after the act step
* Messages that say what went wrong and how to fix it; framework exceptions never reach the test untranslated
* Method names, parameter names and values checked against the doubled type with RTTI
* Small public surface: one facade class, fluent interfaces and one exception class; everything else is local to `ZCL_ATK`
* Test code only — `ZCL_ATK` is `FOR TESTING`, so production code cannot depend on it
* Clean Code following the [Clean ABAP Style Guides](https://github.com/SAP/styleguides/blob/main/clean-abap/CleanABAP.md)
* Modern ABAP syntax (7.58 / 9.14) — expressions, inline declarations, string templates
* Unit tested with ABAP Unit against the real `CL_ABAP_TESTDOUBLE`, checked with abaplint on every push
* Documented with ABAP Doc on every public declaration

# To-Do

Work planned for the next releases, in the order it will be built. What is
already on `main` but not yet released is listed under **Unreleased** in
[CHANGELOG.md](CHANGELOG.md).

## Next phases

1. **Assertions** — `zcl_atk=>expect( actual )->to_equal( expected )` on top of
   `CL_ABAP_UNIT_ASSERT`, with matchers for tables, structures and exceptions,
   and failure messages that always show the expected and the actual value
2. **Testability analyzer** — an ATC check or abaplint rules that explain why a
   class is hard to test (`SELECT` in a method, `NEW` of dependencies, static
   calls, function modules) and how to fix each finding; it will also check the
   method and parameter names in tests that use the library
3. **Koans** — red-to-green exercises built on the test doubles and the
   assertions

## Improvements to the test doubles

- **Consecutive answers** — a different answer for the first, second and
  following calls of a method
- **Matchers for `with( )`** — conditions such as "any text containing" instead
  of equality
- **Events** — raise the events of a doubled type
- **Generic sorted and hashed tables** — mandatory parameters typed
  `SORTED TABLE` or `HASHED TABLE`
- **Default values** — an optional parameter the caller leaves out is recorded
  with its `DEFAULT` value instead of initial
