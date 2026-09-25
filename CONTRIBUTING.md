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
| `src/test/` | `ZATK_TEST` | Interfaces and an exception used by the unit tests of `ZCL_ATK`, and a class they check is rejected |
| `src/demo/` | `ZATK_DEMO` | The order service of the [Before and After](README.md#before-and-after) section, tested once with the classic framework and once with the library |
| `abaplint-stubs/` | - | Minimal definitions of SAP objects for abaplint; abapGit ignores the folder |
| `.github/workflows/` | - | The abaplint run on every push and pull request |

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
  details are 201-299. Exceptions of the test double framework are caught and
  translated, never passed on
* Every change comes with unit tests, and every new or changed public method
  with a README section and a CHANGELOG entry

# Static checks

[abaplint](https://abaplint.org) runs in ABAP Cloud mode on every push and pull
request (`.github/workflows/abaplint.yml`). To run it locally:

```sh
npx @abaplint/cli@latest abaplint.json
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

| Test class | Covers |
|---|---|
| `ltc_doubled_type` | Only interfaces can be doubled; the messages for classes, data types and unknown types |
| `ltc_value_conversion` | Conversion of rule values to the parameter types, without loss |
| `ltc_stub` | Rules, matching order, strict stubs |
| `ltc_parameter_shapes` | EXPORTING, CHANGING, RETURNING, generic and reference parameters |
| `ltc_spy` | `was_called( )`, `was_not_called( )` and their messages |
| `ltc_mock` | `expect_call( )`, `verify( )` and undeclared calls |
| `ltc_dummy` | Calls of a dummy |
| `ltc_facade` | The entry points of `ZCL_ATK` |
| `ltc_exception_text` | The three parts of a `ZCX_ATK` text |
| `ltc_value_formatter` | How values are shown in messages |

Failures that happen during the act step are reported through a local
interface, so the tests replace the reporter with `ltd_failure_recorder` and
check what was reported instead of failing themselves.

The demo in `ZATK_DEMO` is part of the test run too: both of its test classes
must pass, and the README examples are copied from them.

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
   library, which records the call in a journal and answers with the best rule.
5. `was_called( )` and `verify( )` read the journal.

| Local class | Role |
|---|---|
| `lcl_doubled_type` | RTTI description of the doubled interface and its methods that can be configured |
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
| `lcl_value_formatter`, `lcl_name_hint`, `lcl_text` | Values, name suggestions and texts for the messages |
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
| Every stub returns initial values, or `internal_error` is reported | The method name the framework passes to the answer, with or without interface prefix | `lcl_doubled_type=>method_called_by_atdf` |
| `given_generic_table_then_works` or `given_generic_input_then_works` fails | The recording call can fill generically typed parameters | `lcl_doubled_method=>concrete_type_for` |
| `when_raises_then_caller_gets` fails | `IF_ABAP_TESTDOUBLE_RESULT->raise_exception( )` records the exception and the framework raises it after the answer | `lcl_call_rule=>answer` |
| A failure during the act step does not show up | `CL_ABAP_UNIT_ASSERT=>fail( quit = no )` inside the answer object | `lcl_unit_failure_reporter` |
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

Before `1.0.0` the public API can still change in a MINOR release; such changes
are listed under **Changed** in the CHANGELOG.

To make a release:

1. Make sure abaplint and all unit tests pass on `main`.
2. In [CHANGELOG.md](CHANGELOG.md), rename **Unreleased** to the new version
   and date (`## [0.2.0] - 2026-10-15`) and start a new, empty **Unreleased**
   section above it.
3. Commit, then tag the commit `vMAJOR.MINOR.PATCH` and push the tag.
4. Create a GitHub release from the tag with the CHANGELOG section as text.
