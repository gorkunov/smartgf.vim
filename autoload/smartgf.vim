scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

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
        let filestr = entry.file
        if entry['ln'] != 'no'
            let filestr .= ':' . entry.ln
        endif
        let length = strlen(filestr)
        "cut file path if it's bigger than max allowed length
        if length > a:right_max_width

            "use different cutting strategy for gem paths and others
            "for gems cutted path looks like: GEMS/actionpack-1.0.2/lib...bla/bla.rb
            "for others: ...bla/bla.rb
            if has_key(entry, 'gem')
                let right_length = a:right_max_width / 2
                let left_length = a:right_max_width - right_length - 3
                let filestr = strpart(filestr, 0, left_length) . '...' . strpart(filestr, length - right_length, right_length)
            else
                let filestr = '...' . strpart(filestr, length - a:right_max_width + 3, a:right_max_width - 3)
            endif
        else
            let filestr = repeat(' ', a:right_max_width - length) . filestr
        endif

        call add(line, 'SmartGfFilePath' . selected_flag)
        call add(line, filestr)

        call s:Print(line)
        let index += 1
    endwhile

    "show footer legend "Press 1-9 or use j,k and o,Enter to open file"
    call s:Print(['SmartGfPrompt', 'Press ', 'SmartGfIndex', '1-9', 'SmartGfPrompt',
                \ ' or use ', 'SmartGfIndex', 'j', 'SmartGfPrompt', ',', 'SmartGfIndex', 'k', 'SmartGfPrompt',
                \ ' and ', 'SmartGfIndex', 'o', 'SmartGfPrompt', ',', 'SmartGfIndex', 'Enter', 'SmartGfPrompt', ' to open file'])
endfunction

"open file by path in the new buffer
"and set cursor position on the search word
"also centerized screen
function! s:Open(entry)
    if has_key(a:entry, 'real_path')
        let path = a:entry.real_path
    else
        let path = a:entry.file
    endif

    execute 'silent! edit ' . path
    if a:entry['ln'] == 'no'
        call search(escape(a:entry.text, '*'))
        let @/ = ""
    else
        execute "normal! " . a:entry.ln . "G" . a:entry.col . "|"
    endif
    normal! zz
endfunction

"Filter by filetype
function! s:InvalidFileType(file, type)
    let ext = matchstr(a:file, '\.\zs[^.]\+\ze$')
    return  (a:type == 'ruby' && index(['rb', 'rake', 'erb', 'haml', 'rabl', 'slim'], ext) == -1 && index(['Rakefile', 'Gemfile', 'Vagrantfile'], a:file) == -1)
                \ || (a:type == 'js' && index(['coffee', 'js'], ext) == -1)
                \ || (a:type == 'vim' && ext != 'vim')
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
    return     ((a:type == 'ruby' && match(a:text, 'def \+' . a:name . '\($\|[ (!\?]\)') != -1)
                \ || (a:type == 'ruby' && match(a:text, 'def \+self\.' . a:name . '\($\|[ (!\?]\)') != -1)
                \ || (a:type == 'ruby' && match(a:text, '\(module\|class\) \+' . a:name . '\($\| \+\)') != -1)
                \ || (a:type == 'js'   && match(a:text, "\\a \\+[\"\']" . a:name . "[\"\']") != -1)
                \ || (a:type == 'vim'  && match(a:text, 'function!\? \+\(.:\)\?' . a:name . '(') != -1))
endfunction

"main function: search word under the cursor with AG
function! s:Find(use_filter, ...)
    let filepath = expand('%:h') . '/'
    " Just in case someone somehow messed up their path and remove '.'
    " Means that in most cases, '.' will be run twice.
    for prefix in ['.'] + split(&path, ',')
        for extension in [''] + g:smartgf_extensions
            "first of all trying to open file under cursor (default gf)
            let filename = prefix . '/' . expand(expand('<cfile>')) . extension
            let filename = substitute(filename, '^\./', filepath, '')
            if filereadable(filename)
                execute 'edit ' . filename
                return
            endif
        endfor
    endfor

    " try to see if a search word was passed as param
    let searchWord = get(a:000, 0, '')

    if type(searchWord) == type('') && len(searchWord) > 1
        let word = searchWord
    else
        let word = expand('<cword>')
        " take word with ! or ? in the end
        let full_word = substitute(expand('<cWORD>'), '^.*\.', '', '')
        if len(full_word) - len(word) == 1 && (full_word[-1:] == '!' || full_word[-1:] == '?')
            let word = full_word
        endif
    endif

    "skip if this is one symbol
    if strlen(word) < 2 | return | endif

    "get window width and calc max allowed width for results window
    let max_width = &columns - g:smartgf_divider_width - 4
    "left/right sections proportion
    let cells = 10.0
    let left_cells = 7
    let left_max_width = float2nr(max_width / cells * left_cells)

    "detect filetype
    "use filetype to filter search results
    let type = &ft
    if a:use_filter
        if type == 'ruby' || type == 'haml' || type == 'slim'
            let type = 'ruby'
        elseif type == 'js' || type == 'coffee'
            let type = 'js'
        endif
    endif

    "show search in progress
    call s:Print('SmartGfTitle', 'Searching...')

    "escape some symbols like $
    let escaped_word = substitute(word, '\(\$\)', '\\\1', 'g')
    let out = system(g:smartgf_grep_prog . ' --ackmate ' . shellescape(escaped_word))

    let left_real_max_width = 0
    let definitions = []
    let gem_definitions = []
    let common = []
    let file = ''
    for line in split(out, '\n')
        if strlen(line) == 0
            continue
        elseif line[0] == ':'
            "detect file path and skip ./ at the beginning of the path
            let file = line[1:]
            "skip non-matched filetypes
            if a:use_filter && s:InvalidFileType(file, type)
                let file = ''
            endif
            continue
        elseif file != ''
            let [_, ln, col, text; rest] = matchlist(line, '\(.\{-}\);\(.\{-}\) .\{-}:\s*\(.*\)\s*')
            "skip comments
            if a:use_filter && s:IsComment(text, type)
                continue
            endif
        else
            continue
        endif

        let data = { 'file': file, 'ln': ln, 'col': col, 'text': text }

        "set top priority for method/function definition
        if a:use_filter && s:HasPriority(text, word, type)
            call add(definitions, data)
        else
            call add(common, data)
        end

        "calc real max width of text parts of lines
        let length = strlen(text)
        if length > left_real_max_width | let left_real_max_width = length | endif
    endfor

    "also search in the GEMS (with ctags)
    if g:smartgf_enable_gems_search && type == 'ruby' && filereadable(g:smartgf_tags_file)
        "search by first column in the ctags file
        let out = system(g:smartgf_grep_prog . ' --ackmate "(^' . word . '\t)" ' . ' ./'. g:smartgf_tags_file)
        for line in split(out, '\n')
            "ctags file has format:
            "<search target>  <path>  <search pattern>"<rest>
            "so get this line from text property in the ag output
            let text = matchstr(line, '.\{-}:\zs.*')
            let [_, real_path; rest] = split(text, '\t')
            "convert <search pattern> to real text which will be displayed
            let text = matchstr(join(rest, ''), '\/\^\s*\zs.*\ze\s*\$\/')
            "make path more readable (replace absolute url to GEMS/ prefix)
            let path = 'GEMS/' . matchstr(real_path, '.*/gems/\zs.*')
            "we have no line/col for this entry, so we will use search pattern
            "to navigate the result
            let data = { 'file': path, 'real_path': real_path, 'ln': 'no', 'col': 'no', 'text': text, 'gem': 1 }
            call add(gem_definitions, data)
            let length = strlen(text)
            if length > left_real_max_width | let left_real_max_width = length | endif
        endfor
    endif

    let lines = definitions + gem_definitions + common

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
        "change position to next item
        if ch == 'j' || key == "\<Down>"
            let show = 1
            if current_position < results_count - 1
                let current_position += 1
                if current_position - start_at == g:smartgf_max_entries_per_page
                    let start_at += 1
                endif
            endif
            "change position to previous item
        elseif ch == 'k' || key == "\<Up>"
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

"Update tags when it needed
"use bundle to get gems paths and ctags to generate tags
function! smartgf#ValidateTagsFile()
    "work only with Gemfile stuff
    let gemfile = 'Gemfile.lock'
    if !filereadable(gemfile) | return | endif

    call s:Print('SmartGfTitle', 'Checking tags...')

    "check Gemfile.lock modified_at
    let gemfile_updated_at = system('stat -f "%m" ' . gemfile)
    let last_updated_at = ''

    "read previous last saved modified_at from our file
    if exists('g:smartgf_tags_last_updated_at')
        let last_updated_at = g:smartgf_tags_last_updated_at
    elseif filereadable(g:smartgf_date_file)
        let [last_updated_at; rest] = readfile(g:smartgf_date_file)
        let g:smartgf_tags_last_updated_at = last_updated_at
    endif

    "run tags generation if last date is not the same
    if gemfile_updated_at != last_updated_at
        "validate bundle status
        call system('bundle check')
        if v:shell_error == 1
            call s:Print('SmartGfTitle', "Smartgf can't generate tags. Some gems are missing. Install missing gems with `bundle install`.")
            return
        endif
        "validate ctags
        if match(system('ctags --version'), 'Exuberant') == -1
            call s:Print('SmartGfTitle', "Smartgf can't generate tags. Ctags is not valid. Please install Exuberant Ctags.")
            return
        endif
        call s:Print('SmartGfTitle', 'Updating tags...')
        "get path via bundle and load them to ctags
        call system('bundle show --paths | xargs ctags -R --languages=ruby -o ' . g:smartgf_tags_file)
        call writefile([ gemfile_updated_at ], g:smartgf_date_file)
        let g:smartgf_tags_last_updated_at = gemfile_updated_at
    endif
    call s:Print('SmartGfTitle', ' ')
    redraw!
endfunction

" shamelessly copied from:
" https://github.com/tyru/open-browser.vim
" Get the last selected text in visual mode.
function! s:get_last_selected()
    let save = getreg('"', 1)
    let save_type = getregtype('"')
    let [begin, end] = [getpos("'<"), getpos("'>")]
    try
        if visualmode() ==# "\<C-v>"
            let begincol = begin[2] + (begin[2] ># getline('.') ? begin[3] : 0)
            let endcol   =   end[2] + (  end[2] ># getline('.') ?       end[3] : 0)
            if begincol ># endcol
                " end's col must be greater than begin.
                let tmp = begin[2:3]
                let begin[2:3] = end[2:3]
                let end[2:3] = tmp
            endif
            let virtpadchar = ' '
            let lines = map(getline(begin[1], end[1]), '
                        \ (v:val[begincol-1 : endcol-1])
                        \ . repeat(virtpadchar, endcol-len(v:val))
                        \')
        else
            if begin[1] ==# end[1]
                let lines = [getline(begin[1])[begin[2]-1 : end[2]-1]]
            else
                let lines = [getline(begin[1])[begin[2]-1 :]]
                            \                   + (end[1] - begin[1] <# 2 ? [] : getline(begin[1]+1, end[1]-1))
                            \                   + [getline(end[1])[: end[2]-1]]
            endif
        endif
        return join(lines, "\n") . (visualmode() ==# "V" ? "\n" : "")
    finally
        call setreg('"', save, save_type)
    endtry
endfunction

function! s:get_selected_text()
    let selected_text = s:get_last_selected()
    let text = substitute(selected_text, '[\n\r]\+', ' ', 'g')
    return substitute(text, '^\s*\|\s*$', '', 'g')
endfunction

function! smartgf#_keymapping_search(mode, use_filter)
    echo a:mode
    if a:mode ==# 'n'
        return s:Find(a:use_filter)
    else
        return s:Find(a:use_filter, s:get_selected_text())
    endif
endfunction

let &cpo = s:save_cpo
