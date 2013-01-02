let g:smartgf_max_entries_per_page = 9
let g:rails_mappings = 0
let g:smartgf_divider_width = 5

let s:ack = executable('ack-grep') ? 'ack-grep' : 'ack'
let s:ack .= ' -H --nocolor --nogroup --column '

function! s:ExtractColors(group)
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

function! s:DefineHighlight(name, parent, mixparent)

    let parent_colors = {}
    if a:parent != ''
        let parent_colors = s:ExtractColors(a:parent)
    endif

    let mixparent_colors = {}
    if a:mixparent != ''
        let mixparent_colors = s:ExtractColors(a:mixparent)
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

hi! link SmartGfTitle Title
hi! link SmartGfPrompt Underlined
hi! link SmartGfSearchWord Type

call s:DefineHighlight('SmartGfIndex',         'Identifier', '')
call s:DefineHighlight('SmartGfIndexSelected', 'Identifier', 'CursorLine')

call s:DefineHighlight('SmartGfSearchLine',         'Statement', '')
call s:DefineHighlight('SmartGfSearchLineSelected', 'Statement', 'CursorLine')

call s:DefineHighlight('SmartGfSearchLineHighlight',         'Search', '')
call s:DefineHighlight('SmartGfSearchLineHighlightSelected', 'Search', 'CursorLine')

call s:DefineHighlight('SmartGfDivider',         '', '')
call s:DefineHighlight('SmartGfDividerSelected', '', 'CursorLine')

call s:DefineHighlight('SmartGfFilePath',         'Comment', '')
call s:DefineHighlight('SmartGfFilePathSelected', 'Comment', 'CursorLine')

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

function! s:DrawResults(word, lines, leftmaxwidth, rightmaxwidth, current_position, start_at)
    let index = a:start_at
    let divider = repeat(' ', g:smartgf_divider_width)
    redraw!
    "show "Search result for blabla:"
    call s:Print('SmartGfTitle', 'Search results for ', 'SmartGfSearchWord', a:word, 'SmartGfTitle', ':')

    while index < len(a:lines) && index < a:start_at + g:smartgf_max_entries_per_page
        let line = []
        let entry = a:lines[index]
        let visible_index = index < 9 ? string(index + 1) : 'x'
        let selected_flag = index == a:current_position ? 'Selected' : ''

        call add(line, 'SmartGfIndex' . selected_flag)
        call add(line,  visible_index . '. ')

        let text = entry.text
        let length = strlen(text)
        if length > a:leftmaxwidth
            let text = strpart(text, 0, a:leftmaxwidth - 3) . '...'
        else
            let text .= repeat(' ', a:leftmaxwidth - strlen(text))
        endif

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


        let filestr = entry.file . ':' . entry.ln
        let length = strlen(filestr)
        if length > a:rightmaxwidth
            let filestr = '...' . strpart(filestr, length - a:rightmaxwidth + 3, a:rightmaxwidth - 3)
        else
            let filestr = repeat(' ', a:rightmaxwidth - length) . filestr
        endif
        call add(line, 'SmartGfDivider' . selected_flag)
        call add(line, divider)
        call add(line, 'SmartGfFilePath' . selected_flag)
        call add(line, filestr)

        call s:Print(line)
        let index += 1
    endwhile

    call s:Print('SmartGfPrompt', 'Press ', 'SmartGfIndex', '1-9', 'SmartGfPrompt', ' or use k,l and o,Enter to open file:')
endfunction

function! s:Open(position)
    let entry = s:lines[a:position]
    execute 'silent! edit ' . entry.file
    execute "normal! " . entry.ln . "G" . entry.col . "|zz"
endfunction

function! s:Find()
    let word = expand('<cword>')
    if strlen(word) < 2 | return | endif

    let type = &ft
    let types = ''

    let maxwidth = winwidth(0) - g:smartgf_divider_width - 4
    let cells = 10.0
    let leftcells = 7
    let leftmaxwidth = float2nr(maxwidth / cells * leftcells)

    if type == 'ruby' || type == 'haml'
        let type = 'ruby'
        let types = ' --ruby --haml'
    elseif type == 'js' || type == 'coffee'
        let type = 'js'
        let types = ' --js --coffee'
    endif

    echohl Title | echo 'Searching...' | echohl None

    let out = system(s:ack . shellescape(word) . types)
    let lines = []
    let maxlength = 0
    for line in split(out, '\n')
        let [_, file, ln, col, text; rest] = matchlist(line, '\(.\{-}\):\(.\{-}\):\(.\{-}\):\(.*\)')
        let text = substitute(text, '^\s*', '', 'g')
        let text = substitute(text, '\s*$', '', 'g')

        "skip comments
        if (type == 'ruby' && match(text, '^\s*-\?#') != -1)
            \ || (type == 'js' && match(text, '^\s*\(//\|#\)') != -1)
            continue
        endif


        let data = { 'file': file, 'ln': ln, 'col': col, 'text': text }
        if type == 'ruby' && match(text, 'def \+' . word . '[ (]') != -1
            call insert(lines, data)
        else
            call add(lines, data)
        end
        let length = strlen(text)
        if length > maxlength | let maxlength = length | endif
    endfor

    redraw!

    if len(lines) == 0
        echohl Title | echo 'Nothing was found' | echohl None
        return
    endif
    if maxlength > leftmaxwidth | let maxlength = leftmaxwidth | endif

    let rightmaxwidth = maxwidth - maxlength


    let s:lines = lines
    let show = 1
    let current_position = 0
    let results_count = len(lines)
    let start_at = 0
    while show 
        call s:DrawResults(word, lines, maxlength, rightmaxwidth, current_position, start_at)
        let key = getchar()
        let ch = nr2char(key)
        let choice = str2nr(ch)
        redraw!
        let show = 0
        if ch == 'j'
            let show = 1
            if current_position < results_count - 1
                let current_position += 1
                if current_position - start_at == g:smartgf_max_entries_per_page
                    let start_at += 1
                endif
            endif
        elseif ch == 'k'
            let show = 1
            if current_position > 0
                let current_position -= 1
                if current_position < start_at
                    let start_at -= 1
                endif
            endif
        elseif ch == 'o' || key == 13
            call s:Open(current_position)
        elseif choice > 0 && choice < 10
            call s:Open(choice - 1)
        endif
    endwhile
endfunction

nnoremap <silent> gf :<C-U>call <SID>Find()<CR>
