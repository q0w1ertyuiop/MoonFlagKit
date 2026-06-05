///|
pub(all) enum Segment {
  Static(String)
  Param(String)
  Wildcard(String)
} derive(Eq, Debug)

///|
pub(all) struct RoutePattern {
  source : String
  segments : Array[Segment]
} derive(Eq, Debug)

///|
pub(all) struct Route {
  name : String
  http_method : String
  pattern : String
  handler : String
} derive(Eq, Debug)

///|
pub(all) struct Param {
  key : String
  value : String
} derive(Eq, Debug)

///|
pub(all) struct CompiledRoute {
  route : Route
  compiled : RoutePattern
  order : Int
} derive(Eq, Debug)

///|
pub(all) struct RouteTable {
  routes : Array[CompiledRoute]
} derive(Eq, Debug)

///|
pub(all) struct MatchResult {
  route : Route
  params : Array[Param]
  priority : Int
  order : Int
} derive(Eq, Debug)

///|
pub(all) struct RouteDiagnostic {
  kind : String
  route : String
  message : String
} derive(Eq, Debug)

///|
pub(all) enum RouteError {
  MissingLeadingSlash(Int)
  EmptySegment(Int)
  EmptyParam(Int)
  EmptyWildcard(Int)
  InvalidName(Int, String)
  WildcardNotFinal(Int)
  MissingParam(String, String)
  UnknownRoute(String)
} derive(Eq, Debug)

///|
pub fn empty_table() -> RouteTable {
  { routes: [] }
}

///|
pub fn add_route(
  table : RouteTable,
  route : Route,
) -> Result[RouteTable, RouteError] {
  match compile_pattern(route.pattern) {
    Ok(compiled) => {
      let routes : Array[CompiledRoute] = []
      for existing in table.routes {
        routes.push(existing)
      }
      routes.push({ route, compiled, order: routes.length() })
      Ok({ routes, })
    }
    Err(err) => Err(err)
  }
}

///|
pub fn match_route(
  table : RouteTable,
  verb : String,
  path : String,
) -> MatchResult? {
  if path.length() == 0 || path[0] != '/' {
    return None
  }
  let parts = path_segments(path)
  let mut best : MatchResult? = None
  for compiled in table.routes {
    if compiled.route.http_method == verb || compiled.route.http_method == "ANY" {
      match match_compiled(compiled, parts) {
        Some(result) =>
          match best {
            Some(current) =>
              if result.priority > current.priority {
                best = Some(result)
              }
            None => best = Some(result)
          }
        None => ()
      }
    }
  }
  best
}

///|
pub fn reverse(
  table : RouteTable,
  name : String,
  params : Array[Param],
) -> Result[String, RouteError] {
  for compiled in table.routes {
    if compiled.route.name == name {
      return reverse_compiled(compiled, params)
    }
  }
  Err(UnknownRoute(name))
}

///|
pub fn check_conflicts(table : RouteTable) -> Array[RouteDiagnostic] {
  let diagnostics : Array[RouteDiagnostic] = []
  for i in 0..<table.routes.length() {
    let current = table.routes[i]
    let mut reported = false
    for j in 0..<i {
      let previous = table.routes[j]
      if !reported &&
        same_method_space(previous.route.http_method, current.route.http_method) {
        if previous.route.pattern == current.route.pattern {
          diagnostics.push({
            kind: "duplicate",
            route: current.route.name,
            message: "duplicates " +
            previous.route.name +
            " on " +
            current.route.http_method +
            " " +
            current.route.pattern,
          })
          reported = true
        }
      }
    }
    for j in 0..<i {
      let previous = table.routes[j]
      if !reported &&
        same_method_space(previous.route.http_method, current.route.http_method) {
        if previous.route.pattern == current.route.pattern {
          ()
        } else if shadows(previous.compiled, current.compiled) {
          diagnostics.push({
            kind: "shadowed",
            route: current.route.name,
            message: "shadowed by " + previous.route.name,
          })
          reported = true
        }
      }
    }
  }
  diagnostics
}

///|
pub fn compile_pattern(input : String) -> Result[RoutePattern, RouteError] {
  if input.length() == 0 || input[0] != '/' {
    return Err(MissingLeadingSlash(1))
  }
  if input == "/" {
    return Ok({ source: input, segments: [] })
  }
  let segments : Array[Segment] = []
  let chars = input.iter().to_array()
  let part = StringBuilder()
  let mut start_column = 2
  let mut i = 1
  while i <= chars.length() {
    if i == chars.length() || chars[i] == '/' {
      let text = part.to_string()
      match compile_segment(text, start_column, i == chars.length()) {
        Ok(segment) => segments.push(segment)
        Err(err) => return Err(err)
      }
      part.reset()
      start_column = i + 2
    } else {
      part.write_char(chars[i])
    }
    i += 1
  }
  Ok({ source: input, segments })
}

///|
fn match_compiled(route : CompiledRoute, parts : Array[String]) -> MatchResult? {
  let params : Array[Param] = []
  let mut i = 0
  let mut priority = 0
  for segment in route.compiled.segments {
    match segment {
      Static(value) => {
        if i >= parts.length() || parts[i] != value {
          return None
        }
        priority += 100
        i += 1
      }
      Param(name) => {
        if i >= parts.length() {
          return None
        }
        params.push({ key: name, value: parts[i] })
        priority += 10
        i += 1
      }
      Wildcard(name) => {
        params.push({ key: name, value: join_from(parts, i) })
        priority += 1
        i = parts.length()
      }
    }
  }
  if i != parts.length() {
    return None
  }
  Some({ route: route.route, params, priority, order: route.order })
}

///|
fn reverse_compiled(
  route : CompiledRoute,
  params : Array[Param],
) -> Result[String, RouteError] {
  if route.compiled.segments.length() == 0 {
    return Ok("/")
  }
  let out = StringBuilder()
  for segment in route.compiled.segments {
    out.write_char('/')
    match segment {
      Static(value) => out.write_string(value)
      Param(name) =>
        match lookup_param(params, name) {
          Some(value) => out.write_string(value)
          None => return Err(MissingParam(route.route.name, name))
        }
      Wildcard(name) =>
        match lookup_param(params, name) {
          Some(value) => out.write_string(value)
          None => return Err(MissingParam(route.route.name, name))
        }
    }
  }
  Ok(out.to_string())
}

///|
fn lookup_param(params : Array[Param], key : String) -> String? {
  for param in params {
    if param.key == key {
      return Some(param.value)
    }
  }
  None
}

///|
fn same_method_space(left : String, right : String) -> Bool {
  left == right || left == "ANY" || right == "ANY"
}

///|
fn shadows(previous : RoutePattern, current : RoutePattern) -> Bool {
  for i in 0..<previous.segments.length() {
    if i >= current.segments.length() {
      return false
    }
    match previous.segments[i] {
      Wildcard(_) => return prefix_matches(previous, current, i)
      Static(value) =>
        match current.segments[i] {
          Static(other) => if value != other { return false }
          _ => return false
        }
      Param(_) => ()
    }
  }
  false
}

///|
fn prefix_matches(
  previous : RoutePattern,
  current : RoutePattern,
  until : Int,
) -> Bool {
  for i in 0..<until {
    match previous.segments[i] {
      Static(value) =>
        match current.segments[i] {
          Static(other) => if value != other { return false }
          _ => return false
        }
      Param(_) => ()
      Wildcard(_) => ()
    }
  }
  true
}

///|
fn path_segments(path : String) -> Array[String] {
  if path == "/" {
    return []
  }
  let parts : Array[String] = []
  let chars = path.iter().to_array()
  let part = StringBuilder()
  let mut i = 1
  while i < chars.length() {
    if chars[i] == '/' {
      let text = part.to_string()
      if text.length() > 0 {
        parts.push(text)
        part.reset()
      }
    } else {
      part.write_char(chars[i])
    }
    i += 1
  }
  let text = part.to_string()
  if text.length() > 0 {
    parts.push(text)
  }
  parts
}

///|
fn join_from(parts : Array[String], start : Int) -> String {
  let out = StringBuilder()
  for i in start..<parts.length() {
    if i > start {
      out.write_char('/')
    }
    out.write_string(parts[i])
  }
  out.to_string()
}

///|
fn compile_segment(
  text : String,
  column : Int,
  is_final : Bool,
) -> Result[Segment, RouteError] {
  if text.length() == 0 {
    return Err(EmptySegment(column))
  }
  if text[0] == ':' {
    let name = text[1:].to_owned()
    if name.length() == 0 {
      return Err(EmptyParam(column))
    }
    if !valid_name(name) {
      return Err(InvalidName(column + 1, name))
    }
    return Ok(Param(name))
  }
  if text[0] == '*' {
    let name = text[1:].to_owned()
    if name.length() == 0 {
      return Err(EmptyWildcard(column))
    }
    if !is_final {
      return Err(WildcardNotFinal(column))
    }
    if !valid_name(name) {
      return Err(InvalidName(column + 1, name))
    }
    return Ok(Wildcard(name))
  }
  Ok(Static(text))
}

///|
fn valid_name(input : String) -> Bool {
  for c in input.iter() {
    if !is_name_char(c) {
      return false
    }
  }
  true
}

///|
fn is_name_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_'
}

///|
pub fn format_error(err : RouteError) -> String {
  match err {
    MissingLeadingSlash(column) =>
      "column \{column}: route pattern must start with /"
    EmptySegment(column) => "column \{column}: empty path segment"
    EmptyParam(column) => "column \{column}: missing parameter name"
    EmptyWildcard(column) => "column \{column}: missing wildcard name"
    InvalidName(column, name) =>
      "column \{column}: invalid parameter name " + name
    WildcardNotFinal(column) =>
      "column \{column}: wildcard must be the final segment"
    MissingParam(route, name) =>
      "missing parameter " + name + " for route " + route
    UnknownRoute(name) => "unknown route name " + name
  }
}
