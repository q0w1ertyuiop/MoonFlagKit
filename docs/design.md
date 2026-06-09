# MoonFlagKit Design

MoonFlagKit is a feature-flag decision kernel for MoonBit. It only answers one question: given a flag definition and a runtime context, should this feature be enabled, and why? The library stays below the platform layer. It does not own storage, network sync, dashboards, authentication, or analytics.

## Decision Model

A `Flag` contains a name, enabled state, default value, rollout percentage, salt, and an ordered rule list. An `EvalContext` contains the evaluated subject, environment, and arbitrary key-value attributes.

Evaluation is deterministic:

1. A disabled flag returns off immediately.
2. `Deny` rules are checked before all other rules.
3. `Allow` rules can enable a subject before rollout.
4. `When` rules must all match the context.
5. Rollout uses `bucket(subject, flag.name + ":" + flag.salt)`.

This keeps the result easy to explain in tests and in CLI output. It also avoids hidden ordering surprises when flags are reviewed by another developer.

## Stable Rollout

The `bucket` function maps a subject and salt into a number from 0 to 99. If the bucket is lower than the rollout percentage, the feature is enabled. Reusing the same subject and salt gives the same result, which matters for canary rollout and A/B-style experiments.

The current hash is intentionally simple and dependency-free. A future version can replace the hash implementation while preserving the public `bucket` contract.

## Configuration Parser

The first parser handles a small line-oriented format:

```text
flag checkout_v2 enabled=true rollout=35 salt=summer
allow checkout_v2 ops-admin
deny checkout_v2 blocked-user
when checkout_v2 environment=prod
```

The format is good enough for examples, tests, and hand-written configs. Larger integrations can build `Flag` values directly or add a provider on top of the same evaluation API.

## Error And Diagnostic Model

Parse errors report the line number and a short message. Validation diagnostics are separate from parsing so callers can load several flags and show all configuration problems at once. The current diagnostics cover duplicate names, empty names, and rollout values outside `0..100`.

## Extension Points

The project can grow in several directions without changing the v0.1 core:

- multi-variant flags for experiments;
- JSON or TOML providers;
- remote refresh adapters;
- OpenFeature-style facade APIs;
- richer conditions such as prefix, set membership, and numeric comparison;
- audit records for decisions made in service-side code.
