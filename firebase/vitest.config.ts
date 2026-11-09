import { defineConfig } from "vitest/config";

// Rules tests share one emulator, so run files one at a time.
export default defineConfig({
  test: {
    include: ["tests/**/*.test.ts"],
    fileParallelism: false,
    testTimeout: 20_000,
    hookTimeout: 30_000,
  },
});
