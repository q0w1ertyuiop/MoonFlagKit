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
pub(all) enum RouteError {
  MissingLeadingSlash(Int)
  EmptySegment(Int)
  EmptyParam(Int)
  EmptyWildcard(Int)
  InvalidName(Int, String)
  WildcardNotFinal(Int)
} derive(Eq, Debug)

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
