/*
 * Runtime setup for the transpiled unit tests. Referenced from abap_transpile.json
 * (options.setup) and called by the generated output/init.mjs before any ABAP object
 * is loaded.
 *
 * Its only job: load the ATDF stand-in (atdf/atdf_runtime.mjs), which CL_ABAP_TESTDOUBLE in
 * atdf/ delegates to. Delete this file, options.setup in abap_transpile.json and atdf/ once
 * open-abap-core ships CL_ABAP_TESTDOUBLE (open-abap/open-abap-core#1296).
 */

/** runs before any ABAP object is loaded */
export async function setup() {
  // resolved relative to this file, as the transpiler's output layout changes between versions
  globalThis.atdfRuntime = await import("./atdf/atdf_runtime.mjs");
}
