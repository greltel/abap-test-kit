/*
 * Fetches the ABAP side of the transpiler runtime into deps/ at the commits pinned below,
 * so that every transpile - local or CI - builds against the same revisions:
 *   - open-abap-core: the SAP standard classes (RTTI, ABAP Unit, the ABAP Test Double Framework, ...)
 *   - open-abap-xco:  the XCO classes ATK reads the call stack with
 *
 *   node transpiler/fetch_open_abap_core.mjs
 *
 * To move to a newer revision: change the pinned commit, run this script and run the tests.
 */
import {execSync} from "child_process";
import fs from "fs";
import path from "path";
import {fileURLToPath} from "url";

const DEPENDENCIES = [
  {
    name: "open-abap-core",
    repository: "https://github.com/open-abap/open-abap-core.git",
    commit: "0c495ec0d059be72adc76b97848c6cc5ad8a1fe8", // 2026-10-10, with CL_ABAP_TESTDOUBLE (#1296)
  },
  {
    name: "open-abap-xco",
    repository: "https://github.com/open-abap/open-abap-xco.git",
    commit: "1bd58800c12e7abd051ec79ef9420f2e1098d5f4", // 2026-10-06
  },
];

const here = path.dirname(fileURLToPath(import.meta.url));

function git(args, cwd) {
  return execSync(`git ${args}`, {cwd, stdio: ["ignore", "pipe", "inherit"]}).toString().trim();
}

function fetchDependency({name, repository, commit}) {
  const target = path.resolve(here, "..", "deps", name);

  if (fs.existsSync(path.join(target, ".git"))) {
    if (git("rev-parse HEAD", target) === commit) {
      console.log(`${name} already at ${commit.slice(0, 12)}`);
      return;
    }
    console.log(`${name} is at another revision, refreshing`);
    fs.rmSync(target, {recursive: true, force: true});
  }

  fs.mkdirSync(target, {recursive: true});
  git("init --quiet", target);
  git(`remote add origin ${repository}`, target);
  git(`fetch --quiet --depth 1 origin ${commit}`, target);
  git("checkout --quiet FETCH_HEAD", target);
  console.log(`${name} fetched at ${commit.slice(0, 12)}`);
}

for (const dependency of DEPENDENCIES) {
  fetchDependency(dependency);
}
