/*
 * Fetches open-abap-core (the ABAP side of the transpiler runtime) into deps/open-abap-core
 * at the commit pinned below, so that every transpile - local or CI - builds against the
 * same revision the patches in transpiler/open-abap-patches were written for.
 *
 *   node transpiler/fetch_open_abap_core.mjs
 *
 * To move to a newer revision: change PINNED_COMMIT, run this script, run the tests, and
 * re-check each patched file against its new upstream version.
 */
import {execSync} from "child_process";
import fs from "fs";
import path from "path";
import {fileURLToPath} from "url";

const REPOSITORY = "https://github.com/open-abap/open-abap-core.git";
const PINNED_COMMIT = "3f22182feb3ac9ffa6d4178e147961df084a6271"; // 2026-09-24

const here = path.dirname(fileURLToPath(import.meta.url));
const target = path.resolve(here, "..", "deps", "open-abap-core");

function git(args, cwd) {
  return execSync(`git ${args}`, {cwd, stdio: ["ignore", "pipe", "inherit"]}).toString().trim();
}

if (fs.existsSync(path.join(target, ".git"))) {
  if (git("rev-parse HEAD", target) === PINNED_COMMIT) {
    console.log(`open-abap-core already at ${PINNED_COMMIT.slice(0, 12)}`);
    process.exit(0);
  }
  console.log("open-abap-core is at another revision, refreshing");
  fs.rmSync(target, {recursive: true, force: true});
}

fs.mkdirSync(target, {recursive: true});
git("init --quiet", target);
git(`remote add origin ${REPOSITORY}`, target);
git(`fetch --quiet --depth 1 origin ${PINNED_COMMIT}`, target);
git("checkout --quiet FETCH_HEAD", target);
console.log(`open-abap-core fetched at ${PINNED_COMMIT.slice(0, 12)}`);
