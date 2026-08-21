# Command Metadata

Read this before adding or changing commands in `bin/`.

Commands in `bin/` can declare CLI metadata in comments near the top of the
file. `bin/magikos` scans the first 80 lines, and tests expect command metadata
to remain valid.

Supported metadata keys:

- `# magikos:group=...` - override the command group inferred from the filename
- `# magikos:name=...` - override the command name inferred from the filename
- `# magikos:summary=...` - short help text
- `# magikos:args=...` - usage arguments
- `# magikos:examples=...` - examples separated with ` | `
- `# magikos:alias=...` / `# magikos:aliases=...` - alternate routes
- `# magikos:hidden=true` - hide from default command listings
- `# magikos:requires-sudo=true` - mark commands that require sudo

Only use `magikos:examples` where there are args that need explaining.

Prefer explicit metadata for user-facing commands. Keep routes consistent with
the filename unless there is a deliberate alias or compatibility route.

Example:

```bash
# magikos:summary=Take a screenshot
# magikos:args=[smart|region|windows|fullscreen] [slurp|copy]
# magikos:examples=magikos screenshot | magikos capture screenshot region
```
