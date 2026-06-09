# MoonFlagKit Acceptance Checklist

- [x] MoonBit module name is `a18265059561/moonflagkit`.
- [x] Repository metadata points to `https://github.com/q0w1ertyuiop/moonflagkit`.
- [x] README is a normal tracked file, not a symlink.
- [x] Core library has no external MoonBit dependency.
- [x] Public API covers evaluation, batch evaluation, parsing, diagnostics, explanation, and error formatting.
- [x] Tests cover disabled flags, allowlist, denylist, attribute rules, rollout buckets, parsing, and diagnostics.
- [x] CLI demo shows decisions for several subjects and prints diagnostics.
- [x] Application materials include both GitLink and GitHub repository links.
- [x] Current project text uses MoonFlagKit's new feature-flag direction consistently.

Verification commands:

```powershell
moon info
moon fmt
moon test
moon run cmd/main
git ls-files -s README.md
rg -i "<old project keywords>"
```
