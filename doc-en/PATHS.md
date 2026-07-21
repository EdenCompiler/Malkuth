# Dependency paths

Dependency-path analysis helps answer how two packages are connected through the package graph.

## Interface

1. Select the source package and press `M`.
2. Search or select the target package.
3. Press `N` to compute a shortest route.
4. Press `8` to isolate the route.
5. Press `U` to export it.
6. Press `Z` to clear it.

The interactive route uses undirected connectivity (`:either`) because it is intended to answer “how are these subsystems connected?”.

## API directions

```lisp
(malkuth.model:shortest-dependency-path
 snapshot "MEU-APP.UI" "MEU-APP.DOMINIO"
 :direction :outgoing)
```

Supported directions:

- `:outgoing`: follows `USE-PACKAGE` direction;
- `:incoming`: follows reverse dependency direction;
- `:either`: traverses either direction.

## Export

The active route can be exported to Markdown and Graphviz DOT. The focused graph contains only the packages and edges needed to explain the route.

## Uses

Paths are useful for architecture reviews, tracing unexpected coupling, explaining transitive reachability and documenting why a high-level subsystem can influence a lower-level one.

A path is a structural explanation, not a function-level call trace.
