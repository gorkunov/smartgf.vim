"smartgf.vim - Goto file on steroids
"
"Author: Alex Gorkunov <alex.gorkunov@cloudcastlegroup.com>
"Source repository: https://github.com/gorkunov/smartgf.vim
"
"vim: set tabstop=4 softtabstop=4 shiftwidth=4 expandtab

"avoid installing twice
if exists('g:loaded_smartgf')
    finish
endif

"check if debugging is turned off
if !exists('g:smartgf_debug')
    let g:loaded_smartgf = 1
end

let s:save_cpo = &cpo
set cpo&vim

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

if !exists('g:smartgf_create_default_mappings')
    let g:smartgf_create_default_mappings = 1
endif

"define divider width between text and file path in the results
if !exists('g:smartgf_extensions')
    let g:smartgf_extensions = ['.js', '.coffee', '.ls']
endif

"define divider width between text and file path in the results
if !exists('g:smartgf_divider_width')
    let g:smartgf_divider_width = 5
endif

"enable gems search by default
if !exists('g:smartgf_enable_gems_search')
    let g:smartgf_enable_gems_search = 1
endif

"enable auto-refreshing ctags on window focus
if !exists('g:smartgf_auto_refresh_ctags')
    let g:smartgf_auto_refresh_ctags = 1
endif

"define default tags and date file (for gems search)
if !exists('g:smartgf_tags_file')
    let g:smartgf_tags_file = '.smartgf_tags'
endif

if !exists('g:smartgf_date_file')
    let g:smartgf_date_file = g:smartgf_tags_file . '_date'
endif

if !exists('g:smartgf_grep_prog')
    let g:smartgf_grep_prog = 'ag'
endif

"detect the silver searcher
if !executable('ag')
    echo "Smartgf can't find `the_silver_searcher` engine, see details on https://github.com/ggreer/the_silver_searcher"
    finish
endif

let s:ag_version = system("ag --version | sed 's/ag version //'")
if s:ag_version < '0.14'
    echo "Smartgf can't work with old `the_silver_searcher` (version < 0.14). Please update it."
    finish
endif

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
"but with overridden colors from *mixparent*
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

if g:smartgf_enable_gems_search && g:smartgf_auto_refresh_ctags && has("gui_running")
    autocmd FocusGained * call smartgf#ValidateTagsFile()
endif

command! SmargfRefreshTags call smartgf#ValidateTagsFile()

if g:smartgf_create_default_mappings
    " legacy key mapping
    silent exec 'nnoremap <silent> ' . g:smartgf_key . ' :<C-U>call smartgf#_keymapping_search("n", 1)<CR>'
    silent exec 'nnoremap <silent> ' . g:smartgf_no_filter_key . ' :<C-U>call smartgf#_keymapping_search("n", 0)<CR>'
endif

nnoremap <silent> <Plug>(smartgf-search) :<C-u>call smartgf#_keymapping_search('n', 1)<CR>
vnoremap <silent> <Plug>(smartgf-search) :<C-u>call smartgf#_keymapping_search('v', 1)<CR>

nnoremap <silent> <Plug>(smartgf-search-unfiltered) :<C-u>call smartgf#_keymapping_search('n', 0)<CR>
vnoremap <silent> <Plug>(smartgf-search-unfiltered) :<C-u>call smartgf#_keymapping_search('v', 0)<CR>

let &cpo = s:save_cpo
