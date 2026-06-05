///|
fn pattern_ok(input : String) -> @moonroutekit.RoutePattern {
  match @moonroutekit.compile_pattern(input) {
    Ok(pattern) => pattern
    Err(err) => abort("unexpected route error: " + @moonroutekit.format_error(err))
  }
}

///|
fn add_ok(table : @moonroutekit.RouteTable, route : @moonroutekit.Route) -> @moonroutekit.RouteTable {
  match @moonroutekit.add_route(table, route) {
    Ok(next) => next
    Err(err) => abort("unexpected add route error: " + @moonroutekit.format_error(err))
  }
}

///|
fn param_value(result : @moonroutekit.MatchResult, key : String) -> String {
  for param in result.params {
    if param.key == key {
      return param.value
    }
  }
  abort("missing param: " + key)
}

///|
fn sample_table() -> @moonroutekit.RouteTable {
  let table = @moonroutekit.empty_table()
  let table = add_ok(table, { name: "users.index", http_method: "GET", pattern: "/users", handler: "list_users" })
  let table = add_ok(table, { name: "users.show", http_method: "GET", pattern: "/users/:id", handler: "show_user" })
  add_ok(table, { name: "assets.show", http_method: "GET", pattern: "/assets/*path", handler: "asset" })
}

///|
test "compile root static param and wildcard patterns" {
  let root = pattern_ok("/")
  assert_eq(root.source, "/")
  assert_eq(root.segments.length(), 0)
  let user = pattern_ok("/users/:id/posts/:post_id")
  assert_eq(user.segments.length(), 4)
  assert_true(user.segments[0] is @moonroutekit.Static("users"))
  assert_true(user.segments[1] is @moonroutekit.Param("id"))
  assert_true(user.segments[3] is @moonroutekit.Param("post_id"))
  let assets = pattern_ok("/assets/*path")
  assert_true(assets.segments[1] is @moonroutekit.Wildcard("path"))
}

///|
test "reject malformed path patterns" {
  match @moonroutekit.compile_pattern("users/:id") {
    Err(err) =>
      assert_eq(@moonroutekit.format_error(err), "column 1: route pattern must start with /")
    Ok(_) => abort("expected leading slash error")
  }
  match @moonroutekit.compile_pattern("/assets/*path/more") {
    Err(err) =>
      assert_eq(@moonroutekit.format_error(err), "column 9: wildcard must be the final segment")
    Ok(_) => abort("expected wildcard position error")
  }
}

///|
test "match routes by method and extract params" {
  let table = @moonroutekit.empty_table()
  let table = add_ok(table, { name: "users.index", http_method: "GET", pattern: "/users", handler: "list_users" })
  let table = add_ok(table, { name: "users.show", http_method: "GET", pattern: "/users/:id", handler: "show_user" })
  match @moonroutekit.match_route(table, "GET", "/users/42") {
    Some(result) => {
      assert_eq(result.route.name, "users.show")
      assert_eq(param_value(result, "id"), "42")
    }
    None => abort("expected route match")
  }
  assert_true(@moonroutekit.match_route(table, "POST", "/users/42") is None)
}

///|
test "prefer static route over param and wildcard routes" {
  let table = @moonroutekit.empty_table()
  let table = add_ok(table, { name: "files.any", http_method: "ANY", pattern: "/files/*path", handler: "asset" })
  let table = add_ok(table, { name: "files.named", http_method: "GET", pattern: "/files/:name", handler: "named" })
  let table = add_ok(table, { name: "files.health", http_method: "GET", pattern: "/files/health", handler: "health" })
  match @moonroutekit.match_route(table, "GET", "/files/health") {
    Some(result) => assert_eq(result.route.name, "files.health")
    None => abort("expected static route match")
  }
  match @moonroutekit.match_route(table, "GET", "/files/logo/png") {
    Some(result) => {
      assert_eq(result.route.name, "files.any")
      assert_eq(param_value(result, "path"), "logo/png")
    }
    None => abort("expected wildcard route match")
  }
}

///|
test "reverse generate paths from named routes" {
  let table = sample_table()
  match @moonroutekit.reverse(table, "users.show", [{ key: "id", value: "42" }]) {
    Ok(path) => assert_eq(path, "/users/42")
    Err(err) => abort("unexpected reverse error: " + @moonroutekit.format_error(err))
  }
  match @moonroutekit.reverse(table, "assets.show", [{ key: "path", value: "logo/png" }]) {
    Ok(path) => assert_eq(path, "/assets/logo/png")
    Err(err) => abort("unexpected wildcard reverse error: " + @moonroutekit.format_error(err))
  }
}

///|
test "reverse reports missing params and unknown route names" {
  let table = sample_table()
  match @moonroutekit.reverse(table, "users.show", []) {
    Err(err) =>
      assert_eq(@moonroutekit.format_error(err), "missing parameter id for route users.show")
    Ok(_) => abort("expected missing parameter error")
  }
  match @moonroutekit.reverse(table, "users.edit", []) {
    Err(err) =>
      assert_eq(@moonroutekit.format_error(err), "unknown route name users.edit")
    Ok(_) => abort("expected unknown route error")
  }
}
