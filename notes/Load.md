# Native Functions

## With packers `nil`/`function`
### Sync
**Example:** math functions
 1. Call with {{num:7}, {num:12}, ...}
 2. unwrap in list {7, 12, ...}
 3. Call native with `table.unpack` on args, returns as {r1, r2, r3,...}
 4. wraps in list {{num:r1}, {num:r2}, {num:r3}, ...}
 5. result is `table.unpack`ed and converted to varargs
### Async
1-4 same as **Sync**
 5. list must be wrapped in {} to indicate it is a return value of async task
 6. same as **Sync** 5.

 ## Without Packers
 1. Call with {{num:7}, {num:12}, ...}
 2. Call native with `table.unpack` on args, Expects returns as {{num:r1}, {num:r2}, {num:r3}, ...}
 3. if async wrap with {}
 4. result is `table.unpack`ed and converted to varargs