# MoonRouteKit

MoonRouteKit is a lightweight route pattern compiler and request matching core for MoonBit HTTP, edge, and Wasm service experiments.

The project provides a compact routing kernel instead of a full web framework. It can be embedded by service demos, teaching examples, gateway prototypes, and MoonBit runtime experiments that need deterministic path matching without pulling in a large framework.

## Features

- Compile route patterns such as `/users/:id` and `/assets/*path`.
- Match request method and path pairs against a route table.
- Extract route parameters into stable key-value pairs.
- Generate URLs from named routes.
- Diagnose duplicate routes and wildcard shadowing.
- Keep the implementation dependency-free and easy to test.

## Example

```moonbit
let table = @moonroutekit.empty_table()
let table = match @moonroutekit.add_route(
  table,
  { name: "users.show", http_method: "GET", pattern: "/users/:id", handler: "show_user" },
) {
  Ok(next) => next
  Err(err) => abort(@moonroutekit.format_error(err))
}

match @moonroutekit.match_route(table, "GET", "/users/42") {
  Some(result) => println(result.route.name)
  None => println("no match")
}
```

For a runnable demonstration:

```powershell
moon run cmd/main
```

Expected output includes route matches, extracted parameters, reverse path generation, and diagnostic messages.

## Public API

- `compile_pattern(input : String) -> Result[RoutePattern, RouteError]`
- `add_route(table : RouteTable, route : Route) -> Result[RouteTable, RouteError]`
- `match_route(table : RouteTable, verb : String, path : String) -> MatchResult?`
- `reverse(table : RouteTable, name : String, params : Array[Param]) -> Result[String, RouteError]`
- `check_conflicts(table : RouteTable) -> Array[RouteDiagnostic]`
- `format_error(err : RouteError) -> String`

## Repository Links

- GitLink: https://gitlink.org.cn/python123/moonroutekit
- GitHub: https://github.com/python123-ops/moonroutekit
