About. Short Story
------------------
**Smartgf** is a tool for quick method definition lookup. It uses mix of ag (faster than ack which faster than grep), ctags and it was designed for Ruby developers.

![smartgf.vim](https://github.com/gorkunov/smartgf.vim/raw/master/_assets/smartgf.png)
 
Watch [this screencast](https://vimeo.com/56636037) for more details.

About. Long Story
------------------
Since I had been starting using Vim I was searching a best tool/way for quick method definion lookup.

This feature was always an advantage of big IDE systems like RubyMine(IDEA) or VisualStudio. 
Vim has some basic scenarios based on ctags or vimgrep 
which fail in most cases and look useless especially for me as ruby developer.

One day I started designing Smartgf. It combines tools for best results. 
It combines best tools such as the\_sivler\_searcher, ctags and inline-filters (by filetype, skip comment, set top definitions).

Since I have been starting using Smargf I love it.

Installation
------------
First of all you need to have installed [ag](https://github.com/ggreer/the_silver_searcher). So run this:

    # on mac with homebrew
    brew install the_silver_searcher

Or see details instruction [here](https://github.com/ggreer/the_silver_searcher).

If you Rails/Ruby developer you should install [ctags](http://ctags.sourceforge.net/)

    # on ubuntu
    sudo apt-get install ctags

    # on mac with homebrew
    brew install ctags

For quick plugin installing use [pathogen.vim](https://github.com/tpope/vim-pathogen).

If you already have pathogen then put smartgf into ~/.vim/bundle like this:

    cd ~/.vim/bundle
    git clone https://github.com/gorkunov/smartgf.vim.git

Usage
-----
Smartgf uses default 'gf' combination. Set cursor position under the function 
or method and type gf in normal mode. After that you will see dialog with search results. 
Use 1-9 keys as quick shortcuts to select search result or use j,k to change cursor 
position in the dialog and o,Enter to choose selected item.

*Note: By default smartgf uses filter by filetype and sets top priority for method definitions 
and also skips comments in the search results. If you want to skip these filters use 'gF' instead of 'gf'.*

*Note: If you use rails.vim you should know that smartgf disable rails.vim 'gf' mappings.
You can change smartgf mappings (see configuration section) after that rails.vim should works in a normal way.*

*Note: filetype/comments/priority filters are available only for vim, javascript/coffee and ruby files.*

*Note: If you use gems search and any CVS integration (git, svn) you need
to mark as ingored ```.smartgf_tags``` and ```.smartgf_tags_date``` (add to .gitingore for git).*

Configuration
-------------
If you want to change default smartgf settings add these lines to your vimrc file.

Available settings for smartgf:

```viml
"Key for running smartpaigf with all filters (ft/comments/def)
"default is 'gf'
let g:smartgf_key = 'gf'

"Key for running smartpaigf without filters
"default is 'gF'
let g:smartgf_no_filter_key = 'gF'

"Enable search with ruby gems from Gemfile
"default is 1
let g:smartgf_enable_gems_search = 1

"Max entries count to display (search results dialog)
"default is 9
let g:smartgf_max_entries_per_page = 9

"Min space between text and file path in the search results list
"default is 5
let g:smartgf_divider_width = 5

"Extensions to try for filenames which leave it off (will be tried in order)
" Default is as below
let g:smartgf_extensions = ['.ls', '.coffee', '.js']
```

License
-------
Smartgf is released under the [wtfpl](http://sam.zoy.org/wtfpl/COPYING)
