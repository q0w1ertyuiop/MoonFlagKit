# MoonFlagKit

MoonFlagKit is a small MoonBit library for feature flags and progressive rollout decisions. It is meant for service demos, Wasm edge experiments, command-line tools, and runtime configuration prototypes that need predictable flag evaluation without pulling in a server or configuration platform.

The first version focuses on a compact decision engine:

- boolean feature flags;
- allowlist and denylist rules;
- environment and attribute matching;
- stable percentage rollout buckets;
- readable decision explanations;
- configuration parsing and diagnostics.

## Why This Project

MoonBit examples are increasingly used in service-side and Wasm scenarios. These projects often need a simple way to turn features on for a few users, disable risky behavior quickly, or test a new code path in one environment first. MoonFlagKit provides the decision layer for that work. It deliberately does not implement a remote control plane, UI, database, or network protocol, so the core remains easy to embed and test.

## Example

```moonbit
let flag : @moonflagkit.Flag = {
  name: "checkout_v2",
  enabled: true,
  default_enabled: false,
  rollout: 25,
  salt: "summer",
  rules: [
    @moonflagkit.Allow("ops-admin"),
    @moonflagkit.Deny("blocked-user"),
    @moonflagkit.When("environment", "prod"),
    @moonflagkit.When("country", "CN"),
  ],
}

let context : @moonflagkit.EvalContext = {
  subject: "alice",
  environment: "prod",
  attributes: [{ key: "country", value: "CN" }],
}

let decision = @moonflagkit.evaluate(flag, context)
println(@moonflagkit.explain(decision))
```

For a runnable demonstration:

```powershell
moon run cmd/main
```

## Public API

- `evaluate(flag, context) -> Decision`
- `evaluate_all(flags, context) -> Array[Decision]`
- `parse_flags(input) -> Result[Array[Flag], FlagError]`
- `validate_flags(flags) -> Array[FlagDiagnostic]`
- `bucket(key, salt) -> Int`
- `explain(decision) -> String`
- `format_error(err) -> String`

## Configuration Format

The parser accepts a small line-oriented format for demos and tests:

```text
flag checkout_v2 enabled=true rollout=35 salt=summer
allow checkout_v2 ops-admin
deny checkout_v2 blocked-user
when checkout_v2 environment=prod
when checkout_v2 country=CN
```

The format is intentionally narrow in v0.1. A future version can add JSON, TOML, or OpenFeature-style providers while keeping the same evaluation model.

## Repository Links

- GitLink: https://www.gitlink.org.cn/a18265059561/moonflagkit
- GitHub: https://github.com/q0w1ertyuiop/moonflagkit

## Competition Positioning

MoonFlagKit targets the mature engineering area of progressive delivery: feature switches, canary rollout, kill switches, and runtime decision explanation. The implementation has no external MoonBit dependencies and is covered by behavior tests. It is a new project direction with its own API, tests, documents, and demonstration program.
