///|
fn main {
  let source =
    #|flag checkout_v2 enabled=true rollout=35 salt=summer
    #|allow checkout_v2 ops-admin
    #|deny checkout_v2 blocked-user
    #|when checkout_v2 environment=prod
    #|when checkout_v2 country=CN
    #|
  match @moonflagkit.parse_flags(source) {
    Ok(flags) => run_demo(flags)
    Err(err) => abort(@moonflagkit.format_error(err))
  }
}

///|
fn run_demo(flags : Array[@moonflagkit.Flag]) -> Unit {
  println("MoonFlagKit demo")
  show_decisions(flags, {
    subject: "ops-admin",
    environment: "prod",
    attributes: [{ key: "country", value: "CN" }],
  })
  show_decisions(flags, {
    subject: "blocked-user",
    environment: "prod",
    attributes: [{ key: "country", value: "CN" }],
  })
  show_decisions(flags, {
    subject: "visitor-42",
    environment: "prod",
    attributes: [{ key: "country", value: "CN" }],
  })

  println("--- diagnostics ---")
  let diagnostics = @moonflagkit.validate_flags(flags)
  if diagnostics.length() == 0 {
    println("none")
  } else {
    for diagnostic in diagnostics {
      println(
        diagnostic.kind + " " + diagnostic.flag + ": " + diagnostic.message,
      )
    }
  }
}

///|
fn show_decisions(
  flags : Array[@moonflagkit.Flag],
  context : @moonflagkit.EvalContext,
) -> Unit {
  println("subject=" + context.subject + " env=" + context.environment)
  for decision in @moonflagkit.evaluate_all(flags, context) {
    println("  " + @moonflagkit.explain(decision))
  }
}
