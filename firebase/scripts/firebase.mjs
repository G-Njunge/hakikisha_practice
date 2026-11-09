// Runs the Firebase CLI from this folder. For `emulators:start` it keeps data
// between runs: everything is saved to ./emulator-data on exit (Ctrl+C) and
// loaded back next time. The first run has nothing to load, and `--import`
// fails on a missing folder, so it's only added once data exists. Delete
// emulator-data/ to start clean, then `npm run seed`.

import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
const dataDir = "./emulator-data";
const args = process.argv.slice(2);

if (args[0] === "emulators:start") {
  args.push(`--export-on-exit=${dataDir}`);
  if (existsSync(path.join(root, dataDir))) {
    args.push(`--import=${dataDir}`);
  } else {
    console.log("No saved emulator data yet: starting empty. Run `npm run seed` once the emulators are up.");
  }
}

const quoted = args.map((arg) => (/\s/.test(arg) ? `"${arg}"` : arg));
const child = spawn("firebase", quoted, { cwd: root, stdio: "inherit", shell: true });
child.on("exit", (code) => process.exit(code ?? 0));
