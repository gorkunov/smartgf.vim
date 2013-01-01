let s:ack = executable('ack-grep') ? 'ack-grep' : 'ack'
let s:ack .= ' -H --nocolor --nogroup --column '
let g:smartgf_max_entries = 9
let g:rails_mappings = 0
let g:smartgf_divider_width = 5

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
        let types = ' --ruby --haml'
    elseif type == 'js' || type == 'coffee'
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
        call add(lines, { 'file': file, 'ln': ln, 'col': col, 'text': text })
        let length = strlen(text)
        if length > maxlength | let maxlength = length | endif
        if len(lines) == g:smartgf_max_entries | break | endif
    endfor

    if len(lines) == 0 | return | endif
    if maxlength > leftmaxwidth | let maxlength = leftmaxwidth | endif

    let rightmaxwidth = maxwidth - maxlength

    redraw
    echohl Title | echo 'Search results for ' | echohl Type | echon word | echohl Title | echon ':'
    let index = 0
    for entry in lines
        let index += 1
        let text = entry.text
        let length = strlen(text)
        if length > maxlength
            let text = strpart(text, 0, leftmaxwidth - 3) . '...'
        else
            let text .= repeat(' ', maxlength - strlen(text))
        endif
        echohl Identifier | echo index . '. ' 
        let startpos = 0
        while 1
            let endpos = stridx(text, word, startpos)
            if endpos == -1 
                echohl Statement | echon strpart(text, startpos)
                break
            endif
            echohl Statement | echon strpart(text, startpos, endpos - startpos)
            echohl Search | echon strpart(text, endpos, strlen(word))
            let startpos = endpos + strlen(word)
        endwhile


        let filestr = entry.file . ':' . entry.ln
        let length = strlen(filestr)
        if length > rightmaxwidth
            let filestr = '...' . strpart(filestr, length - rightmaxwidth + 3, rightmaxwidth - 3)
        else
            let filestr = repeat(' ', rightmaxwidth - length) . filestr
        endif
        echohl None    | echon repeat(' ', g:smartgf_divider_width)
        echohl Comment | echon filestr

    endfor
    echohl Underlined | echo 'Press ' | echohl Identifier | echon '1-' . index | echohl Underlined | echon ' to open file: ' | echohl None

    let choice = str2nr(nr2char(getchar()))
    if choice > 0 && choice <= index
        redraw
        let entry = lines[choice - 1]
        execute 'silent! edit ' . entry.file
        execute "normal! " . entry.ln . "G" . entry.col . "|zz"
    endif
endfunction

nnoremap <silent> gf :<C-U>call <SID>Find()<CR>
