import { describe, expect, it } from "vitest";
import { evaluateSafeCondition } from "./SafeConditionEvaluator.js";

describe("SafeConditionEvaluator", () => {
  it("evaluates supported boolean expressions", () => {
    const value = evaluateSafeCondition("userInput == 'ok' && retries < 3", {
      userInput: "ok",
      retries: 2,
    });
    expect(value).toBe(true);
  });

  it("rejects executable javascript syntax", () => {
    expect(() => evaluateSafeCondition("process.exit()", {})).toThrow(/Condition|Unsupported|Unexpected|Expected/);
    expect(() => evaluateSafeCondition("globalThis.constructor.constructor('return 1')()", {})).toThrow();
  });
});

