# MoonRouteKit Design

## Positioning

MoonRouteKit is a MoonBit route matching kernel for HTTP-style service experiments. It deliberately stays below the framework layer: no network server, no middleware stack, no response abstraction. The library only owns path pattern compilation, request matching, parameter extraction, reverse path generation, and route diagnostics.

## Pattern Model

Supported patterns:

- `/`
- `/users`
- `/users/:id`
- `/users/:id/posts/:post_id`
- `/assets/*path`

Segments are compiled into three forms:

- `Static(value)` for literal segments.
- `Param(name)` for one-segment captures.
- `Wildcard(name)` for final multi-segment captures.

Wildcard segments must be final. Parameter names accept letters, digits, and `_`.

## Matching Rule

Route matching checks method space first. A route with `ANY` accepts every method; otherwise the method must match exactly.

When multiple routes match the same request, the priority score is deterministic:

- static segment: 100
- parameter segment: 10
- wildcard segment: 1

The highest score wins. Equal scores keep registration order.

## Reverse Generation

Named routes can be turned back into paths. Static segments are copied. Parameter and wildcard segments are filled from `Array[Param]`. Missing values return a structured `RouteError`.

## Diagnostics

`check_conflicts` scans the registered route table and reports:

- duplicate method and pattern pairs
- routes shadowed by an earlier wildcard route

Each route reports only the highest-priority issue, so duplicate entries do not produce noisy secondary warnings.

## Error Model

`RouteError` keeps errors compact and deterministic. `format_error` converts them into review-friendly text for tests, CLI output, and documentation.
