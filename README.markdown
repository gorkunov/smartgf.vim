About
-----
**smartgf** is a 'goto file' on steroids!

It's better than default gf because:

* It doesn't use ctags. So you don't need to run anything after changes.
* It shows you all available matches.

It's better than ack.vim because:

* It sets top priority for function/method/class/module definition.
* It uses filter by filetype by default.
* It skips comments in the search.
* You don't need to switch or use quickfix window. It works in command-line mode.

![smartgf.vim](https://github.com/gorkunov/smartgf.vim/raw/master/_assets/smartgf.png)
 
Watch [this screencast](https://vimeo.com/56636037) for more details.

Installation
------------
First of all you need to have installed [ack](http://betterthangrep.com/). So run this:

    # on ubuntu
    sudo apt-get install ack-grep

    # on mac with homebrew
    brew install ack

Or see details instruction [here](https://github.com/mileszs/ack.vim).

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
and also skips comments in the search results. If you want to skip those filters use 'gF' instead of 'gf'.*

*Note: If you use rails.vim you should know that smartgf disable rails.vim 'gf' mappings.
You can change smartgf mappings (see configuration section) after that rails.vim should works in a normal way.*

*Note: filetype/comments/priority filters are available only for vim, javascript/coffee and ruby files.*

Configuration
-------------
If you want to change default smartgf settings add those lines to your vimrc file.

Available settings for smartgf:

```viml
"Key for running smartpaigf with all filters (ft/comments/def)
"default is 'gf'
let g:smartgf_key = 'gf'

"Key for running smartpaigf without filters
"default is 'gF'
let g:smartgf_no_filter_key = 'gF'

"Max entries count to display (search results dialog)
"default is 9
let g:smartgf_max_entries_per_page = 9

"Min space between text and file path in the search results list
"default is 5
let g:smartgf_divider_width = 5
```

License
-------
Smartgf is released under the [wtfpl](http://sam.zoy.org/wtfpl/COPYING)
