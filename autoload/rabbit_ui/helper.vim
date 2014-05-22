
function! rabbit_ui#helper#id()
  return 'rabbit-ui'
endfunction
function! rabbit_ui#helper#exception(msg)
  throw printf('[%s] %s', rabbit_ui#helper#id(), a:msg)
endfunction
function! rabbit_ui#helper#set_common_options(option)
  let option = a:option

  let option['box_top'] = abs(get(option, 'box_top', &lines / 4 * 1))
  let option['box_bottom'] = abs(get(option, 'box_bottom', &lines / 4 * 3))
  if option['box_bottom'] < option['box_top']
    call rabbit_ui#helper#exception('rabbit_ui#choices: box_top is larger than box_bottom.')
  endif

  let option['box_left'] = abs(get(option, 'box_left', &columns / 4 * 1))
  let option['box_right'] = abs(get(option, 'box_right', &columns / 4 * 3))
  if option['box_right'] < option['box_left']
    call rabbit_ui#helper#exception('rabbit_ui#choices: box_left is larger than box_right.')
  endif

  let option['box_width'] = option['box_right'] - option['box_left'] + 1
  let option['box_height'] = option['box_bottom'] - option['box_top'] + 1

  call s:init_highlights(option)

  return option
endfunction
function! rabbit_ui#helper#redraw_line(line_num, box_left, text)
  let orgline = getline(a:line_num)
  let line = orgline . repeat(' ', &columns - strdisplaywidth(orgline))
  let str = rabbit_ui#helper#smart_split(line, a:box_left)[0]
  let str .= a:text
  let str .= line[(strdisplaywidth(str)):]
  if orgline isnot str
    call setline(a:line_num, str)
  endif
endfunction
function! rabbit_ui#helper#smart_split(str, boxwidth)
  let lines = []

  let cs = split(a:str, '\zs')
  let cs_index = 0

  if a:boxwidth isnot 0
    let text = ''
    while cs_index < len(cs)
      if strdisplaywidth(text . cs[cs_index]) == a:boxwidth
        let text .= cs[cs_index]
        let cs_index += 1
        let lines += [text]
        let text = ''
      elseif strdisplaywidth(text . cs[cs_index]) < a:boxwidth
        let text .= cs[cs_index]
        let cs_index += 1
      elseif strdisplaywidth(text . cs[cs_index]) > a:boxwidth
        let text .= ' '
        let lines += [text]
        let text = cs[cs_index]
        let cs_index += 1
      endif
    endwhile
    let text .= repeat(' ', a:boxwidth - strdisplaywidth(text))
    let lines += [text]
  else
    let lines += ['']
  endif

  return lines
endfunction
function! rabbit_ui#helper#wrapper(funcname, option)
  let saved_hlsearch = &hlsearch
  let saved_currtabindex = tabpagenr()
  let saved_titlestring = &titlestring
  let rtn_value = ''
  try

    let background_lines = []
    for line in getline(line('w0'), line('w0') + &lines) + repeat([''], &lines)
      let background_lines += [
            \ join(map(split(line,'\zs'), 'strdisplaywidth(v:val) isnot 1 ? ".." : v:val'), '')
            \ ]
    endfor

    tabnew
    normal gg

    setlocal nolist
    setlocal nowrap
    setlocal nospell
    setlocal nonumber
    setlocal nohlsearch
    setlocal buftype=nofile nobuflisted noswapfile bufhidden=hide
    setfiletype rabbit-ui
    let &l:titlestring = printf('[%s]', rabbit_ui#helper#id())

    unlet rtn_value
    let rtn_value = call(a:funcname, [extend(a:option, {
          \   'background_lines' : background_lines,
          \ })])
  finally
    tabclose
    let &l:hlsearch = saved_hlsearch
    let &l:titlestring = saved_titlestring
    execute 'tabnext' . saved_currtabindex
    redraw
  endtry

  return rtn_value
endfunction
function! rabbit_ui#helper#clear_highlights()
  call s:clear_highlight('rabbituiTitleLine')
  call s:clear_highlight('rabbituiSelectedItemActive')
  call s:clear_highlight('rabbituiSelectedItemNoActive')
  call s:clear_highlight('rabbituiTextLinesOdd')
  call s:clear_highlight('rabbituiTextLinesEven')
endfunction
function! rabbit_ui#helper#set_highlight(prefix_groupname, line, col, size)
  let groupname = printf('%s_%d_%d_%d', a:prefix_groupname, a:line, a:col, a:size)
  execute printf('syntax match %s /\%%%dl\%%%dv.\{%d,%d}/ containedin=ALL', groupname, a:line, a:col, a:size, a:size)
  execute printf('highlight! default link %s %s', groupname, a:prefix_groupname)
endfunction
function! s:init_highlights(option)
  let highlights = get(a:option, 'highlights', [])

  let default_table = {
        \   'rabbituiTitleLine' : { 'guifg' : '#ffffff', 'guibg' : '#aaaaee', 'gui' : 'bold' },
        \   'rabbituiTextLinesEven' : { 'guifg' : '#000000', 'guibg' : '#ddddff', 'gui' : 'none' },
        \   'rabbituiTextLinesOdd' : { 'guifg' : '#000000', 'guibg' : '#ffffff', 'gui' : 'none' },
        \   'rabbituiSelectedItemActive' : { 'guifg' : '#ffff00', 'guibg' : '#888888', 'gui' : 'bold' },
        \   'rabbituiSelectedItemNoActive' : { 'guifg' : '#000000', 'guibg' : '#bbbbbb', 'gui' : 'none' },
        \ }
  for x in keys(default_table)
    execute printf('highlight! %s guifg=%s guibg=%s gui=%s',
          \   x,
          \   get(get(highlights, x, {}), 'guifg', default_table[x]['guifg']),
          \   get(get(highlights, x, {}), 'guibg', default_table[x]['guibg']),
          \   get(get(highlights, x, {}), 'gui', default_table[x]['gui'])
          \ )
  endfor
endfunction
function! s:clear_highlight(prefix_groupname)
  redir => lines
  silent! highlight
  redir END
  for line in split(lines, "\n")
    let m = matchlist(line, printf('\(%s.*\)\s\+xxx links to', a:prefix_groupname))
    if !empty(m)
      try
        execute printf('syntax clear %s', m[1])
        execute printf('highlight default link %s NONE', m[1])
      catch /.*/
      endtry
    endif
  endfor
endfunction

