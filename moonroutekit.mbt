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
pub(all) enum RouteError {
  MissingLeadingSlash(Int)
  EmptySegment(Int)
  EmptyParam(Int)
  EmptyWildcard(Int)
  InvalidName(Int, String)
  WildcardNotFinal(Int)
} derive(Eq, Debug)

///|
pub fn empty_table() -> RouteTable {
  { routes: [] }
}

///|
pub fn add_route(table : RouteTable, route : Route) -> Result[RouteTable, RouteError] {
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
pub fn match_route(table : RouteTable, verb : String, path : String) -> MatchResult? {
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
fn compile_segment(text : String, column : Int, is_final : Bool) -> Result[Segment, RouteError] {
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
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') || c == '_'
}

///|
pub fn format_error(err : RouteError) -> String {
  match err {
    MissingLeadingSlash(column) => "column \{column}: route pattern must start with /"
    EmptySegment(column) => "column \{column}: empty path segment"
    EmptyParam(column) => "column \{column}: missing parameter name"
    EmptyWildcard(column) => "column \{column}: missing wildcard name"
    InvalidName(column, name) => "column \{column}: invalid parameter name " + name
    WildcardNotFinal(column) => "column \{column}: wildcard must be the final segment"
  }
}
