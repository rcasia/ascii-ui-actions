# ascii-ui-actions.nvim

Neovim plugin UI built with [ascii-ui.nvim](https://github.com/ascii-ui/ascii-ui.nvim).

> This repo also contains the OpenSpec workflow config (`.opencode/`, `openspec/`).

## Requirements

- Neovim >= 0.10
- [ascii-ui.nvim](https://github.com/ascii-ui/ascii-ui.nvim)

## Installation

```lua
{
  "rcasia/ascii-ui-actions",
  dependencies = { "ascii-ui/ascii-ui.nvim" },
  cmd = "AsciiUiActions",
  opts = {},
}
```

## Usage

```
:AsciiUiActions
```

Opens a floating window. Focus with `h/j/k/l`, select with `<CR>`, quit with `q`.

### Setup options

```lua
require("ascii-ui-actions").setup({
  title = "my actions",
})
```

## Structure

```
lua/ascii-ui-actions/
  init.lua        -- setup() and open()
  config.lua      -- defaults and option merging
  health.lua      -- :checkhealth ascii-ui-actions
  ui/tokens.lua   -- the whole state palette (glyph + highlight group)
  ui/keymap.lua   -- the one keymap table (hint bar + ? overlay)
  ui/demo.lua     -- layout reference component (regions per UI structure)
  ui/app.lua      -- App component (ascii-ui)
plugin/
  ascii-ui-actions.lua      -- lazy entry point, defines :AsciiUiActions
scripts/
  minimal_init.lua  -- headless test bootstrap (mini.test + ascii-ui)
  test              -- test runner
tests/
  assertions.lua    -- eq() helper with pretty diff output
  unit/             -- *_spec.lua tests (ascii-ui.testing harness)
```

## UI structure

The window is a fixed stack of five regions, in this order:

```
 ascii-ui-actions        ← title
 foo/bar › ci.yml        ← breadcrumb (h/BS = back)
 ✓ build     main   2m14s ← content rows: glyph, name, branch, duration
 fetched 12:04:31        ← status (errors shown as │ msg · hint)
 j/k move  <CR> open  ? keys ← hint bar (generated from the keymap)
```

- Glyphs and highlight groups come only from `lua/ascii-ui-actions/ui/tokens.lua`
  (✓ ✗ ● ○ ⊘ on DiagnosticOk/Error/Info/Warn/Comment — theme-aware, never hex).
- All bindings live in one table, `ui/keymap.lua`; the hint bar and the `?`
  overlay render from it, so docs and keys cannot drift. Press `<CR>` on
  `? keys` in the hint bar for the full listing.
- Reference implementation of the layout: `ui/demo.lua` (used by tests and
  live-reload; the dashboard views will build on these rules).

## Development

Run tests (auto-clones deps into `.dependencies/` on first run):

```sh
make test              # all tests
make test-fail-fast    # stop at first failure
./scripts/test tests/unit/app_spec.lua  # single file
```

Format and lint with [stylua](https://github.com/JohnnyMorganz/StyLua):

```sh
make format
make validate
```

Iterate live on the UI component from a Neovim session:

```lua
require("ascii-ui").debug("lua/ascii-ui-actions/ui/demo.lua")
```

## License

MIT
