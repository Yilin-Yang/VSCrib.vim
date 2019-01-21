VSCrib.vim
================================================================================
A VimL library for cribbing project infrastructure and workspace configurations
from VSCode.

Prerequisites
--------------------------------------------------------------------------------
VSCrib.vim requires at least [Vim 7.4.1304](https://github.com/vim/vim/commit/7823a3bd2eed6ff9e544d201de96710bd5344aaf)
or [practically any recent version of neovim.](https://github.com/neovim/neovim/commit/4dcd19d9bc2417051ddbda177010ca8c0cb2cf73)

In practice, VSCrib is primarily developed using neovim 0.3.4+, with only
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
# from project root,
cd test
./run_tests.sh [--vim|--neovim] [-v|--visible] [-f <TEST_FILE> | --file=<TEST_FILE>]
```

For example, `./run_tests.sh --neovim -v` runs all tests in an interactive
neovim instance. `./run_tests.sh -f test-Foo.vader` runs only `test-Foo.vader`
in a "backgrounded" vim instance.
