![Selene linter check](https://github.com/jalvesaq/tmp-R-Nvim/actions/workflows/selene.yml/badge.svg)

# R.nvim

This is the development code of R.nvim which improves Neovim's support to edit
R scripts.

## Installation

If you use a plugin manager, follow its instructions on how to install plugins
from GitHub. Users of [lazy.nvim](https://github.com/folke/lazy.nvim) who
opted for `defaults.lazy=true` have to configure R.nvim with `lazy=false`.
Examples of configuration for `lazy.nvim` (see also [cmp-r]):

Minimal configuration:

```lua
  {
    "R-nvim/R.nvim",
    lazy = false
  },
  {
    "nvim-treesitter/nvim-treesitter",
    run = ":TSUpdate",
    config = function ()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "markdown", "markdown_inline", "r", "rnoweb", "yaml" },
        highlight = { enable = true },
      })
    end
  },
  "R-nvim/cmp-r",
  {
    "hrsh7th/nvim-cmp",
    config = function()
      require("cmp").setup({ sources = {{ name = "cmp_r" }}})
      require("cmp_r").setup({ })
    end,
  },
```

More complex configuration (for `R.nvim` only):

```lua
    {
        "R-nvim/R.nvim",
        config = function ()
            -- Create a table with the options to be passed to setup()
            local opts = {
                hook = {
                    on_filetype = function()
                        vim.api.nvim_buf_set_keymap(0, "n", "<Enter>", "<Plug>RDSendLine", {})
                        vim.api.nvim_buf_set_keymap(0, "v", "<Enter>", "<Plug>RSendSelection", {})
                    end
                }
                R_args = {"--quiet", "--no-save"},
                min_editor_width = 72,
                rconsole_width = 78,
                disable_cmds = {
                        "RClearConsole",
                        "RCustomStart",
                        "RSPlot",
                        "RSaveClose",
                    },
                }
                -- Check if the environment variable "R_AUTO_START" exists.
                -- If using fish shell, you could put in your config.fish:
                -- alias r "R_AUTO_START=true nvim"
                if vim.env.R_AUTO_START == "true" then
                    opts.auto_start = "on startup"
                    opts.objbr_auto_start = true
                end
                require("r").setup(opts)
            end,
        lazy = false
    },
```

The complete list of options is in the documentation.
See also the [Wiki](https://github.com/R-nvim/R.nvim/wiki).

## Usage

Please read the plugin's
[documentation](https://github.com/R-nvim/R.nvim/blob/main/doc/R.nvim.txt) for
instructions on usage. See also the output of `:RMapsDesc`.

## Transitioning from Nvim-R

### Changes

During the conversion of VimScript to Lua, we decided to end support for features
that were useful in the past but no longer sufficiently valuable to be worth
the effort of conversion. We removed support for `Rrst` (it seems that not
many people use it anymore), debugging code (a debug adapter would be better),
legacy omni-completion (auto completion with
[nvim-cmp](https://github.com/hrsh7th/nvim-cmp) is better), and highlighting
functions from .GlobalEnv (difficult to make compatible with tree-sitter + LSP
highlighting).

We changed the default key binding to insert the assignment operator (`<-`) from an
underscore (which was familiar to Emacs-ESS users) to `Alt+-` which is more
convenient (but does not work on Vim). See the option `assignment_keymap`.

We replaced the options `R_source` and `after_R_start` with some more specific
`hook`s and we can insert other hooks for Lua functions at other parts of the
code under user request.

We added a keybinding for the pipe operator (`|>`). This defaults to
`<LocalLeader>,` and is configurable with the option `pipe_keymap`.

We added awareness of `.Rproj` files (the project-level configuration
files used by RStudio). This may, for example, change whether `pipe_keymap`
inserts `|>` or `%>%` for a particular project. See the option `rproj_prioritise`
for a full list of the behaviours which may be affected by `.Rproj` files,
or to change whether they should affect things at all.

We removed the `"echo"` parameters from the functions that send code to R
Console. Users can still set the value of `source_args` to define the
arguments that will be passed to `base::source()` and include the argument
`echo=TRUE`. Now, there is a new option to define how many lines can be sent
directly to the R Console without saving the code in a temporary file to be
sourced (`max_lines_to_paste`).

The options for displaying R documentation (`nvimpager`) are now: `"split_h"`,
`"split_v"`, `"tab"`, `"float"` (not implemented yet), and `"no"`.

The options `openpdf` and `openhtml` were renamed as `open_pdf` and
`open_html`, they now are strings and there is a minor change in how they
behave.

The option `nvim_wd` was renamed as `setwd` and it now is a string and its
default value is "no".

The option `notmuxconf` was renamed as `config_tmux` to avoid the negation of
the negation `notmuxconf=false` or the even more awkward confirmation of the
negation `notmuxconf=true`. The default value of `config_tmux` is `true`.

The `:RFormat` command no longer has the option to use the package `formatR`;
now, the `styler` package is required.

### New features

There are two new commands:

- `:RMapsDesc` displays the list of key bindings followed by short
  descriptions.

- `:RConfigShow` displays the list of configuration options and their current
  values.

There is one new command to send the above-piped chain of commands. Its
default key binding is `<LocalLeader>sc`.

There is a new command to install missing packages detected by the
[languageserver]: `<LocalLeader>ip`.

There is a new option: `auto_quit`.

If you have [colorout] installed, and if you are not loading it in your
`~/.Rprofile`, it should be version `1.3-1` or higher. Reason: R.nvim calls
the function `colorout::isColorOut()` which in previous `colorout` versions
were unduly enabling the output colorizing.

There are two new commands available to separate a file path into its different
components.

The first command, `<LocalLeader>sp`, will take the file path under
the cursor and break it down into its components, then surround it with the
`paste()` function.

The second command, `<LocalLeader>sh`, will also break down
the file path under the cursor into its components, but instead surround it
with the `here()` function.

It's important to note that both functions require
the [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
plugin to be installed.

For example, if you have the following file path under the cursor:

```r
read.csv("/home/user/Documents/file.csv")
```

Running the `<LocalLeader>sp` command will transform it into:

```r
read.csv(paste("/home", "user", "Documents", "file.csv", sep = "/"))
```

## Screenshots and videos

None yet. Tell us if you published a video presenting R.nvim features.

## The communication between Neovim and R

The diagram below shows how the communication between Neovim and R works.
![Neovim-R communication](https://raw.githubusercontent.com/jalvesaq/tmp-R-Nvim/master/nvimrcom.svg "Neovim-R communication")

The black arrows represent all commands that you trigger in the editor and
that you can see being pasted into R Console.
There are three different ways of sending the commands to R Console:

- When running R in a Neovim built-in terminal, the function `chansend()`
  is used to send code to R Console.

- When running R in an external terminal emulator, Tmux is used to send
  commands to R Console.

- On the Windows operating system, if using the `Rgui.exe` as "external
  terminal", Nvim-R can send a message to R (nvimcom) which forwards the
  command to R Console.

The R package _nvimcom_ includes the application _rnvimserver_ which is never
used by R itself but is run as a Neovim's job. That is, the communication
between the _rnvimserver_ and Neovim is through the _rnvimserver_ standard
input and output (green arrows). The _rnvimserver_ application runs a TCP
server. When _nvimcom_ is loaded, it immediately starts a TCP client that
connects to _rnvimserver_ (red arrows).

Some commands that you trigger are not pasted into R Console and do not output
anything in the R Console; their results are seen in the editor itself. These are
the commands to do auto completion (of names of objects and function
arguments), start and manipulate the Object Browser (`\ro`, `\r=` and `\r-`),
call R help (`\rh` or `:Rhelp`), insert the output of an R command
(`:Rinsert`), and format selected text (`:Rformat`).

When new objects are created or new libraries are loaded, nvimcom sends
messages that tell the editor to update the Object Browser, update the syntax
highlight to include newly loaded libraries and open the PDF output after
knitting an Rnoweb file, and compiling the LaTeX result. Most of the
information is transmitted through the TCP connection to the _rnvimserver_,
but temporary files are used in a few cases.

## See also:

- [cmp-r]: [nvim-cmp] source using R.nvim as backend.

- [languageserver]: a language server for R.

- [colorout]: a package to colorize R's output.

[cmp-r]: https://github.com/R-nvim/cmp-r
[neovim]: https://github.com/neovim/neovim
[southernlights]: https://github.com/jalvesaq/southernlights
[colorout]: https://github.com/jalvesaq/colorout
[languageserver]: https://cran.r-project.org/web/packages/languageserver/index.html
[nvim-cmp]: https://github.com/hrsh7th/nvim-cmp
