# Contributing

Issues and pull requests are welcome. This file describes how the repository is
set up, how the library works inside, and how a release is made. How to use the
library is described in the [README](README.md).

# Table of contents

1. [Reporting issues](#reporting-issues)
2. [Repository layout](#repository-layout)
3. [Development setup](#development-setup)
4. [Coding rules](#coding-rules)
5. [Static checks](#static-checks)
6. [Unit tests](#unit-tests)
7. [How it works inside](#how-it-works-inside)
8. [Test double framework behaviors the library relies on](#test-double-framework-behaviors-the-library-relies-on)
9. [Releasing](#releasing)

# Reporting issues

Please include the system (SAP BTP ABAP Environment, S/4HANA Cloud Public
Edition, or S/4HANA release and FPS), the failing test or a small snippet that
reproduces the problem, and the full text of the message. For a failing test of
the library itself, check the table in
[Test double framework behaviors the library relies on](#test-double-framework-behaviors-the-library-relies-on)
first.

# Repository layout

| Folder | Package | Content |
|---|---|---|
| `src/` | `ZATK` | The library: `ZCL_ATK`, the `ZIF_ATK_*` interfaces, `ZCX_ATK` and message class `ZATK` |
| `src/test/` | `ZATK_TEST` | Interfaces and an exception used by the unit tests of `ZCL_ATK` |
| `src/demo/` | `ZATK_DEMO` | The order service of the [Before and After](README.md#before-and-after) section, tested once with the classic framework and once with the library |
| `abaplint-stubs/` | - | Minimal definitions of SAP objects for abaplint and the transpiler; abapGit ignores the folder |
| `transpiler/` | - | Off-stack test runner: ATDF stand-in, patched open-abap-core classes, runtime patches (see [transpiler/README.md](transpiler/README.md)) |
| `.github/workflows/` | - | abaplint and the off-stack unit tests on every push and pull request |

abapGit uses the `PREFIX` folder logic, so the sub-packages are named after the
folders.

# Development setup

1. Create packages `ZATK`, `ZATK_TEST` and `ZATK_DEMO` (the last two with
   super package `ZATK`) with ABAP language version *ABAP for Cloud
   Development*. The ABAP Cloud Developer Trial works fine for development.
   `.abapgit.xml` sets the repository to `cloudDevelopment`, so abapGit
   refuses packages and objects with another language version.
2. Link a fork of the repository to `ZATK` with abapGit and pull.
3. Activate everything and run the unit tests of `ZATK` and its sub-packages.
4. Change the objects in ADT, then stage and commit them with abapGit. Files
   outside `src/` (README, CHANGELOG, abaplint configuration) are changed in
   the Git repository directly.

# Coding rules

* ABAP for Cloud Development, released APIs only; the code must pass the ATC
  variant `ABAP_CLOUD_DEVELOPMENT_DEFAULT`
* No dependencies besides SAP's own classes
* [Clean ABAP](https://github.com/SAP/styleguides/blob/main/clean-abap/CleanABAP.md):
  no Hungarian prefixes, descriptive names, small methods, modern syntax
* The public surface stays small: `ZCL_ATK`, the `ZIF_ATK_*` interfaces and
  `ZCX_ATK`. Everything else is a local class in `zcl_atk.clas.locals_imp.abap`
* ABAP Doc on every public declaration. Interfaces of doubles say when to use
  them
* Every problem is a constant of `ZCX_ATK` with two messages in `ZATK`: what
  went wrong (001-099) and how to fix it (101-199). Labels used inside the
  details are 201-299. `get_text( )` puts the three parts on their own lines
  (`cl_abap_char_utilities=>newline`), and every detail is one line of the form
  `Label: facts.` built with `lcl_text=>labeled( )` and `lcl_text=>as_lines( )`.
  A message uses each placeholder once (abaplint `message_exists` counts them)
  and is at most 73 characters long. Exceptions of the test double framework
  are caught and translated, never passed on
* Every change comes with unit tests, and every new or changed public method
  with a README section and a CHANGELOG entry

# Static checks

[abaplint](https://abaplint.org) runs in ABAP Cloud mode on every push and pull
request (`.github/workflows/abaplint.yml`), with the version pinned in
`package-lock.json`. To run it locally:

```sh
npm ci
npm run lint
```

abaplint downloads the definitions of the SAP standard objects from
[abaplint/deps](https://github.com/abaplint/deps). The test double framework
and ABAP Unit are not part of them, so `abaplint-stubs/` holds minimal
definitions of `CL_ABAP_TESTDOUBLE`, the `IF_ABAP_TESTDOUBLE_*` interfaces,
`CX_ATD_EXCEPTION_CORE`, `CL_ABAP_UNIT_ASSERT` and `IF_ABAP_UNIT_CONSTANT`.
When the library uses a method of these objects that is not stubbed yet, add
it to the stub with the signature from ADT.

The configuration follows the Clean ABAP style guide, so the rules that
enforce Hungarian prefixes are switched off, and so are:

| Rule | Why it is off |
|---|---|
| `no_aliases` | The interfaces alias `instance( )` and `when( )` so tests read `stub->when( )` |
| `no_dynamic_stuff` | Dynamic calls and RTTI are how the library works |
| `easy_to_find_messages` | Message numbers are chosen through the constants of `ZCX_ATK` |
| `no_inline_in_optional_branches` | It also flags `LOOP AT … INTO DATA( )` and `CATCH … INTO DATA( )` |
| `definitions_top` | Clean ABAP prefers inline declarations |
| `line_break_multiple_parameters` (test classes only) | `with( parameter = … value = … )` reads best on one line |
| `local_testclass_consistency` (local types of `ZCL_ATK` only) | The gateway to the test double framework must be `FOR TESTING` and visible to `ZCL_ATK` |

# Unit tests

The tests of the library are in `zcl_atk.clas.testclasses.abap` and run
against the real `CL_ABAP_TESTDOUBLE`. The doubled types come from package
`ZATK_TEST`; add a method to one of them, or a new fixture object, when a
test needs a parameter shape that does not exist yet.

| Fixture | Shape it provides |
|---|---|
| `ZIF_ATK_TEST_ORDERS` | RETURNING values, a numeric text key, a declared exception |
| `ZIF_ATK_TEST_AUDIT_LOG` | A command without outputs, the target of spies and mocks |
| `ZIF_ATK_TEST_SHAPES` | EXPORTING, CHANGING, generic, fixed-length, decimal, table, structure, reference and optional parameters, and a static method |
| `ZIF_ATK_TEST_ARCHIVE` | An interface that includes `ZIF_ATK_TEST_AUDIT_LOG` as a component |
| `ZCX_ATK_TEST_NOT_FOUND` | A checked exception a doubled method declares |

| Test class | Covers |
|---|---|
| `ltc_doubled_type` | Only interfaces can be doubled; the messages for classes, data types and unknown types; name normalization, suggestions, static methods, the method names ATDF reports |
| `ltc_component_interface` | Methods of a component interface, named with or without the prefix, routed and matched |
| `ltc_value_conversion` | Conversion of rule values to the parameter types, without loss, for inputs, outputs and RETURNING; the reason a value does not fit |
| `ltc_stub` | Rules, matching order, strict stubs, one answer per rule, exceptions |
| `ltc_parameter_shapes` | EXPORTING, CHANGING, RETURNING, generic, structure, table, reference and optional parameters |
| `ltc_spy` | `was_called( )`, `was_not_called( )` and their messages; a spy answers like a stub |
| `ltc_mock` | `expect_call( )`, `verify( )`, undeclared and surplus calls, several expectations per method, answers of expectations |
| `ltc_dummy` | Calls of a dummy |
| `ltc_call_router` | Nothing escapes from the ATDF answer into the code under test |
| `ltc_facade` | The entry points of `ZCL_ATK` |
| `ltc_exception_text` | The three parts of a `ZCX_ATK` text, placeholders, the previous exception |
| `ltc_arguments`, `ltc_name_hint`, `ltc_value_formatter`, `ltc_type_formatter` | How arguments, name suggestions, values and types are shown in messages |

Failures that happen during the act step are reported through a local
interface, so the tests replace the reporter with `ltd_failure_recorder` and
check what was reported instead of failing themselves.

The demo in `ZATK_DEMO` is part of the test run too: both of its test classes
must pass, and the README examples are copied from them.

Not covered by tests, checked by review: the translation of an exception of
`CL_ABAP_TESTDOUBLE` into `ZCX_ATK` in `lth_atdf_gateway` (`atdf_create_failed`,
`atdf_route_failed`), because no doubled interface makes the framework fail
deterministically.

The same tests run off-stack on every push, transpiled to JavaScript; see
[transpiler/README.md](transpiler/README.md) for what is stubbed or patched
there and which tests only run on a real system.

# How it works inside

1. `zcl_atk=>stub( )` describes the type with RTTI and rejects everything that
   is not a global interface, with a reason. Classes are rejected because ABAP
   Cloud code cannot call the methods of the class the test double framework
   generates for a class double by name (step 2).
2. `CL_ABAP_TESTDOUBLE` creates the double. For every method the library
   registers **one** catch-all configuration (`ignore_all_parameters( )`,
   `times( )` and an answer object), followed by a dynamic recording call built
   from RTTI. This is the only place where the configure-then-call two-step
   happens.
3. `when( )`, `with( )` and the other configuration methods only write rules
   into memory, checked against the method with RTTI.
4. At runtime the framework hands every call to the answer object of the
   library, which records the call in a journal (an optional parameter the
   caller left out is recorded as not supplied) and answers with the best rule:
   the most `with( )` conditions win, then an expectation that still waits for
   calls, then the rule written last.
5. `was_called( )` and `verify( )` read the journal.

| Local class | Role |
|---|---|
| `lcl_doubled_type` | RTTI description of the doubled interface and its methods that can be configured; the methods of component interfaces are described from their own interface, so that `get_method_parameter_type` finds their parameters |
| `lcl_doubled_method` | Parameters of one method; checks values against them and builds the recording call |
| `lcl_value_conversion` | Copies a value into another type only when nothing is lost; values of different types are never compared directly, because ABAP cannot catch a conversion error inside a comparison |
| `lcl_arguments` | Parameter names and values of a rule, a check or a recorded call, and the comparison between them |
| `lcl_call_rule` | One rule or expectation: conditions and answer |
| `lcl_rulebook` | The rules of one double; picks the best rule for a call |
| `lcl_call_journal` | Every call the double received, with its arguments |
| `lcl_call_router` | The answer object the test double framework calls |
| `lcl_call_verification` | A `was_called( )` check |
| `lcl_double` | The object behind `ZIF_ATK_DUMMY`, `ZIF_ATK_STUB`, `ZIF_ATK_SPY` and `ZIF_ATK_MOCK` |
| `lcl_unit_failure_reporter` | Reports failures during the act step to ABAP Unit |
| `lcl_value_formatter`, `lcl_type_formatter`, `lcl_name_hint`, `lcl_text` | Values, types (`TY_ORDER_ID (N LENGTH 10)`), name suggestions and texts for the messages |
| `lth_atdf_gateway` | The only class that calls `CL_ABAP_TESTDOUBLE` |
| `lth_double_factory` | Wires the classes above for `ZCL_ATK` |

# Test double framework behaviors the library relies on

The library relies on a few behaviors of `CL_ABAP_TESTDOUBLE` that are not
documented, and its own tests check each of them. If one of these tests fails
on a system, this is where to look:

| Symptom | Behavior it checks | Where to adapt |
|---|---|---|
| Syntax error or warning about test classes in `zcl_atk.clas.locals_imp.abap` | `lth_atdf_gateway` and `lth_double_factory` use `CL_ABAP_TESTDOUBLE`, so they are `FOR TESTING`, but they live in the local implementation include because `ZCL_ATK` needs them | A warning can be ignored. On an error, remove `FOR TESTING` from both classes - the global test class may already make its whole class pool test code |
| `when_returns_double_then_same` fails, or `?=` is rejected at activation | A value of static type `REF TO object` (what `instance( )` returns) can be down-cast into a generically typed target | `lcl_value_conversion=>copies_losslessly` |
| Runtime error `CONVT_NO_NUMBER` in `ZCL_ATK` | A text that is not a number was compared with a number; ABAP cannot catch that inside a comparison | Every comparison of values of different types must go through `lcl_value_conversion=>copies_losslessly` |
| `when_called_thrice_answers` fails | One catch-all configuration with `times( )` answers every call | `lth_atdf_gateway=>route_method` |
| `ltc_component_interface` fails | The name of a component method in the list of methods of the composed interface and in the ATDF answer (`ZIF_COMPONENT~METHOD`), and whether `interfaces` lists nested components | `lcl_doubled_type=>add_methods_of`, `add_component_interfaces`, `method_called_by_atdf` |
| `given_optional_left_out_fails` fails | `is_importing_param_supplied( )` reports an optional parameter the caller left out | `lcl_doubled_method=>is_supplied` |
| Every stub returns initial values, or `internal_error` is reported | The method name the framework passes to the answer, with or without interface prefix | `lcl_doubled_type=>method_called_by_atdf` |
| `given_generic_table_then_works` or `given_generic_input_then_works` fails | The recording call can fill generically typed parameters | `lcl_doubled_method=>concrete_type_for` |
| `when_raises_then_caller_gets` fails | `IF_ABAP_TESTDOUBLE_RESULT->raise_exception( )` records the exception and the framework raises it after the answer | `lcl_call_rule=>answer` |
| A failure during the act step does not show up | `CL_ABAP_UNIT_ASSERT=>fail( quit = no )` inside the answer object | `lcl_unit_failure_reporter` |
| The three parts of a message run into one line, or a `#` shows between them | The ABAP Unit view of the tool in use does not render `cl_abap_char_utilities=>newline` inside a failure text | `zcx_atk=>line_break` |
| abapGit: *ABAP Language Version of linked package is not compatible with repository settings*, or an object *has ABAP language version … but repository is set to …* | The packages were created with *Standard ABAP*, for example by abapGit itself | Set *ABAP for Cloud Development* on `ZATK`, `ZATK_TEST` and `ZATK_DEMO` in ADT and pull again |

# Releasing

Versions follow [Semantic Versioning](https://semver.org). One version covers
the whole repository. The public API is `ZCL_ATK`, the `ZIF_ATK_*` interfaces,
`ZCX_ATK` with its constants, and the message texts of `ZATK`.

| Change | Version part |
|---|---|
| A public method, parameter, constant or interface is removed or renamed, or a signature changes incompatibly | MAJOR |
| A method, double, matcher or message is added; behavior changes compatibly | MINOR |
| A bug is fixed, a message is reworded, documentation or tests change | PATCH |

From `1.0.0` on, an incompatible change to the public API is a MAJOR release.

To make a release:

1. Make sure abaplint and the off-stack unit tests are green on `main`
   (both workflows), and run the unit tests of `ZATK` and its sub-packages on
   a real system: every test must pass, including the ones the transpiler
   skips (`transpiler/README.md`, *Skipped tests*).
2. In [CHANGELOG.md](CHANGELOG.md), rename **Unreleased** to the new version
   and date (`## [1.0.0] - 2026-10-15`) and start a new, empty **Unreleased**
   section above it. Set the same version in `package.json`.
3. Commit, then tag the commit `vMAJOR.MINOR.PATCH` and push the tag.
4. Create a GitHub release from the tag with the CHANGELOG section as text.
