VSCrib.vim [ALPHA]
================================================================================
A VimL library for cribbing project infrastructure and workspace configurations
from VSCode.

As of the time of writing, VSCrib.vim mainly serves as a library for reading
VSCode JSON configuration files, particularly files like `launch.json` situated
in a `.vscode` folder.

As of the time of writing, VSCrib.vim is effectively a submodule of [dapper.nvim](https://github.com/Yilin-Yang/dapper.nvim).
In the future, VSCrib.vim might serve as a full compatibility layer between vim and
VSCode extensions.

Developers are welcome to use VSCrib.vim in their own plugins, so long as they
remain aware that VSCrib.vim is undergoing active development, and that I make **no
guarantees whatsoever of API stability**. Issue reports and feature requests are
still welcome, however; I hope to eventually turn VSCrib.vim into a fully-fledged
vim plugin of its own, so such reports would help me plan a development roadmap.

Prerequisites
--------------------------------------------------------------------------------
VSCrib.vim requires at least [Vim 7.4.1304](https://github.com/vim/vim/commit/7823a3bd2eed6ff9e544d201de96710bd5344aaf)
or [practically any recent version of neovim.](https://github.com/neovim/neovim/commit/4dcd19d9bc2417051ddbda177010ca8c0cb2cf73)

In practice, VSCrib.vim is primarily developed using neovim 0.3.4+, with only
limited testing on Vim 7.X. If you encounter problems, they might be fixed by
upgrading to a newer version of Vim, but please do [open an Issue](https://github.com/Yilin-Yang/VSCrib.vim/issues)
as well.

### Dependencies

VSCrib.vim depends on [vim-maktaba.](https://github.com/google/vim-maktaba/)

Installation
--------------------------------------------------------------------------------

With [vim-plug](https://github.com/junegunn/vim-plug),

```vim
call plug#begin('~/.vim/bundle')
" ...
Plug 'Yilin-Yang/VSCrib.vim'

  " dependencies
  Plug 'Google/vim-maktaba'

" ...
call plug#end()
```

VSCrib.vim also includes an [`addon-info.json`](https://github.com/google/vim-maktaba/wiki/Creating-Vim-Plugins-with-Maktaba#plugin_metadata)
file, allowing for dependency resolution (i.e. automatic installation of
`vim-maktaba`) in [compatible plugin managers.](https://github.com/MarcWeber/vim-addon-manager)

Basic Usage
--------------------------------------------------------------------------------
VSCrib.vim is a [maktaba-style library plugin](https://github.com/google/vim-maktaba/blob/ffdb1a5a9921f7fd722c84d0f60e166f9916b67d/vroom/libraries.vroom),
that is, VSCrib.vim does not directly offer any user-facing functionality and is
meant for exclusive use in other plugins.

The VSCrib.vim interface is accessible through the [VSCrib object.](./autoload/vscrib.vim)
A call to `function! vscrib#New()` will return a VSCrib object, which:

- Can search for the "active VSCode workspace," i.e. a folder containing a `.vscode`
  directory, which can start from the current working directory, or from
  a directory given as an argument, and,
- Can search for, read, and parse JSON configuration files found in such
  `.vscode` folders, and,
- Stores an internal cache of "VSCode variables" that VSCode uses for [variable
  substitution](https://code.visualstudio.com/docs/editor/variables-reference)
  when parsing its configuration files, populating these variables from the
  current workspace (and other contextual information), and,
- Can update said cache through calls to `Refresh()`, and,
- When parsing JSON configuration files, can perform variable substitution on
  JSON entries (e.g. replacement of `${fileBasename}` with the name of the
  current file) using cached variables.

See `:help VSCrib` for more details.

Contribution
--------------------------------------------------------------------------------
Documentation is generated using [vimdoc.](https://github.com/google/vimdoc)

```bash
# from project root, after installing vimdoc,
vimdoc .
```

VSCrib.vim uses [vader.vim](https://github.com/junegunn/vader.vim) as its
testing framework. To run tests,

```bash
# from project root, with `vader.vim` installed,
cd test
./run_tests.sh
```

See `./run_tests --help` for additional usage details.

License
--------------------------------------------------------------------------------
MIT
