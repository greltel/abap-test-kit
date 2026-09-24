# ABAP Test Kit

**ABAP Unit made readable: test doubles that read like sentences, for your first test and your thousandth.**

ABAP Test Kit (ATK) sits on top of SAP's ABAP Test Double Framework (`CL_ABAP_TESTDOUBLE`).
It keeps what the framework does well and replaces the parts that make tests hard to write,
hard to read and hard to debug.

- **New to ABAP Unit?** Write your first test double without learning the framework's traps
  first. When something is wrong, the message tells you what and how to fix it.
- **Already writing tests?** Write fewer statements, keep arrange-act-assert in its natural
  order, and get failure messages that point at the argument that differs.

```abap
" Classic ABAP Test Double Framework
cl_abap_testdouble=>configure_call( audit_log )->and_expect( )->is_called_times( 1 ).
audit_log->write( order_id = '4711' action = `CANCELLED` ).   " not a real call - it only records
cut->cancel( '4711' ).
cl_abap_testdouble=>verify_expectations( audit_log ).

" ABAP Test Kit
cut->cancel( '4711' ).
audit_log->was_called( 'WRITE' )->with( parameter = 'ACTION' value = `CANCELLED` )->times( 1 ).
```

> **Status:** version 0.1.0 (test doubles). The code passes abaplint in ABAP Cloud mode and
> ships with its own unit tests; the first activation on a real system is in progress - see
> [First run](#first-run-on-a4h).

## Contents

- [What you gain](#what-you-gain)
- [Before and after, scenario by scenario](#before-and-after-scenario-by-scenario)
- [Questions experienced developers ask](#questions-experienced-developers-ask)
- [Install](#install)
- [First run on A4H](#first-run-on-a4h)
- [Guide](#guide)
- [How it works inside](#how-it-works-inside)
- [Limitations](#limitations)
- [Objects](#objects)
- [Development](#development)
- [Roadmap](#roadmap)

## What you gain

Measured on the demo package `ZATK_DEMO`, where every scenario below exists twice, once per
style, and both versions pass:

| | Classic ATDF | ABAP Test Kit |
|---|---|---|
| Statements to set up and check doubles in the 4 shared scenarios | 14 | 6 |
| Lines that look like real calls but only record arguments | 6 | 0 |
| Where call checks are written | before the act step, then `verify_expectations( )` | after the act step, like every other assertion |
| A call with arguments no configuration matches | returns initial values, silently | fails the test and shows the actual arguments |
| A check that fails because one argument differs | reports the unmet expectation | also shows the closest actual call and the parameter that differs |
| EXPORTING and CHANGING parameters | `set_parameter( )`, and the recording call must not receive them | `sets( )` for both |
| A value that does not fit the parameter, e.g. `'47A1'` for a numeric text | converted by the usual ABAP rules | rejected with a message, before the test runs the code |
| A misspelled method or parameter name | compile error (the recording call is real code) | message with a suggestion: "Did you mean GET_ORDER?" |
| Errors of the framework itself | `CX_ATD_EXCEPTION` | `ZCX_ATK`: what went wrong, how to fix it |

The last-but-one row is the honest trade-off: ATDF catches a misspelled name when you
activate, ATK catches it the first time the test runs (see the [questions](#questions-experienced-developers-ask)).

## Before and after, scenario by scenario

All examples test the same small class, `ZCL_ATK_DEMO_ORDER_SERVICE`: it reads an order from a
repository and, when it cancels an open order, writes the cancellation to an audit log. Both
collaborators are injected through the constructor.

```abap
" Classic: create the doubles and inject them
repository = CAST zif_atk_demo_order_repo( cl_abap_testdouble=>create( 'ZIF_ATK_DEMO_ORDER_REPO' ) ).
audit_log  = CAST zif_atk_demo_audit_log( cl_abap_testdouble=>create( 'ZIF_ATK_DEMO_AUDIT_LOG' ) ).
cut = NEW zcl_atk_demo_order_service( repository = repository
                                      audit_log  = audit_log ).

" ABAP Test Kit: the kind of double says what it is for
repository = zcl_atk=>stub( 'ZIF_ATK_DEMO_ORDER_REPO' ).   " answers questions
audit_log  = zcl_atk=>spy( 'ZIF_ATK_DEMO_AUDIT_LOG' ).     " remembers what it was told
cut = NEW zcl_atk_demo_order_service( repository = CAST #( repository->instance( ) )
                                      audit_log  = CAST #( audit_log->instance( ) ) ).
```

### 1. Return a value for a specific argument

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

**What you gain:** one sentence instead of a configuration plus a call that is not really a
call. The argument the answer depends on is named, so the test says *why* this order comes back.

### 2. Raise an exception

```abap
" Before
cl_abap_testdouble=>configure_call( repository )->raise_exception( NEW zcx_atk_demo_not_found( ) ).
repository->get_order( '4711' ).
```

```abap
" After
repository->when( 'GET_ORDER' )->raises( NEW zcx_atk_demo_not_found( ) ).
```

**What you gain:** the recording call `repository->get_order( '4711' )` declares
`RAISING zcx_atk_demo_not_found`, so the classic version forces a `RAISING` clause on a test
method for a line that never raises. ATK also checks that `GET_ORDER` really declares the
exception - a double that raises something the method cannot raise is rejected with a message.

### 3. Check that a method was called once, with the right arguments

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

**What you gain:** five statements become two. The test reads in the order you think about it -
arrange, act, assert - instead of declaring the expectation before anything has happened. And
when the check fails, you see why:

```text
WRITE: expected 1 matching call(s), but found 0. Check the code under test, or adjust with( )
and times( ). Expected arguments: ACTION = 'CANCELLED', ORDER_ID = '0000004711'. Closest actual
call: ACTION = 'CANCELED', ORDER_ID = '0000004711'. Differs in: ACTION.
```

### 4. Check that a method was not called

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

**What you gain:** no dummy arguments for a call that must *not* happen, no
`ignore_all_parameters( )`, no `verify_expectations( )`. The last line says exactly what the
test checks.

### 5. Every call declared up front (strict mock)

Sometimes any unplanned call is a bug. A mock fails the test at the moment an undeclared call
happens, and `verify( )` reports declared calls that never came:

```abap
" After (ABAP Test Kit only - ATDF has no strict mode: undeclared calls return initial values)
DATA(strict_log) = zcl_atk=>mock( 'ZIF_ATK_DEMO_AUDIT_LOG' ).
strict_log->expect_call( 'WRITE' )->with( parameter = 'ACTION' value = zif_atk_demo_audit_log=>action-cancelled ).

service->cancel( '4711' ).

strict_log->verify( ).
```

### 6. When the test itself is wrong

The most expensive test bugs are silent. Say the configuration is for order `4711`, but the
code under test asks for `0815`:

- **Before:** ATDF finds no matching configuration and returns an initial order. The code under
  test carries on with it, and the test fails somewhere later - or worse, passes.
- **After:** a stub that has rules for `GET_ORDER` fails the test at the call:

```text
GET_ORDER was called with arguments that match none of its rules. Add a rule for these
arguments, or check the code under test. Actual arguments: ORDER_ID = '0000000815'.
```

The same care applies to the test's own values. `with( parameter = 'ORDER_ID' value = '47A1' )`
is rejected instead of silently turning into `0000000471`, text that is too long for the
parameter is rejected instead of cut, and `'12.345'` for an amount with two decimals is rejected
instead of rounded.

## Questions experienced developers ask

**Is it type-safe?** Not in the compiler's sense. Method and parameter names are strings, so
ATDF catches a misspelling at activation and ATK catches it the first time the test runs - with
a suggestion for the closest name, and before the code under test runs. Rename refactoring in
ADT does not update the strings either. In exchange, the test contains no call that only
pretends to be one. A static check for these strings is planned (Phase 3).

**Does it replace ATDF?** No. ATDF still creates the doubles and intercepts the calls; ATK adds
rules, a call journal and messages on top. You can mix both in one test class.

**Why not write test doubles by hand?** For an interface with one method and one scenario, a
local class is fine. It grows with every method (or needs `PARTIALLY IMPLEMENTED`) and with
every scenario (fields, flags, counters), and each hand-written double is code that needs its
own review. With ATK the double is one line and the scenario is one sentence.

**Can it leak into production code?** No. `ZCL_ATK` is a test class (`FOR TESTING`), so only
test code can use it.

**What does it need?** ABAP for Cloud Development on SAP BTP ABAP Environment, S/4HANA Cloud
Public Edition, or S/4HANA 2023 and later. Only released SAP APIs, no other dependencies.

**What does the injection cost?** One `CAST #( double->instance( ) )` per collaborator, because
one double object serves all four kinds (dummy, stub, spy, mock).

## Install

1. In ADT, create the package **`ZATK`** with ABAP language version *ABAP for Cloud
   Development*. On a BTP or S/4HANA Cloud system any package of your cloud software component
   works.
2. Link this repository to `ZATK` with abapGit (the ADT *abapGit Repositories* view, or the
   abapGit report on an on-premise system) and pull. abapGit creates the sub-packages:

   | Package | Content | Needed in production code? |
   |---|---|---|
   | `ZATK` | The library: `ZCL_ATK`, the `ZIF_ATK_*` interfaces, `ZCX_ATK`, message class `ZATK` | No - `ZCL_ATK` is `FOR TESTING` |
   | `ZATK_TEST` | Fixtures for ATK's own tests | No |
   | `ZATK_DEMO` | The before/after demo | No |

3. Activate everything (Ctrl+Shift+F3).
4. Run the unit tests of package `ZATK` (right-click, *Run As → ABAP Unit Test*). All tests
   should be green.

## First run on A4H

ATK relies on a few ATDF behaviors that are not documented. The library's own tests check each
of them. If a test fails on your system, this is where to look:

| Symptom | Behavior it checks | Where to adapt |
|---|---|---|
| Syntax error or warning about test classes in `zcl_atk.clas.locals_imp.abap` | `lth_atdf_gateway` and `lth_double_factory` use `CL_ABAP_TESTDOUBLE`, so they are `FOR TESTING`, but they live in the local implementation include because `ZCL_ATK` needs them | A warning can be ignored. On an error, remove `FOR TESTING` from both classes - the global test class may already make its whole class pool test code |
| `when_returns_double_then_same` fails, or `?=` is rejected at activation | A value of static type `REF TO object` (what `instance( )` returns) can be down-cast into a generically typed target | `lcl_doubled_method=>copies_losslessly` |
| `when_called_thrice_answers` fails | One catch-all configuration with `times( )` answers every call | `lth_atdf_gateway=>route_method` |
| Every stub returns initial values, or `internal_error` is reported | The method name ATDF passes to the answer, with or without interface prefix | `lcl_doubled_type=>method_called_by_atdf` |
| `given_generic_table_then_works` or `given_generic_input_then_works` fails | The recording call can fill generically typed parameters | `lcl_doubled_method=>concrete_type_for` |
| `when_raises_then_caller_gets` fails | `IF_ABAP_TESTDOUBLE_RESULT->raise_exception( )` records the exception and ATDF raises it after the answer | `lcl_call_rule=>answer` |
| A failure during the act step does not show up | `CL_ABAP_UNIT_ASSERT=>fail( quit = no )` inside the ATDF answer | `lcl_unit_failure_reporter` |
| Objects were created as *Standard ABAP* | abapGit took the language version from its defaults | Change it in the object properties, or set it on the package before pulling |

Please open an issue with the failing test and the message - that is exactly the feedback
ATK needs at this stage.

## Guide

### Pick the right double

| You need… | Use | The test fails when… |
|---|---|---|
| a collaborator that must be passed in, but is never used | `zcl_atk=>dummy( )` | it is called at all |
| a collaborator that *answers* questions (a query) | `zcl_atk=>stub( )` | a method with rules is called with arguments no rule matches |
| a collaborator that is *told* to do something (a command), checked afterwards | `zcl_atk=>spy( )` | like a stub, plus your `was_called( )` checks |
| every call declared up front, nothing else allowed | `zcl_atk=>mock( )` | an undeclared call happens, or `verify( )` finds a declared call missing |

Every double hands out the fake object with `instance( )`; cast it where you inject it.
Doubles can be made of global interfaces and of global classes that are not final, not
`CREATE PRIVATE`, and have no mandatory constructor parameters.

### Stubs

```abap
DATA(repository) = zcl_atk=>stub( 'ZIF_ORDER_REPOSITORY' ).

" answer one argument value
repository->when( 'GET_ORDER' )->with( parameter = 'ORDER_ID' value = '4711' )->returns( open_order ).

" answer every other call
repository->when( 'GET_ORDER' )->returns( unknown_order ).

" fill EXPORTING or CHANGING parameters - you do not need to know which of the two
repository->when( 'READ_TOTALS' )->sets( parameter = 'NET' value = 100 )->sets( parameter = 'TAX' value = 24 ).

" raise an exception the method declares
repository->when( 'GET_ORDER' )->with( parameter = 'ORDER_ID' value = '0000' )->raises( NEW zcx_order_not_found( ) ).
```

- `with( )` names an IMPORTING or CHANGING parameter. Call it once per parameter.
- `returns( )` sets the RETURNING value. `sets( )` sets EXPORTING or CHANGING parameters.
  Both can be combined in one rule.
- `raises( )` ends the rule. The method must declare the exception, unless it is a
  `CX_NO_CHECK` exception.
- A method without any rule returns initial values.

### Spies

```abap
DATA(audit_log) = zcl_atk=>spy( 'ZIF_AUDIT_LOG' ).

cut->cancel( '4711' ).

audit_log->was_called( 'WRITE'
  )->with( parameter = 'ORDER_ID' value = '4711'
  )->with( parameter = 'ACTION' value = `CANCELLED`
  )->times( 1 ).

audit_log->was_not_called( 'DELETE' ).
```

`times( )` performs the check - a `was_called( )` without `times( )` checks nothing.
`times( 0 )` and `was_not_called( )` both check that no matching call happened.

### Mocks

```abap
DATA(audit_log) = zcl_atk=>mock( 'ZIF_AUDIT_LOG' ).
audit_log->expect_call( 'WRITE' )->with( parameter = 'ACTION' value = `CANCELLED` ).

cut->cancel( '4711' ).

audit_log->verify( ).
```

An expectation without `times( )` expects exactly one call. It can answer like a stub rule:
`expect_call( 'GET_ORDER' )->returns( open_order )`. If you are unsure whether you need a mock,
use a spy.

### Dummies

```abap
DATA(unused_log) = zcl_atk=>dummy( 'ZIF_AUDIT_LOG' ).
cut = NEW zcl_order_service( repository = CAST #( repository->instance( ) )
                             audit_log  = CAST #( unused_log->instance( ) ) ).
```

Any call of a dummy fails the test and names the method, so you know you need a stub instead.

### How matching works

- **Names** of methods and parameters are checked against the doubled type as soon as you
  write them. Case does not matter. A close misspelling gets a suggestion.
- **Values** are converted to the parameter's type, never with loss: `'4711'` becomes the
  numeric text `0000004711`; `'47A1'`, text that is too long and decimals that would be rounded
  are rejected.
- **Parameters you do not name** match any value.
- **Several rules match a call:** the rule with the most `with( )` conditions wins; on a tie,
  the rule written last wins. So a general rule and specific exceptions can be written in any
  order.
- **Strict stubs:** once a method has rules, a call that matches none of them fails the test.
  Methods without rules return initial values.
- **Failures during the act step** are recorded without stopping the code under test, so a
  `CATCH cx_root` in the code under test cannot hide them.

### When something is wrong

Every problem raises or reports `ZCX_ATK`. Its text has three parts - what went wrong, how to
fix it, and details:

```text
ZCL_ORDER_SERVICE is a final class, so no double can extend it. Extract an interface from
ZCL_ORDER_SERVICE and let the code depend on it.
```

The texts live in message class `ZATK` (001-025 what, 101-121 fix, 201-212 labels). ATDF's own
exceptions never reach the test untranslated.

## How it works inside

1. `zcl_atk=>stub( )` describes the type with RTTI and rejects what ATDF cannot double, with a
   reason.
2. ATDF creates the double. For every method, ATK registers **one** catch-all configuration
   (`ignore_all_parameters( )` and an answer object) with a dynamic recording call built from
   RTTI. This is the only place where the configure-then-call two-step happens.
3. `when( )`, `with( )` and the other configuration methods only write rules into memory,
   checked with RTTI.
4. At runtime, ATDF hands every call to ATK's answer, which records it and answers with the best
   rule.
5. `was_called( )` and `verify( )` read the recorded calls.

All of it is in `zcl_atk.clas.locals_imp.abap` as local classes, so the public surface is only
`ZCL_ATK`, the `ZIF_ATK_*` interfaces and `ZCX_ATK`.

## Limitations

- Values are compared with `=`. Matchers such as "any text containing X" are planned for
  Phase 2.
- Events of doubled types are not supported yet.
- Methods with generically typed mandatory parameters of kind `SORTED TABLE` or `HASHED TABLE`
  cannot be doubled yet (`INDEX TABLE`, `STANDARD TABLE`, `ANY` and the other generic types
  work).
- Static, final and private methods cannot be doubled - an ATDF restriction.
- One answer per rule. Different answers for consecutive calls are an open design question.
- An optional IMPORTING parameter that the caller leaves out is recorded as initial, not with
  its `DEFAULT` value (RTTI does not expose default values).
- Values shown inside the first sentence of a message are cut at 50 characters (T100
  placeholders); longer texts go to the details part of the message.

## Objects

| Object | Purpose |
|---|---|
| `ZCL_ATK` | Entry point: `dummy( )`, `stub( )`, `spy( )`, `mock( )` |
| `ZIF_ATK_DOUBLE` | `instance( )` - what every double offers |
| `ZIF_ATK_DUMMY`, `ZIF_ATK_STUB`, `ZIF_ATK_SPY`, `ZIF_ATK_MOCK` | One interface per kind of double; the type shows what is allowed |
| `ZIF_ATK_CALL_RULE` | `with( )`, `returns( )`, `sets( )`, `raises( )` of a stub or spy |
| `ZIF_ATK_CALL_EXPECTATION` | The same plus `times( )`, for mocks |
| `ZIF_ATK_CALL_VERIFICATION` | `with( )`, `times( )` of a spy check |
| `ZCX_ATK` | The only exception; `problem` tells which one |
| `ZATK` | Message class |

## Development

Static checks run with [abaplint](https://abaplint.org) in ABAP Cloud mode on every push
(`.github/workflows/abaplint.yml`). To run them locally:

```sh
npx @abaplint/cli@latest abaplint.json
```

`abaplint-stubs/` holds minimal definitions of the ATDF and ABAP Unit objects so that abaplint
can type-check calls to them; abapGit ignores the folder. The configuration follows the
[Clean ABAP](https://github.com/SAP/styleguides/blob/main/clean-abap/CleanABAP.md) style guide,
so the rules that enforce Hungarian prefixes are switched off, and so are:

| Rule | Why it is off |
|---|---|
| `no_aliases` | The interfaces alias `instance( )` and `when( )` so tests read `stub->when( )` |
| `no_dynamic_stuff` | Dynamic calls and RTTI are how ATK works |
| `easy_to_find_messages` | Message numbers are chosen through the constants of `ZCX_ATK` |
| `no_inline_in_optional_branches` | It also flags `LOOP AT … INTO DATA( )` and `CATCH … INTO DATA( )` |
| `definitions_top` | Clean ABAP prefers inline declarations |
| `line_break_multiple_parameters` (tests only) | `with( parameter = … value = … )` reads best on one line |
| `local_testclass_consistency` (`zcl_atk` local types only) | The ATDF gateway must be `FOR TESTING` and visible to `ZCL_ATK` |

## Roadmap

- **Phase 1** - test doubles (this release).
- **Phase 2** - fluent assertions: `zcl_atk=>expect( actual )->to_equal( expected )` with the
  same message style, and matchers for `with( )`.
- **Phase 3** - a testability analyzer that explains why a class is hard to test and how to fix
  it, including a check for misspelled names in ATK tests.
- **Phase 4** - koans: red-to-green exercises built on Phases 1 and 2.

## License

[MIT](LICENSE)
