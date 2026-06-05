///|
fn pattern_ok(input : String) -> @moonroutekit.RoutePattern {
  match @moonroutekit.compile_pattern(input) {
    Ok(pattern) => pattern
    Err(err) => abort("unexpected route error: " + @moonroutekit.format_error(err))
  }
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
