""
" @section Introduction, intro
" @stylized VSCrib.vim
" @library
" @order intro functions
" A VimL library for for cribbing project infrastructure used by VSCode and
" twisting it to one's own nefarious ends.
"
" The primary purpose of this plugin is to locate `.vscode` folders and the
" JSON configuration files held within. This allows for a limited degree of
" 'letting vim pretend to be VSCode' for the purposes of writing plugins.

let s:vscode_variables = {
    \ 'workspaceFolder': '',
    \ 'workspaceFolderBasename': '',
    \ 'file': '',
    \ 'relativeFile': '',
    \ 'fileBasename': '',
    \ 'fileBasenameNoExtension': '',
    \ 'fileDirname': '',
    \ 'fileExtname': '',
    \ 'cwd': '',
    \ 'lineNumber': '',
    \ 'selectedText': '',
    \ 'execPath': '',
    \ }

""
" Search upwards from the current directory to find a `.vscode` folder,
" returning the absolute filepath of the folder containing `.vscode` if found.
"
" {search_from} should be an absolute filepath.
" @throws BadValue  If {search_from} isn't an absolute path.
" @throws NotFound  If a `.vscode` folder could not be found.
" @throws WrongType If {search_from} isn't a string.
function! vscrib#FindWorkspace(search_from) abort
  call maktaba#ensure#IsString(a:search_from)
  let l:search_dir = maktaba#ensure#IsAbsolutePath(a:search_from)
  let l:fpath = ''
  let l:vscode_dir = '.vscode'
  while empty(l:fpath)
    if maktaba#path#Exists(l:search_dir . l:vscode_dir)
      let l:fpath = l:search_dir
    else
      let l:search_dir = maktaba#path#Dirname(l:search_dir)
    endif
    if empty(l:search_dir)
        \ || l:search_dir ==# maktaba#path#RootComponent(l:search_dir)
      throw maktaba#error#NotFound(
          \ 'Could not find .vscode folder when searching from: %s',
          \ a:search_from)
    endif
  endwhile
endfunction

""
" Returns a dictionary of what the VSCode task/debugging variables would be,
" using the arguments given.
"
" {workspace} The absolute path to the workspace folder.
" {cwd}       The absolute path to the current working directory.
" {file}      The absolute path of the file currently open.
" {curpos}    The position of the cursor, as returned by `getcurpos()`.
" {selection} The current visual section.
" {vscode}    An absolute path to a VSCode executable, or garbage.
" @throws BadValue  If paths given are not absolute paths.
" @throws WrongType If arguments given are of the wrong type.
function! vscrib#VariablesFrom(
    \ workspace, cwd, file, curpos, selection, vscode) abort
  call maktaba#ensure#IsAbsolutePath(a:workspace)
  call maktaba#ensuire#IsDirectory(a:workspace)
  call maktaba#ensure#IsAbsolutePath(a:cwd)
  call maktaba#ensuire#IsDirectory(a:cwd)
  call maktaba#ensure#IsAbsolutePath(a:file)
  call maktaba#ensuire#IsFile(a:file)
  call maktaba#ensure#IsList(a:curpos)
  call maktaba#ensure#IsString(a:selection)
  call maktaba#ensure#IsString(a:vscode)

  let l:file_basename = maktaba#path#Basename(a:file)
  let l:file_basename_split_on_period = split(l:file_basename, '\.')
  let l:file_extname = ''
  if len(l:file_basename_split_on_period) !=# 1
    let l:file_extname = l:file_basename_split_on_period[-1]
    unlet l:file_basename_split_on_period[-1]
  endif
  let l:file_basename_no_extension = join(l:file_basename_split_on_period, '.')

  let l:new_vars = {
      \ 'workspaceFolder': a:workspace,
      \ 'workspaceFolderBasename':
          \ maktaba#path#Basename(maktaba#path#StripTrailingSlash(a:workspace)),
      \ 'file': a:file,
      \ 'relativeFile': maktaba#path#MakeRelative(a:cwd, a:file),
      \ 'fileBasename': maktaba#path#Basename(a:file),
      \ 'fileBasenameNoExtension': l:file_basename_no_extension,
      \ 'fileDirname': maktaba#path#Dirname(a:file),
      \ 'fileExtname': l:file_extname,
      \ 'cwd': a:cwd,
      \ 'lineNumber': a:curpos[1],
      \ 'selectedText': a:selection,
      \ 'execPath': a:vscode,
      \ }
  return l:new_vars
endfunction

""
" Updates the VSCode task/debugging variables cache, searching from the given
" directory (by default, the current working directory).
"
" [relative_to] is an absolute path to a directory, from which to start
"     searching for a `.vscode` folder.
" [vscode_exe]  is an absolute path to a VSCode executable, or garbage.
"
" @default relative_to=getcwd()
" @default vscode_exe='NO_VSCODE_EXE_SPECIFIED'
" @throws NotFound  If no VSCode workspace folder could be found.
" @throws WrongType If [relative_to] or [vscode_exe ]aren't strings.
" @throws BadValue  If [relative_to] or [vscode_exe] aren't a directory and a
"     file, respectively; or if either is not an absolute filepath.
function! vscrib#SetVSCodeVariables(...) abort
  let a:relative_to = get(a:, 0, getcwd())
  call maktaba#ensure#IsDirectory(a:relative_to)
  call maktaba#ensure#IsAbsolutePath(a:relative_to)

  let a:vscode_exe = get(a:, 1, '/NO_VSCODE_EXE_SPECIFIED')
  call maktaba#ensure#IsFile(a:vscode_exe)
  call maktaba#ensure#IsAbsolutePath(a:vscode_exe)

  let l:workspace = vscrib#FindWorkspace(a:relative_to)

  let s:vscode_variables = vscrib#VariablesFrom(
      \ l:workspace, a:relative_to, expand('%:p'), getcurpos(),
      \ maktaba#buffer#GetVisualSelection(),
      \ )
endfunction

""
" Return the nearest `launch.json` file, parsed into a dictionary, using the
" cached VSCode workspace variables.
"
" If no `launch.json` file is found in the current workspace folder, will
" search up to find the closest parent directory containing a
" `.vscode/launch.json` file.
"
" @throws NotFound    If no workspace folder is currently set; or if no
"     `launch.json` file could be found in the current workspace folder, or
"     any of its parent directories.
" @throws IOError     If the found `launch.json` file could not be opened.
" @throws ParseError  If the `launch.json` file could not be parsed.
function! vscrib#GetLaunchJSON() abort
  if empty(s:vscode_variables['workspaceFolder'])
    throw maktaba#error#NotFound('workspaceFolder not set!')
  endif

  let l:workspace =
      \ maktaba#path#StripTrailingSlash(s:vscode_variables['workspaceFolder'])
  let l:launch_json = l:workspace.'/.vscode/launch.json'

  while !maktaba#path#Exists(l:launch_json)
    if l:workspace ==# maktaba#path#RootCompnent(l:workspace)
      throw maktaba#error#NotFound(
          \ 'Could not find launch.json searching from: %s',
          \ s:vscode_variables['workspaceFolder'])
    endif
    let l:workspace = maktaba#path#Dirname(l:workspace)
    let l:launch_json = l:workspace.'/.vscode/launch.json'
  endwhile

  try
    let l:contents = readfile(l:launch_json)
    let l:json = json_decode(l:launch_json)
  catch /E484/  " Can't open file
    throw maktaba#error#Exception(
        \ 'IOError', 'Could not read file: %s', l:launch_json)
  catch /E474/  " Failed to parse
    throw maktaba#error#Exception(
        \ 'ParseError', 'Could not parse JSON. Err: %s', v:exception)
  endtry
  return l:json
endfunction
