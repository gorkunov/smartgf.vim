"smartgf.vim - Goto file on steroids
"
"Author: Alex Gorkunov <alex.gorkunov@cloudcastlegroup.com>
"Source repository: https://github.com/gorkunov/smartgf.vim
"
"vim: set tabstop=4 softtabstop=4 shiftwidth=4 expandtab

"avoid installing twice
"if exists('g:loaded_smartgf')
    "finish
"endif
"check if debugging is turned off
if !exists('g:smartgf_debug')
    let g:loaded_smartgf = 1
end

"max visible search results on page
if !exists('g:smartgf_max_entries_per_page')
    let g:smartgf_max_entries_per_page = 9
end

"check key mappings
if !exists('g:smartgf_key')
    "disable rails mappings if smartgf uses default mapping (it override gf for each buffer)
    let g:rails_mappings = 0
    let g:smartgf_key = 'gf'
endif
if !exists('g:smartgf_no_filter_key')
    let g:smartgf_no_filter_key = 'gF'
endif

"define divider width between text and file path in the results
if !exists('g:smartgf_divider_width')
    let g:smartgf_divider_width = 5
endif

"detect system ack (thanks Ack.vim)
let s:ack = executable('ack-grep') ? 'ack-grep' : 'ack'
let s:ack .= ' -H --nocolor --nogroup --column '


"get dictionary with color settings from hi group
function! s:ExtractColorsFromHighlightGroup(group)
    redir => group | exe 'silent highlight '. a:group | redir END
    let out = split(matchlist(group,  '\<xxx\>\s\+\(.*\)')[1], '\n')
    let out = split(out[0], ' ')
    let result = {}
    for ln in out
        let [name, color] = split(ln, '=')
        let result[name] = color
    endfor
    return result
endfunction

"define new hi group with *name* based on *parent* group 
"but with overrided colors from *mixparent* 
function! s:DefineHighlight(name, parent, mixparent)

    let parent_colors = {}
    if a:parent != ''
        let parent_colors = s:ExtractColorsFromHighlightGroup(a:parent)
    endif

    let mixparent_colors = {}
    if a:mixparent != ''
        let mixparent_colors = s:ExtractColorsFromHighlightGroup(a:mixparent)
    endif

    let mix_colors = copy(parent_colors)
    for [name, color] in items(mixparent_colors)
        let mix_colors[name] = color
    endfor
    let str = ''
    for [name, color] in items(mix_colors)
        let str .= ' ' . name . '=' . color
    endfor
    execute 'silent! hi! ' . a:name . str
endfunction

"define two hi groups
"the first (*name*) based on *base*
"the second (*name* + Selected) based on *base* and extended with CursorLine
function! s:DefineHighlightWithSelected(name, base)
    call s:DefineHighlight(a:name, a:base, '')
    call s:DefineHighlight(a:name . 'Selected', a:base, 'CursorLine')
endfunction

"define colors scheme for search results window
call s:DefineHighlight('SmartGfTitle', 'Title', '')
call s:DefineHighlight('SmartGfPrompt', 'Underlined', '')
call s:DefineHighlight('SmartGfSearchWord', 'Type', '')

"for rows style apply selected style too (from CursorLine style)
call s:DefineHighlightWithSelected('SmartGfIndex', 'Identifier')
call s:DefineHighlightWithSelected('SmartGfSearchLine', 'Statement')
call s:DefineHighlightWithSelected('SmartGfSearchLineHighlight', 'Search')
call s:DefineHighlightWithSelected('SmartGfDivider', '')
call s:DefineHighlightWithSelected('SmartGfFilePath', 'Comment')

"print line to command line with defined styles e.g.
"call s:Print('SmartGfTitle', 'text') -> 
"echohl SmartGfTitle | echo 'text' | echohl None
"must have even ordinal params number (for each pair the first is style the
"second is text)
"can accept array instead of params list (works as params list)
function! s:Print(...)
    let data = type(a:1) == type([]) ? a:1 : a:000
    let pos = 0
    while pos < len(data)
        execute 'echohl ' . data[pos]
        let pos += 1
        if pos == 1
            echo data[pos]
        else
            echon data[pos]
        endif
        let pos += 1
    endwhile
    echohl None
endfunction

"draw search results window 
"*word* search word
"*lines* list with results (each line contains text, file, line, col)
"*left_max_width* max allowed width for text part of line 
"*right_max_width* max allowed width for file part of line 
"*current_position* current selected line
"*start_at* shift from start of the list
function! s:DrawResults(word, lines, left_max_width, right_max_width, current_position, start_at)
    let index = a:start_at
    let length = len(a:lines)
    let end_at = length > g:smartgf_max_entries_per_page ? a:start_at + g:smartgf_max_entries_per_page : length
    let divider = repeat(' ', g:smartgf_divider_width)

    redraw!

    "show "Search result (1-9 of 20) for blabla:"
    call s:Print('SmartGfTitle', 'Search results (' . (a:start_at + 1) . '-' . end_at . ' of ' . len(a:lines) . ') for ',
            \ 'SmartGfSearchWord', a:word, 'SmartGfTitle', ':')

    "for each line show "x. search line     /file/path.txt:1"
    while index < len(a:lines) && index < end_at
        let line = []
        let entry = a:lines[index]
        let selected_flag = index == a:current_position ? 'Selected' : ''

        "show index for first 9 results (quick way to select result)
        let visible_index = index < 9 ? string(index + 1) : 'x'
        call add(line, 'SmartGfIndex' . selected_flag)
        call add(line,  visible_index . '. ')

        "cut text if it has symbols more than *left_max_width*
        let text = entry.text
        let length = strlen(text)
        if length > a:left_max_width
            let text = strpart(text, 0, a:left_max_width - 3) . '...'
        else
            let text .= repeat(' ', a:left_max_width - strlen(text))
        endif

        "highlight search word in the text
        let startpos = 0
        while 1
            let endpos = stridx(text, a:word, startpos)
            if endpos == -1 
                call add(line, 'SmartGfSearchLine' . selected_flag)
                call add(line, strpart(text, startpos))
                break
            endif
            call add(line, 'SmartGfSearchLine' . selected_flag)
            call add(line, strpart(text, startpos, endpos - startpos))
            call add(line, 'SmartGfSearchLineHighlight' . selected_flag)
            call add(line, strpart(text, endpos, strlen(a:word)))
            let startpos = endpos + strlen(a:word)
        endwhile

        "divider between text and file path
        call add(line, 'SmartGfDivider' . selected_flag)
        call add(line, divider)

        "cut file path if it has symbols more than *right_max_width*
        let filestr = entry.file . ':' . entry.ln
        let length = strlen(filestr)
        if length > a:right_max_width
            let filestr = '...' . strpart(filestr, length - a:right_max_width + 3, a:right_max_width - 3)
        else
            let filestr = repeat(' ', a:right_max_width - length) . filestr
        endif

        call add(line, 'SmartGfFilePath' . selected_flag)
        call add(line, filestr)

        call s:Print(line)
        let index += 1
    endwhile

    "show footer legend "Press 1-9 or use k,l and o,Enter to open file"
    call s:Print(['SmartGfPrompt', 'Press ', 'SmartGfIndex', '1-9', 'SmartGfPrompt', 
                \ ' or use ', 'SmartGfIndex', 'k', 'SmartGfPrompt', ',', 'SmartGfIndex', 'l', 'SmartGfPrompt', 
                \ ' and ', 'SmartGfIndex', 'o', 'SmartGfPrompt', ',', 'SmartGfIndex', 'Enter', 'SmartGfPrompt', ' to open file'])
endfunction

"open file by path in the new buffer 
"and set cursor position on the search word
"also centerized screen
function! s:Open(entry)
    execute 'silent! edit ' . a:entry.file
    execute "normal! " . a:entry.ln . "G" . a:entry.col . "|zz"
endfunction

"return whether *text* is comment
"for ruby: # or -#
"for js: // or # or * or /*
"for vim: "
function! s:IsComment(text, type)
    return     ((a:type == 'ruby' && match(a:text, '^-\?#') != -1)
           \ || (a:type == 'js'   && match(a:text, '^\(//\|#\|/\s*\*\|\*\)') != -1)
           \ || (a:type == 'vim'  && match(a:text, '^"') != -1))
endfunction

"return whether *text* has priority in the search results
"it can be a function definition or module or class etc
function! s:HasPriority(text, name, type)
    return     ((a:type == 'ruby' && match(a:text, 'def \+' . a:name . '[ (]') != -1)
           \ || (a:type == 'ruby' && match(a:text, '\(module\|class\) \+' . a:name . '\($\| \+\)') != -1)
           \ || (a:type == 'vim'  && match(a:text, 'function!\? \+\(.:\)\?' . a:name . '(') != -1))
endfunction

"main function: seach word under the cursor with ACK
function! s:Find(use_filter)
    let word = expand('<cword>')
    "skip if this is one symbol
    if strlen(word) < 2 | return | endif


    "get window width and calc max allowed width for results window
    let max_width = winwidth(0) - g:smartgf_divider_width - 4
    "left/right sections proportion
    let cells = 10.0
    let left_cells = 7
    let left_max_width = float2nr(max_width / cells * left_cells)

    "detect filetype
    "use filetype to filter search results
    let type = &ft
    let typestr = ''
    if a:use_filter
        if type == 'ruby' || type == 'haml'
            let type = 'ruby'
            let typestr = ' --ruby --haml'
        elseif type == 'js' || type == 'coffee'
            let type = 'js'
            let typestr = ' --js --coffee'
        elseif type == 'vim'
            let typestr = ' --vim'
        endif
    endif

    "show search in progress
    call s:Print('SmartGfTitle', 'Searching...') 

    "and run search
    let out = system(s:ack . shellescape(word) . typestr)
    let lines = []
    let left_real_max_width = 0
    for line in split(out, '\n')
        "result line:
        "/file/path.text:line:col:search text
        let [_, file, ln, col, text; rest] = matchlist(line, '\(.\{-}\):\(.\{-}\):\(.\{-}\):\(.*\)')
        "remove leading spaces
        "and at the end too
        let text = substitute(text, '^\s\+\|\s\+$', '', 'g')

        "skip comments
        if a:use_filter && s:IsComment(text, type)
            continue
        endif

        let data = { 'file': file, 'ln': ln, 'col': col, 'text': text }

        "set top priority for method/function definition
        if a:use_filter && s:HasPriority(text, word, type)
            call insert(lines, data)
        else
            call add(lines, data)
        end

        "calc real max width of text parts of lines
        let length = strlen(text)
        if length > left_real_max_width | let left_real_max_width = length | endif
    endfor

    redraw!

    "if nothing was found show message
    if len(lines) == 0
        call s:Print('SmartGfTitle', 'Nothing was found') 
        return
    endif

    "calc real width for left and right parts (text and file)
    if left_real_max_width > left_max_width | let left_real_max_width = left_max_width | endif
    let right_max_width = max_width - left_real_max_width


    "show results while user select file or press Esc
    let current_position = 0
    let results_count = len(lines)
    let start_at = 0
    let show = 1
    while show 
        call s:DrawResults(word, lines, left_real_max_width, right_max_width, current_position, start_at)
        let key = getchar()
        let ch = nr2char(key)
        let choice = str2nr(ch)
        redraw!
        let show = 0
        "change position to previous item
        if ch == 'j'
            let show = 1
            if current_position < results_count - 1
                let current_position += 1
                if current_position - start_at == g:smartgf_max_entries_per_page
                    let start_at += 1
                endif
            endif
        "change position to next item
        elseif ch == 'k'
            let show = 1
            if current_position > 0
                let current_position -= 1
                if current_position < start_at
                    let start_at -= 1
                endif
            endif
        "select file under the cursor
        elseif ch == 'o' || key == 13
            call s:Open(lines[current_position])
        "select file by shortcut
        elseif choice > 0 && choice < 10
            call s:Open(lines[choice - 1])
        endif
    endwhile
endfunction

"key mapping
silent exec 'nnoremap <silent> ' . g:smartgf_key . '  :<C-U>call <SID>Find(1)<CR>'
silent exec 'nnoremap <silent> ' . g:smartgf_no_filter_key . '  :<C-U>call <SID>Find(0)<CR>'
