let s:path = expand('<sfile>:p:h:h')

python <<NOMAS
import sys
import time
import urllib
import urllib2
import vim
import os
import subprocess
NOMAS

function! scrimbavim#EvaluateSelection()
  call scrimbavim#evaluateJS(scrimbavim#get_visual_selection())
endfunction

function! scrimbavim#EvaluateBuffer()
  call scrimbavim#evaluateJS(join(getline(1,'$')," "))
endfunction

function! scrimbavim#EvaluateWord()
  call scrimbavim#evaluateJS(expand("<cword>") . "()")
endfunction

function! scrimbavim#evaluateJS(js)
  python urllib2.urlopen(urllib2.Request(vim.eval("g:scrimba_serverpath") + "/evaluate", vim.eval("a:js")))
endfunction

function! scrimbavim#sendCommand(command)
  python <<EOF
try:
  urllib2.urlopen(vim.eval("g:scrimba_serverpath") + "/" + vim.eval("a:command")).read()
except:
  vim.command("call scrimbavim#startscrimbavim()")
EOF
endfunction

function! scrimbavim#startscrimbavim()
  if has("win32")
    execute 'cd' fnameescape(s:path . "/scrimbavim")
    call system("./start.bat")
    execute 'cd -'
  else
    execute 'cd' fnameescape(s:path . "/scrimbavim")
    call system("node scrimbavim.js &")
    execute 'cd -'
  endif
endfunction

function! scrimbavim#getConsole()
  normal ggdG
python <<EOF
data = urllib2.urlopen(vim.eval("g:scrimb_serverpath") + "/console").read()
for line in data.split("\n"):
  vim.current.buffer.append(line)
EOF
  setlocal nomodified
  nnoremap <buffer> i :scrimbaEval
  nnoremap <buffer> cc :scrimbaConsoleClear<cr>:e<cr>
  nnoremap <buffer> r :e!<cr>
  nnoremap <buffer> <cr> :scrimbaTraceLine<cr>
endfunction

function! scrimbavim#url2path(url)
  let path = a:url
  " strip off any fragment identifiers
  let hashIdx = stridx(a:url, '#')
  if hashIdx > -1
    let path = strpart(path, 0, hashIdx)
  endif
  " translate file-URLs
  if stridx(path,'file://') == 0
    return strpart(path,7)
  endif
  " for everything else, look up user-defined mappings
  if exists("g:scrimba_urlpaths")
    for key in keys(g:scrimba_urlpaths)
      if stridx(path, key) == 0
        return g:scrimba_urlpaths[key] . strpart(path, strlen(key))
      endif
    endfor
  endif
  return path
endfunction

function! scrimbavim#getErrors()
python <<EOF
data = urllib2.urlopen(vim.eval("g:scrimba_serverpath") + "/errors").readlines()
vim.command("let errors = %s" % [e.strip() for e in data])
EOF
  set errorformat+=%f:%l:%m
  let qfitems = []
  for errorstr in errors
    let error = eval(errorstr)
    let msg = error.message
    if error.multiplicity > 1
      let msg = msg . ' (' . error.multiplicity . ' times)'
    endif
    let qfitems = qfitems + [scrimbavim#url2path(error.url) . ':' . error.lineNumber . ':' . msg]
  endfor
  cexpr join(qfitems, "\n")
endfunction

function! scrimbavim#clearErrors()
python <<EOF
urllib2.urlopen(vim.eval("g:scrimba_serverpath") + "/clearerrors")
EOF
endfunction

function! scrimbavim#traceLine()
python <<EOF

line = vim.eval("getline('.')")
fragments = line.split('/')
page = fragments[-1].split(':')[0]
line = fragments[-1].split(':')[1]

vim.command("b " + page)
vim.command(":" + line)
EOF
endfunction

function! scrimbavim#get_visual_selection()
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  let lines[-1] = lines[-1][: col2 - 2]
  let lines[0] = lines[0][col1 - 1:]
  return join(lines, " ")
endfunction

" --------------------------

function! scrimbavim#sendCursor()
if exists("g:scrimba_active")
python <<EOF
line = vim.eval("line('.')")
col  = vim.eval("col('.')")
try:
  urllib2.urlopen(vim.eval("g:scrimba_serverpath") + "/" + "cursor/" + line + "/" + col).read()
except:
  vim.command("call scrimbavim#startscrimbavim()")
EOF
endif
endfunction

function! scrimbavim#fileChanged()
if exists("g:scrimba_active")
python <<EOF
name = vim.eval("expand('%:t')")
try:
  urllib2.urlopen(vim.eval("g:scrimba_serverpath") + "/" + "fileChanged/" + name).read()
except:
  vim.command("call scrimbavim#startscrimbavim()")
EOF
endif
endfunction

function! scrimbavim#reloadGeneric()
if exists("g:scrimba_active")
python <<EOF
name = vim.eval("expand('%:t')")
# pth  = vim.eval("expand('%:p:h')")
txt  = urllib.pathname2url(vim.eval("join(getline(1,'$'), '\n')"))
try:
  # urllib2.urlopen(vim.eval("g:scrimba_serverpath") + "/" + "reload/" + name + "/" + pth).read()
  urllib2.urlopen(vim.eval("g:scrimba_serverpath") + "/" + "reload/" + name + "/" + txt).read()
except:
  vim.command("call scrimbavim#startscrimbavim()")
EOF
endif
endfunction

function! scrimbavim#download()
if !exists("g:scrimba_active")
  call scrimbavim#start()
endif
python <<EOF
pth = vim.eval("expand('%:p:h')");
try:
  urllib2.urlopen(vim.eval("g:scrimba_serverpath") + "/" + "download" + "/" + pth).read()
except:
  vim.command("call scrimbavim#startscrimbavim()")
EOF
endfunction

function! scrimbavim#start()
  let g:scrimba_active=1
  call scrimbavim#startscrimbavim()
endfunction
