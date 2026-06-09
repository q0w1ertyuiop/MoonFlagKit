///|
pub(all) struct Attribute {
  key : String
  value : String
} derive(Eq, Debug)

///|
pub(all) struct EvalContext {
  subject : String
  environment : String
  attributes : Array[Attribute]
} derive(Eq, Debug)

///|
pub(all) enum Condition {
  Equals(String, String)
} derive(Eq, Debug)

///|
pub(all) enum Rule {
  Allow(String)
  Deny(String)
  When(String, String)
} derive(Eq, Debug)

///|
pub(all) struct Flag {
  name : String
  enabled : Bool
  default_enabled : Bool
  rollout : Int
  salt : String
  rules : Array[Rule]
} derive(Eq, Debug)

///|
pub(all) struct Decision {
  flag : String
  enabled : Bool
  reason : String
} derive(Eq, Debug)

///|
pub(all) struct FlagDiagnostic {
  kind : String
  flag : String
  message : String
} derive(Eq, Debug)

///|
pub(all) enum FlagError {
  ParseError(Int, String)
  UnknownFlag(Int, String)
} derive(Eq, Debug)

///|
pub fn evaluate(flag : Flag, context : EvalContext) -> Decision {
  if !flag.enabled {
    return off(flag.name, "flag disabled")
  }
  for rule in flag.rules {
    match rule {
      Deny(subject) =>
        if subject == context.subject {
          return off(flag.name, "subject denied by rule")
        }
      _ => ()
    }
  }
  for rule in flag.rules {
    match rule {
      Allow(subject) =>
        if subject == context.subject {
          return on(flag.name, "subject allowed by rule")
        }
      _ => ()
    }
  }
  if !conditions_match(flag.rules, context) {
    return off(flag.name, "condition not matched")
  }
  if flag.rollout <= 0 {
    return off(flag.name, "rollout bucket closed")
  }
  if flag.rollout >= 100 {
    return on(flag.name, "rollout bucket opened")
  }
  let score = bucket(context.subject, flag.name + ":" + flag.salt)
  if score < flag.rollout {
    on(flag.name, "rollout bucket opened")
  } else {
    off(flag.name, "rollout bucket closed")
  }
}

///|
pub fn evaluate_all(
  flags : Array[Flag],
  context : EvalContext,
) -> Array[Decision] {
  let decisions : Array[Decision] = []
  for flag in flags {
    decisions.push(evaluate(flag, context))
  }
  decisions
}

///|
pub fn bucket(key : String, salt : String) -> Int {
  let input = key + "|" + salt
  let mut hash = 5381
  for c in input.iter() {
    hash = (hash * 33 + c.to_int()) % 1000003
    if hash < 0 {
      hash = 0 - hash
    }
  }
  hash % 100
}

///|
pub fn parse_flags(input : String) -> Result[Array[Flag], FlagError] {
  let mut flags : Array[Flag] = []
  let lines = input.split("\n").to_array()
  for i in 0..<lines.length() {
    let line_number = i + 1
    let line = lines[i].trim().to_owned()
    if line.length() == 0 {
      continue
    }
    let tokens = words(line)
    if tokens.length() == 0 {
      continue
    }
    match tokens[0] {
      "flag" =>
        match parse_flag_line(tokens, line_number) {
          Ok(flag) => flags.push(flag)
          Err(err) => return Err(err)
        }
      "allow" =>
        match attach_rule(flags, tokens, line_number, "allow") {
          Ok(next) => flags = next
          Err(err) => return Err(err)
        }
      "deny" =>
        match attach_rule(flags, tokens, line_number, "deny") {
          Ok(next) => flags = next
          Err(err) => return Err(err)
        }
      "when" =>
        match attach_rule(flags, tokens, line_number, "when") {
          Ok(next) => flags = next
          Err(err) => return Err(err)
        }
      other => return Err(ParseError(line_number, "unknown directive " + other))
    }
  }
  Ok(flags)
}

///|
pub fn validate_flags(flags : Array[Flag]) -> Array[FlagDiagnostic] {
  let diagnostics : Array[FlagDiagnostic] = []
  for i in 0..<flags.length() {
    let flag = flags[i]
    for j in 0..<i {
      if flags[j].name == flag.name && flag.name.length() > 0 {
        diagnostics.push({
          kind: "duplicate",
          flag: flag.name,
          message: "duplicate flag name " + flag.name,
        })
      }
    }
    if flag.rollout < 0 || flag.rollout > 100 {
      diagnostics.push({
        kind: "invalid_rollout",
        flag: flag.name,
        message: "rollout must be between 0 and 100",
      })
    }
    if flag.name.length() == 0 {
      diagnostics.push({
        kind: "empty_name",
        flag: flag.name,
        message: "flag name cannot be empty",
      })
    }
  }
  diagnostics
}

///|
pub fn explain(decision : Decision) -> String {
  let state = if decision.enabled { "on" } else { "off" }
  decision.flag + " " + state + ": " + decision.reason
}

///|
pub fn format_error(err : FlagError) -> String {
  match err {
    ParseError(line, message) => "line \{line}: " + message
    UnknownFlag(line, name) => "line \{line}: unknown flag " + name
  }
}

///|
fn on(flag : String, reason : String) -> Decision {
  { flag, enabled: true, reason }
}

///|
fn off(flag : String, reason : String) -> Decision {
  { flag, enabled: false, reason }
}

///|
fn conditions_match(rules : Array[Rule], context : EvalContext) -> Bool {
  for rule in rules {
    match rule {
      When(key, value) =>
        if lookup_context(context, key) != Some(value) {
          return false
        }
      _ => ()
    }
  }
  true
}

///|
fn lookup_context(context : EvalContext, key : String) -> String? {
  if key == "environment" || key == "env" {
    return Some(context.environment)
  }
  for attr in context.attributes {
    if attr.key == key {
      return Some(attr.value)
    }
  }
  None
}

///|
fn words(line : String) -> Array[String] {
  let parts : Array[String] = []
  for part in line.split(" ") {
    let token = part.trim().to_owned()
    if token.length() > 0 {
      parts.push(token)
    }
  }
  parts
}

///|
fn parse_flag_line(
  tokens : Array[String],
  line : Int,
) -> Result[Flag, FlagError] {
  if tokens.length() < 3 {
    return Err(ParseError(line, "flag requires name enabled and rollout"))
  }
  let name = tokens[1]
  if !tokens[2].has_prefix("enabled=") {
    return Err(ParseError(line, "expected enabled=true|false token"))
  }
  let enabled_text = after(tokens[2], "enabled=")
  let enabled = if enabled_text == "true" {
    true
  } else if enabled_text == "false" {
    false
  } else {
    return Err(ParseError(line, "expected enabled=true|false token"))
  }
  if !tokens[3].has_prefix("rollout=") {
    return Err(ParseError(line, "expected rollout=0..100 token"))
  }
  let rollout_text = after(tokens[3], "rollout=")
  let rollout = match parse_int(rollout_text) {
    Some(value) => value
    None => return Err(ParseError(line, "rollout must be an integer"))
  }
  let mut salt = name
  if tokens.length() > 4 {
    if !tokens[4].has_prefix("salt=") {
      return Err(ParseError(line, "expected salt=value token"))
    }
    salt = after(tokens[4], "salt=")
  }
  Ok({ name, enabled, default_enabled: false, rollout, salt, rules: [] })
}

///|
fn attach_rule(
  flags : Array[Flag],
  tokens : Array[String],
  line : Int,
  directive : String,
) -> Result[Array[Flag], FlagError] {
  if tokens.length() < 3 {
    return Err(ParseError(line, directive + " requires flag name and value"))
  }
  let flag_name = tokens[1]
  let rule = match directive {
    "allow" => Allow(tokens[2])
    "deny" => Deny(tokens[2])
    "when" =>
      match parse_condition(tokens[2], line) {
        Ok(pair) => When(pair.0, pair.1)
        Err(err) => return Err(err)
      }
    _ => return Err(ParseError(line, "unknown rule directive"))
  }
  let out : Array[Flag] = []
  let mut found = false
  for flag in flags {
    if flag.name == flag_name {
      let rules : Array[Rule] = []
      for existing in flag.rules {
        rules.push(existing)
      }
      rules.push(rule)
      out.push({
        name: flag.name,
        enabled: flag.enabled,
        default_enabled: flag.default_enabled,
        rollout: flag.rollout,
        salt: flag.salt,
        rules,
      })
      found = true
    } else {
      out.push(flag)
    }
  }
  if !found {
    return Err(UnknownFlag(line, flag_name))
  }
  Ok(out)
}

///|
fn parse_condition(
  token : String,
  line : Int,
) -> Result[(String, String), FlagError] {
  let parts = token.split("=").map(part => part.to_owned()).collect()
  if parts.length() != 2 || parts[0].length() == 0 || parts[1].length() == 0 {
    return Err(ParseError(line, "condition must be key=value"))
  }
  Ok((parts[0], parts[1]))
}

///|
fn after(input : String, prefix : String) -> String {
  input[prefix.length():].to_owned()
}

///|
fn parse_int(input : String) -> Int? {
  if input.length() == 0 {
    return None
  }
  let mut value = 0
  for c in input.iter() {
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + c.to_int() - '0'.to_int()
  }
  Some(value)
}
