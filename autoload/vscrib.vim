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
" @dict VSCrib
" A 'cribbed' VSCode working 'state', encompassing an active workspace.
"
" This encapsulation in an object (as opposed to a 'purely functional'
" approach) is meant to prevent concurrency issues arising from multiple
" plugins using VSCrib at the same time.
"
" If VSCrib.vim had a *single* global state (of workspace variables, etc.), then
" that state could be clobbered by calls to @function(SetVariables) made by
" other plugins; e.g. if one plugin wants to update the active workspace only
" when the user `cd`s into another directory, while another wants to update
" whenever the user opens a new file, then one plugin could overwrite the
" shared workspace state 'while the other wasn't looking.'
"
" To avoid this, VSCrib.vim's interface is tied to a VSCrib *object*: the
" 'state' of the workspace is fully contained by this object. So the two
" plugins mentioned above would have two *different* objects, with two
" independently modifiable states, and neither would have to consider the
" other's existence.

""
" Create a @dict(VSCrib) object.
function! vscrib#New() abort
  return {
      \ 'TYPE': {'VSCrib': 1},
      \ '__vars': deepcopy(s:vscode_variables),
      \ 'FindWorkspace': function('vscrib#FindWorkspace'),
      \ 'VariablesFrom': function('vscrib#VariablesFrom'),
      \ 'Refresh': function('vscrib#Refresh'),
      \ 'GetVariables': function('vscrib#GetVariables'),
      \ 'StripComments': function('vscrib#StripComments'),
      \ 'GetWorkspaceJSON': function('vscrib#GetWorkspaceJSON'),
      \ 'Substitute': function('vscrib#Substitute'),
      \ }
endfunction

function! s:StrDump(obj) abort
  let l:str = ''
  redir => l:str
    silent! echo a:obj
  redir end
  return l:str
endfunction

""
" Type check to make sure that a VSCrib function wasn't accidentally assigned
" into another dictionary, e.g. as an incorrectly bound callback function.
" @throws WrongType
" @private
function! vscrib#CheckType(obj) abort
  if type(a:obj) !=# v:t_dict
      \ || !has_key(a:obj, 'TYPE')
      \ || !has_key(a:obj['TYPE'], 'VSCrib')
    throw maktaba#error#WrongType(
        \ 'self object isn''t a VSCrib: %s', s:StrDump(a:obj))
  endif
endfunction

""
" @dict VSCrib
" Search upwards from the current directory to find a `.vscode` folder,
" returning the absolute filepath of the folder containing `.vscode` if found,
" without trailing slash.
"
" {search_from} should be an absolute filepath to a directory.
" @throws BadValue  If {search_from} isn't an absolute path.
" @throws NotFound  If a `.vscode` folder could not be found.
" @throws WrongType If {search_from} isn't a string.
function! vscrib#FindWorkspace(search_from) abort
  call maktaba#ensure#IsAbsolutePath(a:search_from)
  call maktaba#ensure#IsDirectory(a:search_from)
  let l:search_dir = maktaba#path#StripTrailingSlash(a:search_from)
  let l:fpath = ''
  let l:vscode_dir = '/.vscode'
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
  return maktaba#path#StripTrailingSlash(l:fpath)
endfunction

""
" @dict VSCrib
" Returns a dictionary of what the VSCode task/debugging variables would be,
" using the arguments given.
"
" {workspace} The absolute path to the workspace folder.
"
" {cwd}       The absolute path to the current working directory.
"
" {file}      The absolute path of the file currently open.
"
" {curpos}    The position of the cursor, as returned by `getcurpos()`.
"
" {selection} The current visual section.
"
" {vscode}    An absolute path to a VSCode executable, or garbage.
"
" @throws BadValue  If paths given are not absolute paths.
" @throws WrongType If arguments given are of the wrong type.
" @private
function! vscrib#VariablesFrom(
    \ workspace, cwd, file, curpos, selection, vscode) abort
  call maktaba#ensure#IsAbsolutePath(a:workspace)
  call maktaba#ensure#IsDirectory(a:workspace)
  call maktaba#ensure#IsAbsolutePath(a:cwd)
  call maktaba#ensure#IsDirectory(a:cwd)
  call maktaba#ensure#IsAbsolutePath(a:file)
  " call maktaba#ensure#IsFile(a:file)  " might be a nofile buffer
  call maktaba#ensure#IsString(a:file)
  call maktaba#ensure#IsList(a:curpos)
  call maktaba#ensure#IsString(a:selection)
  call maktaba#ensure#IsString(a:vscode)

  let l:file_basename = maktaba#path#Basename(a:file)
  let l:file_basename_split_on_period = split(l:file_basename, '\.')
  let l:file_extname = ''
  if len(l:file_basename_split_on_period) !=# 1
    let l:file_extname = '.'.l:file_basename_split_on_period[-1]
    unlet l:file_basename_split_on_period[-1]
  endif
  let l:file_basename_no_extension = join(l:file_basename_split_on_period, '.')

  let l:new_vars = {
      \ 'workspaceFolder': a:workspace,
      \ 'workspaceFolderBasename':
          \ maktaba#path#Basename(maktaba#path#StripTrailingSlash(a:workspace)),
      \ 'file': a:file,
      \ 'relativeFile': maktaba#path#MakeRelative(a:workspace, a:file),
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
" @dict VSCrib
" Updates the VSCode task/debugging variables cache, searching from the given
" directory (by default, the current working directory).
"
" [relative_to] is an absolute path to a directory, from which to start
"     searching for a `.vscode` folder.
" [vscode_exe]  is an absolute path to a VSCode executable, or garbage.
"
" @default relative_to=getcwd()
" @default vscode_exe='/NO_VSCODE_EXE_SPECIFIED'
" @throws NotFound  If no VSCode workspace folder could be found.
" @throws WrongType If [relative_to] or [vscode_exe ]aren't strings.
" @throws BadValue  If [relative_to] or [vscode_exe] aren't a directory and a file, respectively; or if either is not an absolute filepath.
function! vscrib#Refresh(...) dict abort
  call vscrib#CheckType(l:self)
  let a:relative_to = get(a:000, 0, getcwd())
  call maktaba#ensure#IsDirectory(a:relative_to)
  call maktaba#ensure#IsAbsolutePath(a:relative_to)

  let a:vscode_exe = get(a:000, 1, '/NO_VSCODE_EXE_SPECIFIED')
  try
    call maktaba#ensure#IsFile(a:vscode_exe)
    call maktaba#ensure#IsAbsolutePath(a:vscode_exe)
  catch /ERROR(NotFound)/
    " should be string, but IsFile already invokes IsString
  endtry

  let l:workspace = vscrib#FindWorkspace(a:relative_to)

  let l:self['__vars'] = vscrib#VariablesFrom(
      \ l:workspace, a:relative_to, expand('%:p'), getcurpos(),
      \ maktaba#buffer#GetVisualSelection(), a:vscode_exe
      \ )
endfunction

""
" @dict VSCrib
" Returns the currently cached VSCode task/debugging variables; if [mutable]
" is true, returns a mutable reference to the cache instead of a deep copy.
" @throws WrongType If [mutable] is not a boolean value.
function! vscrib#GetVariables(...) dict abort
  call vscrib#CheckType(l:self)
  let a:mutable = get(a:000, 0, v:false)
  if type(a:mutable) !=# v:t_bool && !maktaba#value#IsNumber(a:mutable)
    throw maktaba#error#WrongType('Did not receive a boolean.')
  endif
  let l:vscode_vars = l:self['__vars']
  return a:mutable ? l:vscode_vars : deepcopy(l:vscode_vars)
endfunction

""
" Remove inline comments (e.g. `// this sort of comment`) from the given
" string, if present, and return it.
" @throws WrongType If not given a string.
" @throws BadValue  If the given string contains newlines or carriage returns.
function! vscrib#StripComments(line) abort
  call maktaba#ensure#IsString(a:line)
  if match(a:line, '^\s\{-}//') ==# 0
    " entire line is a comment
    return ''
  endif
  if match(a:line, '[\r\n]') !=# -1
    throw maktaba#error#BadValue(
        \ 'Given string contained CR and/or LF: %s', a:line)
  endif

  " check if file has inline code comments
  " make sure that the '//' doesn't occur inside a string literal
  let l:quote_stack = []
  let l:comment_idx = -1
  let l:i = 0 | while l:i <# len(a:line)
    let l:char = a:line[l:i]
    if l:char ==# '"'
      if l:i !=# 0 && a:line[l:i - 1] ==# '\'
        " escaped quote character, ignore
      elseif empty(l:quote_stack) || l:quote_stack[-1] !=# l:char
        call add(l:quote_stack, l:char)
      else
        unlet l:quote_stack[-1]  " pop matched quotation mark
      endif
    elseif l:char ==# '/'
      if l:i ==# len(a:line) - 1
        break  " line ended with (probably illegal) slash, but not comment
      endif
      if a:line[l:i + 1] ==# '/'
        " found a //
        if empty(l:quote_stack)
          let l:comment_idx = l:i
          break
        else
          " found a // inside a set of quotes
          let l:i += 1  " skip the known / to follow
        endif
      endif
    endif
  let l:i += 1 | endwhile

  if l:comment_idx ==# -1
    return a:line
  endif

  return a:line[ : l:comment_idx - 1]
endfunction

""
" @dict VSCrib
" Return the nearest JSON file with named [filename] that can be found in a
" `.vscode` directory, parsed into a dictionary, searching from the cached
" workspace folder.
"
" If the JSON file can't be found in the current workspace folder, will
" search up to find the closest parent directory containing the requested file
" in a `.vscode` directory. If one is found, but it cannot be read or parsed,
" will continue searching upwards into parent directories.
"
" @default filename='launch.json'
" @default workspace_folder=The cached value of 'workspaceFolder'.
" @throws NotFound    If no workspace folder is currently set; or if the requested file could be found in the current workspace folder, or any of its parent directories.
function! vscrib#GetWorkspaceJSON(...) dict abort
  call vscrib#CheckType(l:self)
  let a:filename = get(a:000, 0, 'launch.json')
  call maktaba#ensure#IsString(a:filename)
  let a:workspace = get(a:000, 1, l:self['__vars']['workspaceFolder'])
  let l:workspace = a:workspace  " mutable 'working copy'
  if empty(l:workspace)
    throw maktaba#error#NotFound('workspaceFolder not set/given!')
  endif

  let l:workspace = maktaba#path#StripTrailingSlash(l:workspace)
  let l:target_json = l:workspace.'/.vscode/'.a:filename

  while !maktaba#path#Exists(l:target_json)
    if l:workspace ==# maktaba#path#RootComponent(l:workspace)
      throw maktaba#error#NotFound(
          \ 'Could not find working %s searching from: %s',
          \ a:filename,
          \ a:workspace)
    endif
    let l:workspace = maktaba#path#Dirname(l:workspace)
    let l:target_json = l:workspace.'/.vscode/'.a:filename
  endwhile

  try
    let l:contents = readfile(l:target_json)

    " VSCode JSON files might include illegal comments; strip those
    let l:i = len(l:contents) - 1 | while l:i >=# 0 && !empty(l:contents)
      let l:line = vscrib#StripComments(l:contents[l:i])
      if empty(l:line)
        unlet l:contents[l:i]
      else
        let l:contents[l:i] = l:line
      endif
    let l:i -= 1 | endwhile

    let l:json = json_decode(join(l:contents, "\n"))
  catch /E484/  " Can't open file
    let l:workspace = maktaba#path#Dirname(l:workspace)
    return l:self.GetWorkspaceJSON(a:filename, l:workspace)
  catch /E474/  " Failed to parse
    let l:workspace = maktaba#path#Dirname(l:workspace)
    return l:self.GetWorkspaceJSON(a:filename, l:workspace)
  endtry
  return l:json
endfunction

""
" @dict VSCrib
" Perform VSCode's task/debugging variable substitution on {line} using cached
" variables and return it.
"
" As of the time of writing, this function does NOT support substitution of
" VSCode settings and commands, e.g. `${config:editor.fontSize}` or
" `${command.explorer.newFolder}`. Attempted substitution of these variables
" will produce errors, unless [ignore_unrecognized] is true.
"
" VSCode normally offers 'input' variables (see: https://code.visualstudio.com/docs/editor/variables-reference)
" that allow tasks and launch configurations to prompt for user input, e.g.
" for the name of the executable to debug. This function offers limited
" support for user input: variables of the form `${prompt:Message goes here}`
" will, if [no_interactive] is set to false, prompt the user for input using
" vim's `input()` function. (In this case, the prompt would be: 'Message goes
" here: <CURSOR>', with `<CURSOR>` being the position of the user's cursor.)
"
" Does not invoke `inputsave()` or `inputrestore()` if [no_inputsave] is set
" to true. This is useful when automatically supplying answers to interactive
" user prompts, e.g. in writing test cases for this function.
"
" @default ignore_unrecognized=v:true
" @default no_interactive=v:false
" @default no_inputsave=v:false
" @throws WrongType If {line} is not a string.
" @throws BadValue  If the line contains malformed variables, OR if the line contains unrecognized variables and [ignore_unrecognized] is false, OR if [no_interactive] is set to true and dynamic variables that prompt for user input are in the string, OR if the given line contains newline characters or carriage returns.
function! vscrib#Substitute(line, ...) dict abort
  call vscrib#CheckType(l:self)
  let a:variables = l:self['__vars']
  let a:ignore_unrecognized = get(a:000, 0, v:false)
  let a:no_interactive = get(a:000, 1, v:false)
  let a:no_inputsave = get(a:000, 2, v:false)
  let l:line = maktaba#ensure#IsString(a:line)

  call maktaba#ensure#IsIn(a:ignore_unrecognized, [v:true, v:false, 1, 0])
  call maktaba#ensure#IsIn(a:no_interactive, [v:true, v:false, 1, 0])
  call maktaba#ensure#IsIn(a:no_inputsave, [v:true, v:false, 1, 0])

  let l:vars = []  " list of all variables to substitute
  let l:var = matchstr(l:line, s:var_search_pat) | while !empty(l:var)
    call add(l:vars, l:var)
    let l:first_after = matchend(l:line, s:var_search_pat)
    let l:line = l:line[l:first_after : ]
  let l:var = matchstr(l:line, s:var_search_pat) | endwhile

  let l:sub_vals = []
  let l:i = 0 | while l:i <# len(l:vars)
    let l:var = l:vars[l:i]
    let l:var_no_braces = l:var[2:-2]  " trim ${ and }
    if has_key(a:variables, l:var_no_braces)
      call add(l:sub_vals, a:variables[l:var_no_braces])
    elseif match(l:var, s:env_search_pat) !=# -1
      let l:env = l:var[matchend(l:var, s:env_search_pat) : -1]
      execute 'call add(l:sub_vals, $'.l:env.')'
    elseif match(l:var, s:prompt_search_pat) !=# -1
      if a:no_interactive
        throw maktaba#error#BadValue(
            \ 'Substitution would prompt for user input: %s', l:var)
      endif
      let l:prompt_msg = l:var[matchend(l:var, s:prompt_search_pat) : -2]
      if !a:no_inputsave | call inputsave() | endif
      let l:input = input(l:prompt_msg.': ',
        \ '',
        \ 'file'
        \ )
      if !a:no_inputsave | call inputrestore() | endif
      call add(l:sub_vals, l:input)
    elseif a:ignore_unrecognized
      unlet l:vars[l:i]  " don't substitute this one
      let l:i -= 1  " don't skip the next variable
    else
      throw maktaba#error#NotImplemented(
          \ 'VSCode dynamic variables not yet supported: %s', l:var)
    endif
  let l:i += 1 | endwhile

  let l:line = a:line  " reset to original value
  let l:i = 0 | while l:i <# len(l:vars)
    let l:var = l:vars[l:i]
    let l:sub = l:sub_vals[l:i]
    let l:line = substitute(l:line, l:var, l:sub, '')
  let l:i += 1 | endwhile

  return l:line
endfunction
let s:var_search_pat = '${.\{-}}'
let s:env_search_pat = '^${env:'
let s:prompt_search_pat = '^${prompt:'
