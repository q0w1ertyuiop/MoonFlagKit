# MoonRouteKit API Notes

## Route Construction

Use `empty_table` to create an empty route table, then register routes with `add_route`.

```moonbit
let table = @moonroutekit.empty_table()
let table = match @moonroutekit.add_route(table, {
  name: "users.show",
  http_method: "GET",
  pattern: "/users/:id",
  handler: "show_user",
}) {
  Ok(next) => next
  Err(err) => abort(@moonroutekit.format_error(err))
}
```

## Matching

`match_route` returns `MatchResult?`. A successful match contains the selected route, extracted params, priority score, and registration order.

```moonbit
match @moonroutekit.match_route(table, "GET", "/users/42") {
  Some(result) => println(result.route.name)
  None => println("no match")
}
```

## Reverse Generation

Use `reverse` with a named route and parameter list.

```moonbit
@moonroutekit.reverse(table, "users.show", [{ key: "id", value: "42" }])
```

## Diagnostics

Use `check_conflicts` before exposing a route table through an application. The function reports duplicate routes and wildcard shadowing in registration order.
