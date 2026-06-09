///|
fn attr(key : String, value : String) -> @moonflagkit.Attribute {
  { key, value }
}

///|
fn context(
  subject : String,
  environment : String,
  attributes : Array[@moonflagkit.Attribute],
) -> @moonflagkit.EvalContext {
  { subject, environment, attributes }
}

///|
fn flag(
  name : String,
  enabled : Bool,
  rollout : Int,
  salt : String,
  rules : Array[@moonflagkit.Rule],
) -> @moonflagkit.Flag {
  { name, enabled, default_enabled: false, rollout, salt, rules }
}

///|
fn decision_for(
  flag : @moonflagkit.Flag,
  context : @moonflagkit.EvalContext,
) -> Bool {
  @moonflagkit.evaluate(flag, context).enabled
}

///|
test "disabled flags stay off and explain the reason" {
  let beta = flag("checkout_v2", false, 100, "v1", [])
  let decision = @moonflagkit.evaluate(beta, context("alice", "prod", []))
  assert_eq(decision.enabled, false)
  assert_eq(decision.reason, "flag disabled")
  assert_eq(@moonflagkit.explain(decision), "checkout_v2 off: flag disabled")
}

///|
test "denylist takes precedence over allowlist" {
  let beta = flag("checkout_v2", true, 100, "v1", [
    @moonflagkit.Allow("alice"),
    @moonflagkit.Deny("alice"),
  ])
  let decision = @moonflagkit.evaluate(beta, context("alice", "prod", []))
  assert_eq(decision.enabled, false)
  assert_eq(decision.reason, "subject denied by rule")
}

///|
test "allowlist can enable a user before rollout" {
  let beta = flag("checkout_v2", true, 0, "v1", [@moonflagkit.Allow("alice")])
  assert_eq(decision_for(beta, context("alice", "prod", [])), true)
  assert_eq(decision_for(beta, context("bob", "prod", [])), false)
}

///|
test "attribute rules require matching environment and fields" {
  let beta = flag("checkout_v2", true, 100, "v1", [
    @moonflagkit.When("environment", "prod"),
    @moonflagkit.When("country", "CN"),
    @moonflagkit.When("plan", "pro"),
  ])
  assert_eq(
    decision_for(
      beta,
      context("alice", "prod", [attr("country", "CN"), attr("plan", "pro")]),
    ),
    true,
  )
  assert_eq(
    decision_for(
      beta,
      context("alice", "prod", [attr("country", "US"), attr("plan", "pro")]),
    ),
    false,
  )
}

///|
test "percentage rollout uses a stable bucket" {
  let first = @moonflagkit.bucket("alice", "checkout_v2:v1")
  let second = @moonflagkit.bucket("alice", "checkout_v2:v1")
  assert_eq(first, second)
  assert_true(first >= 0 && first < 100)

  let beta = flag("checkout_v2", true, 100, "v1", [])
  assert_eq(decision_for(beta, context("alice", "prod", [])), true)
  let closed = flag("checkout_v2", true, 0, "v1", [])
  assert_eq(decision_for(closed, context("alice", "prod", [])), false)
}

///|
test "parse line oriented flag configuration" {
  let source =
    #|flag checkout_v2 enabled=true rollout=25 salt=v1
    #|allow checkout_v2 alice
    #|deny checkout_v2 bob
    #|when checkout_v2 environment=prod
    #|
  match @moonflagkit.parse_flags(source) {
    Ok(flags) => {
      assert_eq(flags.length(), 1)
      assert_eq(flags[0].name, "checkout_v2")
      assert_eq(flags[0].rules.length(), 3)
    }
    Err(err) => abort(@moonflagkit.format_error(err))
  }
}

///|
test "validate flags reports duplicates and invalid rollout" {
  let diagnostics = @moonflagkit.validate_flags([
    flag("checkout_v2", true, 25, "v1", []),
    flag("checkout_v2", true, 120, "v2", []),
    flag("", true, 10, "v3", []),
  ])
  assert_eq(diagnostics.length(), 3)
  assert_eq(diagnostics[0].kind, "duplicate")
  assert_eq(diagnostics[1].kind, "invalid_rollout")
  assert_eq(diagnostics[2].kind, "empty_name")
}

///|
test "parse errors are formatted for humans" {
  match @moonflagkit.parse_flags("flag checkout_v2 rollout=bad") {
    Err(err) =>
      assert_eq(
        @moonflagkit.format_error(err),
        "line 1: expected enabled=true|false token",
      )
    Ok(_) => abort("expected parse error")
  }
}
