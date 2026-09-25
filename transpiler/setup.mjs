/*
 * Runtime setup for the transpiled unit tests. Referenced from abap_transpile.json
 * (options.setup) and called by the generated output/init.mjs before any ABAP object
 * is loaded. Fills gaps of @abaplint/runtime that the ABAP Test Kit runs into.
 */

/** Levenshtein distance, the ABAP built-in distance( val1 = … val2 = … [max = …] ) */
function levenshtein(a, b) {
  if (a === b) {
    return 0;
  }
  const rows = a.length + 1;
  const cols = b.length + 1;
  let previous = Array.from({length: cols}, (_, j) => j);
  for (let i = 1; i < rows; i++) {
    const current = [i];
    for (let j = 1; j < cols; j++) {
      const substitution = previous[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1);
      current[j] = Math.min(previous[j] + 1, current[j - 1] + 1, substitution);
    }
    previous = current;
  }
  return previous[cols - 1];
}

function text(value) {
  if (value === undefined || value === null) {
    return "";
  }
  if (typeof value === "string") {
    return value;
  }
  if (value instanceof abap.types.FieldSymbol) {
    return text(value.getPointer());
  }
  if (value instanceof abap.types.Character) {
    return value.getTrimEnd();
  }
  return String(value.get());
}

function distance(input) {
  let result = levenshtein(text(input.val1), text(input.val2));
  if (input.max !== undefined) {
    const max = Number(text(input.max));
    if (max > 0 && result > max) {
      result = max;
    }
  }
  return new abap.types.Integer().set(result);
}

/*
 * Gap of @abaplint/runtime: "numc = decfloat34" (and numc against p / f) compares the
 * strings "0000004711" and "4711" instead of the numbers. ABAP compares numerically.
 * ATK relies on that in lcl_value_conversion=>is_same_value.
 */
function numericValue(value) {
  const types = globalThis.abap.types;
  if (value instanceof types.Numc) {
    return parseInt(value.get(), 10) || 0;
  }
  if (value instanceof types.DecFloat34 || value instanceof types.Float) {
    return value.getRaw();
  }
  if (value instanceof types.Packed || value instanceof types.Integer) {
    return value.get();
  }
  return undefined;
}

function patchNumcComparison(abap) {
  const types = abap.types;
  const original = abap.compare.eq;
  const isDecimal = (v) => v instanceof types.DecFloat34 || v instanceof types.Float || v instanceof types.Packed;
  const eq = (left, right) => {
    const l = left instanceof types.FieldSymbol ? left.getPointer() : left;
    const r = right instanceof types.FieldSymbol ? right.getPointer() : right;
    if ((l instanceof types.Numc && isDecimal(r)) || (r instanceof types.Numc && isDecimal(l))) {
      return numericValue(l) === numericValue(r);
    }
    return original(left, right);
  };
  // abap.compare is a module namespace with read-only bindings, so it is replaced as a whole
  abap.compare = Object.assign({}, abap.compare, {eq, ne: (left, right) => !eq(left, right)});
}

/*
 * Gap of @abaplint/runtime: "IS INSTANCE OF <interface>" is a plain JavaScript instanceof,
 * which is false for every object because no class extends an interface. This checks the
 * IMPLEMENTED_INTERFACES of the object's class and of its super classes instead.
 */
function patchInstanceOf(abap) {
  const original = abap.compare.instance_of;
  const instance_of = (value, cname) => {
    const object = value?.get?.();
    if (object === undefined || object === null || cname?.INTERNAL_TYPE !== "INTF") {
      return original(value, cname);
    }
    for (let clas = object.constructor; clas !== undefined && clas !== null; clas = clas.STATIC_SUPER) {
      if ((clas.IMPLEMENTED_INTERFACES ?? []).includes(cname.INTERNAL_NAME)) {
        return true;
      }
    }
    return false;
  };
  abap.compare = Object.assign({}, abap.compare, {instance_of});
}

/** runs before any ABAP object is loaded */
export async function setup(abap) {
  if (abap.builtin.distance === undefined) {
    abap.builtin.distance = distance;
  }
  patchNumcComparison(abap);
  patchInstanceOf(abap);
}

/*
 * Gap of @abaplint/transpiler: TYPES BEGIN OF ENUM emits every member as an Integer with
 * no value, so all members compare equal, and inside a local interface the members are
 * emitted as lif_role.lif_role$mock but referenced as lif_role.mock. ATK keeps the role of
 * a double in the local interface LIF_ROLE of ZCL_ATK. Keep this list in sync with it.
 */
const LOCAL_ENUMS = [
  {owner: "CLAS-ZCL_ATK-LIF_ROLE", prefix: "lif_role$", members: ["dummy", "stub", "spy", "mock"]},
];

/** runs after every ABAP object is loaded, before the tests */
export async function afterLoad() {
  for (const definition of LOCAL_ENUMS) {
    const owner = globalThis.abap.Classes[definition.owner];
    if (owner === undefined) {
      continue;
    }
    definition.members.forEach((member, value) => {
      const constant = new globalThis.abap.types.Integer({qualifiedName: "I"}).set(value);
      owner[member] = constant;
      owner[definition.prefix + member] = constant;
    });
  }
}
