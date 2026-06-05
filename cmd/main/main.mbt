///|
fn main {
  let table = @routekit.empty_table()
  let table = add_route(table, "home", "GET", "/", "home")
  let table = add_route(table, "users.show", "GET", "/users/:id", "show_user")
  let table = add_route(table, "assets.any", "ANY", "/assets/*path", "asset")
  let table = add_route(table, "assets.logo", "GET", "/assets/logo", "logo")

  println("MoonRouteKit demo")
  show_match(table, "GET", "/users/42")
  show_match(table, "GET", "/assets/logo")
  show_match(table, "POST", "/assets/docs/readme")

  match @routekit.reverse(table, "users.show", [{ key: "id", value: "42" }]) {
    Ok(path) => println("reverse users.show => " + path)
    Err(err) => println("reverse error: " + @routekit.format_error(err))
  }

  println("--- diagnostics ---")
  let diagnostics = @routekit.check_conflicts(table)
  if diagnostics.length() == 0 {
    println("none")
  } else {
    for diagnostic in diagnostics {
      println(diagnostic.kind + " " + diagnostic.route + ": " + diagnostic.message)
    }
  }
}

///|
fn add_route(
  table : @routekit.RouteTable,
  name : String,
  http_method : String,
  pattern : String,
  handler : String
) -> @routekit.RouteTable {
  match @routekit.add_route(table, { name, http_method, pattern, handler }) {
    Ok(next) => next
    Err(err) => abort("route error: " + @routekit.format_error(err))
  }
}

///|
fn show_match(table : @routekit.RouteTable, verb : String, path : String) -> Unit {
  match @routekit.match_route(table, verb, path) {
    Some(result) => {
      println(verb + " " + path + " => " + result.route.name)
      for param in result.params {
        println("  " + param.key + "=" + param.value)
      }
    }
    None => println(verb + " " + path + " => no match")
  }
}
