/*
 * Stand-in for SAP's ABAP Test Double Framework (CL_ABAP_TESTDOUBLE) inside the
 * abaplint transpiler runtime (open-abap). open-abap-core does not ship the ATDF,
 * and the ATDF cannot be written in ABAP: it needs to build an object that implements
 * an arbitrary interface at runtime. Here that is a plain JavaScript class built from
 * the interface metadata the transpiler emits (abap.Classes[<INTERFACE>].METHODS).
 *
 * Scope: exactly what the ABAP Test Kit needs, nothing more.
 *   - create( object_name )                       interfaces only
 *   - configure_call( double )->ignore_all_parameters( )->times( n )->set_answer( answer )
 *     followed by the ATDF two-step: the next call of a method on the double registers
 *     the configuration for that method instead of executing it
 *   - configure_call( double )->returning( value ) / ->raise_exception( exception )
 *   - the answer receives IF_ABAP_TESTDOUBLE_ARGUMENTS and IF_ABAP_TESTDOUBLE_RESULT
 *   - a configuration applies to calls whose importing arguments equal the ones of the
 *     registration call, unless ignore_all_parameters( ) / ignore_parameter( ) say otherwise
 *   - and_expect( )->is_called_once( ) / is_called_times( n ) / is_never_called( ), checked
 *     by verify_expectations( double ), which fails the test through cl_abap_unit_assert
 *
 * Not implemented: doubling classes, matchers, events, set_parameter( ).
 *
 * The entry points are called from the @KERNEL lines of cl_abap_testdouble.clas.abap
 * in this folder.
 */

const GENERIC_PARAMETER_TYPES = new Set([
  "AnyType", "CLikeType", "CSequenceType", "DataType", "SimpleType", "NumericGenericType",
  "XSequenceType", "XGenericType", "GenericObjectReferenceType", "UnknownType", "VoidType",
]);

/** state of every double, keyed by the raw double instance */
const doubles = new WeakMap();

/** configuration built by configure_call( ) that waits for its registration call */
let pendingConfiguration = undefined;

// ---------------------------------------------------------------- helpers

function rawObject(reference) {
  // an ABAPObject wrapper or already the raw instance
  return reference !== undefined && reference !== null && typeof reference.get === "function"
    && !(reference instanceof abap.types.DataReference)
    ? reference.get()
    : reference;
}

function wrap(instance, interfaceName) {
  return new abap.types.ABAPObject({
    qualifiedName: interfaceName,
    RTTIName: "\\INTERFACE=" + interfaceName,
  }).set(instance);
}

function textOf(value) {
  if (value === undefined || value === null) {
    return "";
  }
  if (typeof value === "string") {
    return value;
  }
  if (value instanceof abap.types.FieldSymbol) {
    return textOf(value.getPointer());
  }
  return String(value.get());
}

function parameterName(value) {
  return textOf(value).trim().toUpperCase();
}

function resolvePointer(value) {
  return value instanceof abap.types.FieldSymbol ? value.getPointer() : value;
}

function toAbapValue(value) {
  if (typeof value === "string") {
    return new abap.types.String().set(value);
  }
  if (typeof value === "number") {
    return new abap.types.Integer().set(value);
  }
  return value;
}

function isGenericTable(type, parameter) {
  return parameter.type_name === "TableType"
    && typeof type.getRowType === "function"
    && type.getRowType() instanceof abap.types.Character
    && type.getRowType().getQualifiedName?.() === undefined;
}

/** copy of an argument, converted to the formal parameter type like a real method call */
function copyAsFormalType(value, parameter) {
  const source = toAbapValue(resolvePointer(value));
  const formal = parameter.type();
  if (GENERIC_PARAMETER_TYPES.has(parameter.type_name) || isGenericTable(formal, parameter)) {
    return typeof source.clone === "function" ? source.clone() : source;
  }
  if (source instanceof abap.types.ABAPObject || formal instanceof abap.types.ABAPObject) {
    return typeof source.clone === "function" ? source.clone() : source;
  }
  formal.set(source);
  return formal;
}

function findParameter(parameters, name, kinds) {
  const upper = parameterName(name);
  const parameter = parameters[upper];
  if (parameter === undefined || !kinds.includes(parameter.parm_kind)) {
    return undefined;
  }
  return {name: upper, meta: parameter};
}

function returningParameter(parameters) {
  for (const [name, meta] of Object.entries(parameters)) {
    if (meta.parm_kind === "R") {
      return {name, meta};
    }
  }
  return undefined;
}

function initialReturnValue(parameters) {
  const returning = returningParameter(parameters);
  return returning === undefined ? undefined : returning.meta.type();
}

async function raiseAtdfError(text) {
  const exceptionClass = abap.Classes["CX_ATD_EXCEPTION_CORE"];
  if (exceptionClass === undefined) {
    throw new Error("ATDF stand-in: " + text);
  }
  const exception = new exceptionClass();
  await exception.constructor_({});
  exception.ATDF_TEXT = text;
  throw exception;
}

// ---------------------------------------------------------------- IF_ABAP_TESTDOUBLE_ARGUMENTS

class AtdfArguments {
  static INTERNAL_TYPE = "CLAS";
  static INTERNAL_NAME = "ATDF_STANDIN_ARGUMENTS";
  static IMPLEMENTED_INTERFACES = ["IF_ABAP_TESTDOUBLE_ARGUMENTS"];
  static ATTRIBUTES = {};
  static METHODS = {};

  constructor(parameters, input) {
    this.INTERNAL_ID = abap.internalIdCounter++;
    this.parameters = parameters;
    this.input = input ?? {};
    this.position = 0;
    this.names = Object.keys(parameters).filter(name => parameters[name].parm_kind !== "R");
  }

  supplied(name) {
    return this.input[name.toLowerCase()] !== undefined;
  }

  async if_abap_testdouble_arguments$get_param_importing(INPUT) {
    const parameter = findParameter(this.parameters, INPUT.name, ["I"]);
    if (parameter === undefined) {
      await raiseAtdfError("unknown importing parameter " + parameterName(INPUT.name));
    }
    const reference = new abap.types.DataReference(parameter.meta.type());
    if (this.supplied(parameter.name)) {
      reference.assign(copyAsFormalType(this.input[parameter.name.toLowerCase()], parameter.meta));
    } else {
      reference.assign(parameter.meta.type());
    }
    return reference;
  }

  async if_abap_testdouble_arguments$get_param_changing(INPUT) {
    const parameter = findParameter(this.parameters, INPUT.name, ["C"]);
    if (parameter === undefined) {
      await raiseAtdfError("unknown changing parameter " + parameterName(INPUT.name));
    }
    const reference = new abap.types.DataReference(parameter.meta.type());
    const actual = resolvePointer(this.input[parameter.name.toLowerCase()]);
    reference.assign(actual !== undefined ? actual : parameter.meta.type());
    return reference;
  }

  async if_abap_testdouble_arguments$is_importing_param_supplied(INPUT) {
    const parameter = findParameter(this.parameters, INPUT.name, ["I"]);
    if (parameter === undefined) {
      await raiseAtdfError("unknown importing parameter " + parameterName(INPUT.name));
    }
    return this.supplied(parameter.name) ? abap.builtin.abap_true : abap.builtin.abap_false;
  }

  async if_abap_testdouble_arguments$is_changing_param_supplied(INPUT) {
    const parameter = findParameter(this.parameters, INPUT.name, ["C"]);
    if (parameter === undefined) {
      await raiseAtdfError("unknown changing parameter " + parameterName(INPUT.name));
    }
    return this.supplied(parameter.name) ? abap.builtin.abap_true : abap.builtin.abap_false;
  }

  async if_abap_testdouble_arguments$has_next_parameter() {
    return this.position < this.names.length ? abap.builtin.abap_true : abap.builtin.abap_false;
  }

  async if_abap_testdouble_arguments$next_parameter(INPUT) {
    if (this.position >= this.names.length) {
      await raiseAtdfError("no next parameter");
    }
    const name = this.names[this.position];
    this.position = this.position + 1;
    INPUT?.name?.set(name);
    INPUT?.kind?.set(this.parameters[name].parm_kind);
    INPUT?.ignore?.set("");
  }

  async if_abap_testdouble_arguments$reset_iterator() {
    this.position = 0;
  }

  async if_abap_testdouble_arguments$size_of() {
    return new abap.types.Integer().set(this.names.length);
  }
}

// ---------------------------------------------------------------- IF_ABAP_TESTDOUBLE_RESULT

class AtdfResult {
  static INTERNAL_TYPE = "CLAS";
  static INTERNAL_NAME = "ATDF_STANDIN_RESULT";
  static IMPLEMENTED_INTERFACES = ["IF_ABAP_TESTDOUBLE_RESULT"];
  static ATTRIBUTES = {};
  static METHODS = {};

  constructor(parameters, input) {
    this.INTERNAL_ID = abap.internalIdCounter++;
    this.parameters = parameters;
    this.input = input ?? {};
    this.returning = undefined;
    this.exception = undefined;
  }

  async writeOutput(INPUT, kind, label) {
    const parameter = findParameter(this.parameters, INPUT.name, [kind]);
    if (parameter === undefined) {
      await raiseAtdfError(parameterName(INPUT.name) + " is not " + label + " parameter of the method");
    }
    const target = resolvePointer(this.input[parameter.name.toLowerCase()]);
    if (target === undefined) {
      return; // the caller did not ask for it
    }
    target.set(toAbapValue(resolvePointer(INPUT.value)));
  }

  async if_abap_testdouble_result$set_param_exporting(INPUT) {
    await this.writeOutput(INPUT, "E", "an exporting");
  }

  async if_abap_testdouble_result$set_param_changing(INPUT) {
    await this.writeOutput(INPUT, "C", "a changing");
  }

  async if_abap_testdouble_result$set_param_returning(INPUT) {
    const returning = returningParameter(this.parameters);
    if (returning === undefined) {
      await raiseAtdfError("the method has no returning parameter");
    }
    this.returning = copyAsFormalType(INPUT.value, returning.meta);
  }

  async if_abap_testdouble_result$raise_exception(INPUT) {
    this.exception = rawObject(INPUT.exception);
  }
}

// ---------------------------------------------------------------- IF_ABAP_TESTDOUBLE_HANDLE

class AtdfHandle {
  static INTERNAL_TYPE = "CLAS";
  static INTERNAL_NAME = "ATDF_STANDIN_HANDLE";
  static IMPLEMENTED_INTERFACES = ["IF_ABAP_TESTDOUBLE_HANDLE"];
  static ATTRIBUTES = {};
  static METHODS = {};

  constructor(double) {
    this.INTERNAL_ID = abap.internalIdCounter++;
    this.double = double;
  }
}

// ---------------------------------------------------------------- IF_ABAP_TESTDOUBLE_CONFIG

class AtdfConfiguration {
  static INTERNAL_TYPE = "CLAS";
  static INTERNAL_NAME = "ATDF_STANDIN_CONFIGURATION";
  static IMPLEMENTED_INTERFACES = ["IF_ABAP_TESTDOUBLE_CONFIG"];
  static ATTRIBUTES = {};
  static METHODS = {};

  constructor(double) {
    this.INTERNAL_ID = abap.internalIdCounter++;
    this.double = double;
    this.answer = undefined;
    this.returning = undefined;
    this.exception = undefined;
    this.times = 1;
    this.ignoreAll = false;
    this.ignored = new Set();
    this.expectedCalls = undefined; // set by and_expect( )
    this.methodName = undefined;    // INTERFACE~METHOD, set by the registration call
    this.registeredArguments = {};  // importing arguments of the registration call
    this.calls = 0;
  }

  self() {
    return wrap(this, "IF_ABAP_TESTDOUBLE_CONFIG");
  }

  /** the registration call: remember the method and its importing arguments */
  register(methodName, parameters, input) {
    this.methodName = methodName;
    for (const [name, meta] of Object.entries(parameters)) {
      const value = input?.[name.toLowerCase()];
      if (meta.parm_kind === "I" && value !== undefined) {
        this.registeredArguments[name] = copyAsFormalType(value, meta);
      }
    }
  }

  matches(parameters, input) {
    if (this.ignoreAll) {
      return true;
    }
    for (const [name, meta] of Object.entries(parameters)) {
      if (meta.parm_kind !== "I" || this.ignored.has(name)) {
        continue;
      }
      const registered = this.registeredArguments[name];
      const actual = input?.[name.toLowerCase()];
      if (registered === undefined && actual === undefined) {
        continue;
      }
      if (registered === undefined || actual === undefined) {
        return false;
      }
      if (!abap.compare.eq(registered, copyAsFormalType(actual, meta))) {
        return false;
      }
    }
    return true;
  }

  async if_abap_testdouble_config$ignore_all_parameters() {
    this.ignoreAll = true;
    return this.self();
  }

  async if_abap_testdouble_config$ignore_parameter(INPUT) {
    this.ignored.add(parameterName(INPUT.name));
    return this.self();
  }

  async if_abap_testdouble_config$set_parameter() {
    return this.self();
  }

  async if_abap_testdouble_config$set_matcher() {
    return this.self();
  }

  async if_abap_testdouble_config$times(INPUT) {
    this.times = Number(textOf(INPUT.number));
    return this.self();
  }

  async if_abap_testdouble_config$returning(INPUT) {
    this.returning = toAbapValue(resolvePointer(INPUT.value));
    return this.self();
  }

  async if_abap_testdouble_config$raise_exception(INPUT) {
    this.exception = rawObject(INPUT.exception_object);
    return this.self();
  }

  async if_abap_testdouble_config$raise_event() {
    await raiseAtdfError("raise_event is not supported by the ATDF stand-in");
  }

  async if_abap_testdouble_config$and_expect() {
    return wrap(new AtdfVerification(this), "IF_ABAP_TESTDOUBLE_VERIFY");
  }

  async if_abap_testdouble_config$set_answer(INPUT) {
    this.answer = rawObject(INPUT.answer);
  }
}

// ---------------------------------------------------------------- IF_ABAP_TESTDOUBLE_VERIFY

class AtdfVerification {
  static INTERNAL_TYPE = "CLAS";
  static INTERNAL_NAME = "ATDF_STANDIN_VERIFICATION";
  static IMPLEMENTED_INTERFACES = ["IF_ABAP_TESTDOUBLE_VERIFY"];
  static ATTRIBUTES = {};
  static METHODS = {};

  constructor(configuration) {
    this.INTERNAL_ID = abap.internalIdCounter++;
    this.configuration = configuration;
  }

  async if_abap_testdouble_verify$is_called_once() {
    this.configuration.expectedCalls = 1;
  }

  async if_abap_testdouble_verify$is_called_times(INPUT) {
    this.configuration.expectedCalls = Number(textOf(INPUT.times));
  }

  async if_abap_testdouble_verify$is_never_called() {
    this.configuration.expectedCalls = 0;
  }
}

// ---------------------------------------------------------------- the double

async function dispatch(double, interfaceName, methodName, meta, INPUT) {
  const state = doubles.get(double);
  const parameters = meta.parameters ?? {};
  const qualifiedName = interfaceName + "~" + methodName;
  if (pendingConfiguration !== undefined && pendingConfiguration.double === double) {
    // ATDF two-step: this call only registers the configuration
    pendingConfiguration.register(qualifiedName, parameters, INPUT);
    state.configurations.push(pendingConfiguration);
    pendingConfiguration = undefined;
    return undefined;
  }

  const configuration = state.configurations.findLast(c =>
    c.methodName === qualifiedName && c.calls < c.times && c.matches(parameters, INPUT));
  if (configuration === undefined) {
    return initialReturnValue(parameters);
  }
  configuration.calls = configuration.calls + 1;

  if (configuration.answer !== undefined) {
    const args = new AtdfArguments(parameters, INPUT);
    const result = new AtdfResult(parameters, INPUT);
    await configuration.answer.if_abap_testdouble_answer$answer({
      arguments: wrap(args, "IF_ABAP_TESTDOUBLE_ARGUMENTS"),
      double_handle: wrap(state.handle, "IF_ABAP_TESTDOUBLE_HANDLE"),
      method_name: new abap.types.Character(61, {qualifiedName: "abap_methname"}).set(qualifiedName),
      result: wrap(result, "IF_ABAP_TESTDOUBLE_RESULT"),
    });
    if (result.exception !== undefined) {
      throw result.exception;
    }
    return result.returning !== undefined ? result.returning : initialReturnValue(parameters);
  }

  if (configuration.exception !== undefined) {
    throw configuration.exception;
  }
  if (configuration.returning !== undefined) {
    const returning = returningParameter(parameters);
    return returning === undefined
      ? undefined
      : copyAsFormalType(configuration.returning, returning.meta);
  }
  return initialReturnValue(parameters);
}

const doubleClasses = new Map();

/**
 * The interface and every interface it includes (transitively), each with its methods. The
 * transpiler emits the component interfaces only when setup.mjs added IMPLEMENTED_INTERFACES.
 */
function interfaceFamily(interfaceName, interfaceClass) {
  const family = [];
  const seen = new Set();
  const visit = (name, definition) => {
    if (seen.has(name) || definition === undefined) {
      return;
    }
    seen.add(name);
    family.push({name, methods: definition.METHODS ?? {}});
    for (const component of definition.IMPLEMENTED_INTERFACES ?? []) {
      visit(component, abap.Classes[component]);
    }
  };
  visit(interfaceName, interfaceClass);
  return family;
}

function doubleClassFor(interfaceName, interfaceClass) {
  let doubleClass = doubleClasses.get(interfaceName);
  if (doubleClass !== undefined) {
    return doubleClass;
  }
  const family = interfaceFamily(interfaceName, interfaceClass);
  doubleClass = class {
    static INTERNAL_TYPE = "CLAS";
    static INTERNAL_NAME = "ATDF_DOUBLE_" + interfaceName;
    static IMPLEMENTED_INTERFACES = family.map(member => member.name);
    static ATTRIBUTES = {};
    static METHODS = interfaceClass.METHODS ?? {};

    constructor() {
      this.INTERNAL_ID = abap.internalIdCounter++;
    }

    async constructor_() {
      return this;
    }
  };
  Object.defineProperty(doubleClass, "name", {value: "ATDF_DOUBLE_" + interfaceName});
  // a method of a component interface is called as component$method and reported to the
  // answer as COMPONENT~METHOD, the name it has in the class ATDF generates
  for (const member of family) {
    const prefix = member.name.toLowerCase() + "$";
    for (const [methodName, meta] of Object.entries(member.methods)) {
      doubleClass.prototype[prefix + methodName.toLowerCase()] = async function (INPUT) {
        return dispatch(this, member.name, methodName, meta, INPUT);
      };
    }
  }
  doubleClasses.set(interfaceName, doubleClass);
  return doubleClass;
}

// ---------------------------------------------------------------- CL_ABAP_TESTDOUBLE entry points

/** cl_abap_testdouble=>create( object_name ) */
export async function create(objectName) {
  const interfaceName = textOf(objectName).trim().toUpperCase();
  const interfaceClass = abap.Classes[interfaceName];
  if (interfaceClass === undefined) {
    await raiseAtdfError(interfaceName + " does not exist");
  }
  if (interfaceClass.INTERNAL_TYPE !== "INTF") {
    await raiseAtdfError(interfaceName + " is not an interface; the ATDF stand-in doubles interfaces only");
  }
  const double = new (doubleClassFor(interfaceName, interfaceClass))();
  doubles.set(double, {
    interfaceName: interfaceName,
    configurations: [],
    handle: new AtdfHandle(double),
  });
  return new abap.types.ABAPObject({
    qualifiedName: interfaceName,
    RTTIName: "\\INTERFACE=" + interfaceName,
  }).set(double);
}

/** cl_abap_testdouble=>configure_call( double ) */
export async function configureCall(doubleReference) {
  const double = rawObject(doubleReference);
  if (double === undefined || !doubles.has(double)) {
    await raiseAtdfError("configure_call: the object is not a test double of the ATDF stand-in");
  }
  pendingConfiguration = new AtdfConfiguration(double);
  return pendingConfiguration.self();
}

/** cl_abap_testdouble=>verify_expectations( double ) */
export async function verifyExpectations(doubleReference) {
  const double = rawObject(doubleReference);
  if (double === undefined || !doubles.has(double)) {
    await raiseAtdfError("verify_expectations: the object is not a test double of the ATDF stand-in");
  }
  const state = doubles.get(double);
  for (const configuration of state.configurations) {
    if (configuration.expectedCalls === undefined || configuration.calls === configuration.expectedCalls) {
      continue;
    }
    const message = `${configuration.methodName}: expected `
      + `${configuration.expectedCalls} call(s), got ${configuration.calls}`;
    await abap.Classes["CL_ABAP_UNIT_ASSERT"].fail({msg: new abap.types.String().set(message)});
  }
}
