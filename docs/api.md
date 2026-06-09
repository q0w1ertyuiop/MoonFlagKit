# MoonFlagKit API Notes

## Types

- `Attribute`: one key-value attribute in the evaluation context.
- `EvalContext`: subject, environment, and attributes supplied at runtime.
- `Rule`: `Allow`, `Deny`, or `When`.
- `Flag`: a boolean feature flag with rollout and rules.
- `Decision`: enabled state plus a human-readable reason.
- `FlagDiagnostic`: validation result for loaded flags.
- `FlagError`: parser or lookup error.

## Evaluation

```moonbit
let decision = @moonflagkit.evaluate(flag, context)
println(@moonflagkit.explain(decision))
```

Use `evaluate_all` when a caller wants to check a batch of flags for the same context.

## Parsing

```moonbit
let source =
  #|flag checkout_v2 enabled=true rollout=35 salt=summer
  #|allow checkout_v2 ops-admin
  #|when checkout_v2 environment=prod
  #|

match @moonflagkit.parse_flags(source) {
  Ok(flags) => println(flags.length().to_string())
  Err(err) => println(@moonflagkit.format_error(err))
}
```

## Diagnostics

`validate_flags` does not stop at the first problem. It returns all diagnostics it can find in the supplied array, which is useful for CLI tools or config loading steps.
