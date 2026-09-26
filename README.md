# ABAP Test Kit
[![ABAP Cloud](https://img.shields.io/badge/ABAP-Cloud%20Ready-green)](https://abaplint.app/stats/greltel/abap-test-kit/object_classifications)
[![ABAP Version](https://img.shields.io/badge/ABAP-7.58%2B-blue)](https://abaplint.app/stats/greltel/abap-test-kit/statement_compatibility)
[![Code Statistics](https://img.shields.io/badge/CodeStatistics-abaplint-blue)](https://abaplint.app/stats/greltel/abap-test-kit)
[![License](https://img.shields.io/badge/License-MIT-green)](https://github.com/greltel/abap-test-kit/blob/main/LICENSE)
[![Release](https://img.shields.io/github/v/release/greltel/abap-test-kit?label=release)](https://github.com/greltel/abap-test-kit/releases)
[![abaplint](https://github.com/greltel/abap-test-kit/actions/workflows/abaplint.yml/badge.svg)](https://github.com/greltel/abap-test-kit/actions/workflows/abaplint.yml)
[![unit tests](https://github.com/greltel/abap-test-kit/actions/workflows/unit.yml/badge.svg)](https://github.com/greltel/abap-test-kit/actions/workflows/unit.yml)
# Table of contents

1. [ABAP Test Kit](#abap-test-kit)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Quick start](#quick-start)
5. [Versioning](#versioning)
6. [License](#license)
7. [Contributors-Developers](#contributors-developers)
8. [Available Test Doubles](#available-test-doubles)
9. [Before and After](#before-and-after)
10. [Limitations](#limitations)
11. [Design Goals-Features](#design-goals-features)
12. [To-Do](#to-do)

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

Verified with the ABAP Cloud Developer Trial 2025 (SAP S/4HANA 2023 based) and, on every push,
off-stack with the abaplint transpiler. Reports from SAP BTP ABAP Environment and S/4HANA Cloud
Public Edition are welcome.

# Installation

Install via [abapGit](https://abapgit.org) into a package flagged as
**ABAP Cloud** in the customer namespace, e.g. `ZATK`. The repository is set to
the ABAP language version *ABAP for Cloud Development*, so abapGit only imports
it into packages with that language version. Create the package and its two
sub-packages in ADT before the pull:

| Package | Super package | Content |
|---|---|---|
| `ZATK` | - | The library: `ZCL_ATK`, the `ZIF_ATK_*` interfaces, `ZCX_ATK` and message class `ZATK` |
| `ZATK_TEST` | `ZATK` | Fixtures for the unit tests of the library |
| `ZATK_DEMO` | `ZATK` | A small order service, tested once with the classic framework and once with the library |

Then link `https://github.com/greltel/abap-test-kit.git` to `ZATK`, pull, and
run the unit tests of `ZATK` and its sub-packages; all of them should pass.
`ZCL_ATK` is a test class (`FOR TESTING`), so only test code can use it.

# Quick start

The code under test gets its collaborators through the constructor, as interfaces. The test
replaces them with doubles from `ZCL_ATK` and injects `instance( )` of each double:

```abap
CLASS ltc_order_service DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA repository TYPE REF TO zif_atk_stub.
    DATA audit_log TYPE REF TO zif_atk_spy.
    DATA cut TYPE REF TO zif_atk_demo_order_service.

    METHODS setup.
    METHODS when_cancel_then_logged_once FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_order_service IMPLEMENTATION.

  METHOD setup.
    repository = zcl_atk=>stub( 'ZIF_ATK_DEMO_ORDER_REPO' ).
    audit_log = zcl_atk=>spy( 'ZIF_ATK_DEMO_AUDIT_LOG' ).
    cut = NEW zcl_atk_demo_order_service( repository = CAST #( repository->instance( ) )
                                          audit_log  = CAST #( audit_log->instance( ) ) ).
  ENDMETHOD.

  METHOD when_cancel_then_logged_once.
    " arrange: the repository answers with an open order
    repository->when( 'GET_ORDER' )->returns( VALUE zif_atk_demo_order_repo=>ty_order(
        id     = '0000004711'
        status = zif_atk_demo_order_repo=>status-open ) ).

    " act
    cut->cancel( '4711' ).

    " assert: the cancellation was written to the log, exactly once
    audit_log->was_called( 'WRITE' )->with( parameter = 'ACTION' value = `CANCELLED` )->times( 1 ).
  ENDMETHOD.

ENDCLASS.
```

Run it in ADT with *Ctrl+Shift+F10*. If a name is misspelled or a value does not fit the
parameter, the test fails at that line with a message that says what to change.

Which double do I need?

| The collaborator... | Use | Because |
|---|---|---|
| must be passed in, but the scenario never uses it | `dummy( )` | any call fails the test and names the method |
| is asked for data | `stub( )` | the test decides the answers, and checks the result of the code under test |
| is told to do something | `spy( )` | the test checks after the act step that it was told, and how often |
| must receive exactly the declared calls and nothing else | `mock( )` | any other call fails at once; `verify( )` reports missing calls |

If unsure between spy and mock, take the spy: it answers like a stub, and the checks are
written after the act step, where a reader expects them.

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
the name of a global interface. The instance methods of the interface and of its
component interfaces can be configured; static methods cannot be doubled.
Classes are rejected: from ABAP Cloud code, the calls of a class double cannot be
taken over by method name, so extract an interface and let the code depend on
it, or double the class with `CL_ABAP_TESTDOUBLE` directly. `instance( )`
hands out the object that is injected into the code under test. Rules and
checks are fluent interfaces, method names, parameter names and values are
checked against the doubled type while the test is set up, and errors surface
through one exception class, `ZCX_ATK`.

## Cheat sheet

| I want to... | Write |
|---|---|
| inject a double | `NEW zcl_service( CAST #( double->instance( ) ) )` |
| answer a method | `stub->when( 'GET_ORDER' )->returns( order )` |
| answer only for an argument | `stub->when( 'GET_ORDER' )->with( parameter = 'ORDER_ID' value = '4711' )->returns( order )` |
| fill an EXPORTING or CHANGING parameter | `stub->when( 'READ' )->sets( parameter = 'MESSAGES' value = messages )` |
| raise an exception | `stub->when( 'GET_ORDER' )->raises( NEW zcx_not_found( ) )` |
| check that a method was called | `spy->was_called( 'WRITE' )->times( 1 )` |
| check the arguments of the call | `spy->was_called( 'WRITE' )->with( parameter = 'ACTION' value = 'CANCELLED' )->times( 1 )` |
| check that a method was not called | `spy->was_not_called( 'DELETE' )` |
| declare every call up front | `mock->expect_call( 'WRITE' )->times( 2 )` ... `mock->verify( )` |
| name a method of a component interface | `when( 'WRITE' )` or `when( 'ZIF_LOG~WRITE' )` |

Names are not case sensitive. Values are converted to the parameter type without loss, so
`'4711'` fits a numeric text of length 10, and `'47A1'` is rejected.

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
arguments, the closest actual call with the method and line it came from, and the
parameters that differ.

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
WRITE: expected 1 matching call(s), but found 0.
Check the code under test, or adjust with( ) and times( ).
Expected arguments: ORDER_ID = '0000004711', ACTION = 'CANCELLED'.
Closest actual call: ORDER_ID = '0000004711', ACTION = 'CANCELED' from ZCL_ORDER_SERVICE=>ZIF_ORDER_SERVICE~CANCEL, line 6 of the method.
Differs in: ACTION.
```

## Mock

A strict double for scenarios where any unplanned call is a bug. Every expected
call is declared with `expect_call( )` before the act step; a call that was not
declared fails the test at once, and `verify( )` reports declared calls that did
not happen as often as declared. Without `times( )` an expectation expects
exactly one call, and it can answer like a stub rule. Two expectations for the
same method are two calls: each call is matched to the most specific expectation
that still waits for a call.

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

Every mistake in a test surfaces through `ZCX_ATK`. Its text has the same three parts every
time, in this order: what went wrong, how to fix it, and the facts - the arguments of the
call and the method and line of the code under test that made it, the rules that exist,
the closest one and where it differs, or what a value would become. In the ABAP Unit result, the first part is the message of the failure; the fix and
the facts are its detail, shown under it (Analysis in the SAP GUI, Details in ADT). The
examples below show the parts on separate lines. Close misspellings of method and parameter names get a suggestion; names that are
far from every candidate get the list of candidates with their kinds. The texts live in
message class `ZATK`; exceptions of the test double framework never reach the test
untranslated. Failures during the act step are recorded without stopping the code under
test, so a `CATCH cx_root` in the code under test cannot hide them; the facts of such a
failure name the method and the line that called the double (read from the XCO call
stack, with the line counted from the `METHOD` statement).

```text
ZCL_ORDER_SERVICE is a class, and ATK doubles interfaces only.
Extract an interface from ZCL_ORDER_SERVICE, or double it with CL_ABAP_TESTDOUBLE.
```

```text
Method GET_ORDER has no parameter CUSTOMER.
Pick one of the available names.
Available: ORDER_ID (IMPORTING), RESULT (RETURNING).
```

```text
Value '12.345' does not fit parameter AMOUNT of type TY_AMOUNT (P LENGTH 8 DECIMALS 2).
Pass a value of that type, for example a typed variable.
Instead, the parameter would hold: 12.35.
```

```text
FIRST_NAME of SPLIT_NAME is declared EXPORTING, not as an input.
with( ) is for IMPORTING and CHANGING; outputs go to sets( ).
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
GET_ORDER was called with arguments that match none of its rules.
Add a rule for these arguments, or check the code under test.
Actual arguments: ORDER_ID = '0000000815'.
Called from: ZCL_ATK_DEMO_ORDER_SERVICE=>ZIF_ATK_DEMO_ORDER_SERVICE~CANCEL, line 2 of the method.
Rules: (ORDER_ID = '0000004711').
Closest rule differs in: ORDER_ID.
```

The failure list of ABAP Unit shows the first line; the rest is the detail of the failure
(Analysis in the SAP GUI, Details in ADT). The classic framework fails in the same place -
at the call - only when an expectation is configured for it; the line it shows is the one
of the framework, and the method of the code under test is somewhere in the stack trace.

## Summary

In the four scenarios that exist in both test classes, the doubles need 6
statements instead of 14, and none of them is a call that only records
arguments. What the library takes off your hands, compared with the classic
framework used directly:

| With `CL_ABAP_TESTDOUBLE` directly | With the library |
|---|---|
| Two statements per configuration: `configure_call( )`, then a call that looks like a real call but only records arguments | One statement: `when( )->with( )->returns( )` |
| The recording call needs every mandatory parameter, even those the scenario does not care about, and a `RAISING` clause when the method raises | Only the parameters named in `with( )` matter; the rest match any value |
| A never-called check needs `ignore_all_parameters( )`, a placeholder call and `verify_expectations( )` | `was_not_called( )` |
| Expectations are written before the act step and checked by `verify_expectations( )` | Spy checks are written after the act step, where the reader expects them |
| `set_parameter( )` for outputs; EXPORTING and CHANGING are not distinguished for the reader | `sets( )` for both |
| A call without a matching configuration returns initial values silently | A call that matches no rule of a configured method fails the test at the call, with the arguments |
| A wrong value in a configuration fails the test somewhere later, or not at all | Values are checked against the parameter type when the rule is written; the message says what the parameter would hold instead |
| A failed expectation says how many calls were made, not which | The failure shows the expected arguments, the closest call and the parameter that differs |
| Which line of the code under test made the unwanted or unmatched call is in the stack trace, if the failure happens at the call at all | Every recorded call carries the method and line of the code under test that made it: `from ZCL_ORDER_SERVICE=>ZIF_ORDER_SERVICE~CANCEL, line 6 of the method` |
| Framework exceptions (`CX_ATD_EXCEPTION`) with technical texts | One exception class whose text says what went wrong and how to fix it, with a suggestion for misspelled names |

One difference to keep in mind: method and parameter names are strings. The
classic framework catches a misspelled name at activation, the library the
first time the test runs, with a suggestion for the closest name; a rename
refactoring in ADT does not update them.

# Limitations

* Only **global interfaces** can be doubled. Classes are rejected with a message that says why
  (see [Available Test Doubles](#available-test-doubles)); local interfaces of a test include
  cannot be described by name.
* **Static methods** and **events** of the doubled interface are not doubled. `when( )` on a
  static method reports it as unknown.
* An optional parameter the caller leaves out is recorded as **initial**, not with its `DEFAULT`
  value, because RTTI does not expose defaults. A condition on such a parameter is not met, and
  the failure marks the parameter with `(not supplied)`.
* Mandatory parameters typed generically as `SORTED TABLE` or `HASHED TABLE` cannot be doubled
  yet; `ANY TABLE`, `INDEX TABLE`, `STANDARD TABLE`, `ANY`, `DATA` and the other generic types work.
* `with( )` compares for equality. Matchers such as "any text containing" are planned.
* A spy check without `times( )` checks nothing; a mock that is never verified checks only
  the undeclared calls. Both are planned to be detected by the testability analyzer.
* `raises( )` accepts exceptions the method declares and `CX_NO_CHECK` ones; an undeclared
  `CX_DYNAMIC_CHECK` exception is rejected, although ABAP would allow it.

# Design Goals-Features

* ABAP Cloud / Clean Core compatibility — passes the ATC variant `ABAP_CLOUD_DEVELOPMENT_DEFAULT`
* Released APIs only (release contract C1), no dependencies besides SAP's own classes
* Built on `CL_ABAP_TESTDOUBLE` — no own mocking engine; both can be used in the same test class
* Tests in arrange-act-assert order: spies are checked after the act step
* Messages in three parts - what went wrong, how to fix it, the facts; framework exceptions never reach the test untranslated
* Method names, parameter names and values checked against the doubled type with RTTI
* Small public surface: one facade class, fluent interfaces and one exception class; everything else is local to `ZCL_ATK`
* Test code only — `ZCL_ATK` is `FOR TESTING`, so production code cannot depend on it
* Clean Code following the [Clean ABAP Style Guides](https://github.com/SAP/styleguides/blob/main/clean-abap/CleanABAP.md)
* Modern ABAP syntax (7.58 / 9.14) — expressions, inline declarations, string templates
* 149 unit tests of the library run with ABAP Unit against the real `CL_ABAP_TESTDOUBLE`, and off-stack on every push with the abaplint transpiler; abaplint on every push
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
   method and parameter names in tests that use the library, and find spy checks
   without `times( )` and mocks without `verify( )`
3. **Koans** — red-to-green exercises built on the test doubles and the
   assertions

## Improvements to the test doubles

- **Consecutive answers** — a different answer for the first, second and
  following calls of a method
- **Matchers for `with( )`** — conditions such as "any text containing" instead
  of equality
- **Argument capture** — read the arguments of a recorded call in the test, for
  assertions on structures and tables with the developer's own checks
- **Events** — raise the events of a doubled type
- **Generic sorted and hashed tables** — mandatory parameters typed
  `SORTED TABLE` or `HASHED TABLE`
