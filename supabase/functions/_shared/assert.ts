// Minimal assertions for the function tests. CI runs `deno test --no-remote`,
// so tests import nothing from the network (no jsr:@std/assert).

function equal(a: unknown, b: unknown): boolean {
  if (Object.is(a, b)) return true;
  if (typeof a !== "object" || typeof b !== "object" || !a || !b) return false;
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  const ka = Object.keys(a), kb = Object.keys(b);
  if (ka.length !== kb.length) return false;
  return ka.every((k) =>
    equal(
      (a as Record<string, unknown>)[k],
      (b as Record<string, unknown>)[k],
    )
  );
}

export function assert(cond: unknown, msg = "assertion failed"): asserts cond {
  if (!cond) throw new Error(msg);
}

export function assertFalse(cond: unknown, msg = "expected false") {
  if (cond) throw new Error(msg);
}

export function assertEquals(actual: unknown, expected: unknown, msg = "") {
  if (!equal(actual, expected)) {
    throw new Error(
      `${msg} expected ${JSON.stringify(expected)}, got ${
        JSON.stringify(actual)
      }`,
    );
  }
}

export function assertStringIncludes(actual: string, part: string) {
  if (!actual.includes(part)) {
    throw new Error(`expected ${JSON.stringify(actual)} to include ${part}`);
  }
}
