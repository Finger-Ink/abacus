# Changelog

- Identifiers no longer swallow `-`: `a-b` lexes as subtraction, not a single
  variable named "a-b" (the `WORD` charset is now `[a-zA-Z_][a-zA-Z0-9_.]*`).
- Add the `%` modulo operator with JS remainder semantics (the result takes
  the dividend's sign), at the same precedence as `*` and `/`.
- Arithmetic that cannot produce a finite number — division by zero, `5 % 0`,
  `sqrt(-1)`, `log10(0)`, `0 ^ -1`, float overflow — returns
  `{:error, :einval}` instead of raising `ArithmeticError`.
- New `Abacus.Number` module: the shared numeric-coercion contract with the
  Finger-Ink JS expression engine (blank → 0; Unicode whitespace, currency
  and trailing-percent stripping; decimal-comma support). Arithmetic,
  ordering comparisons and the maths functions all route operands through
  it. `==`/`!=` deliberately keep the old exact parse.
- Whole-valued float results collapse to integers (`10 / 2` → `5`, not
  `5.0`) so results render the same as JS numbers.
- Repair `Abacus.variables/1`, which crashed on arithmetic, function and
  ternary nodes; it now walks any parsed expression and also accepts an
  `{:ok, expr}` parse result directly.
- Fix `includes_any`/`includes_all`/`does_not_include` crashing when the
  first argument is a bracketed list literal.
- Compile `.xrl`/`.yrl` with the leex/yecc mix compilers explicitly
  (required on modern Elixir; the generated `.erl` files stay gitignored).
- Fix uncaught errors thrown when performing functions on values that don't exist.
- Ensure that we pass floats through to the Float.\* functions, not integers.
- Modify maths functions to accept both strings and numbers — strings will be coerced into numbers before applying the correct operation.
- Add `roundTo` and `round_to` function as alias to `round` to mimic JS behaviour.
