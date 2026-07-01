" ~/.config/nvim/init.vim — vi-faithful setup for a longtime vi user
" Goal: neutralize the Neovim defaults that break vi muscle memory.

set startofline        " G, gg, dd, <C-d>, :<line> land on first non-blank (vi behavior)
set nohlsearch         " no lingering search highlight
set noincsearch        " search only jumps on <CR>, not while typing
set noautoindent       " no auto-indent (avoids paste 'staircase')
set nosmarttab
set clipboard=         " keep vim registers ("a, etc.) separate from the system clipboard

" Mouse: OFF in the terminal (stays vi-pure), ON in the Neovide GUI.
if exists('g:neovide')
  set mouse=a
else
  set mouse=
endif

" Right-click context menu (Windows-gVim style): show the popup but DON'T move
" the caret to the click point. The default 'popup_setpos' repositions the
" cursor to the mouse pointer first, so 'Paste' lands under the pointer instead
" of at the text cursor -- the non-intuitive behavior. 'popup' keeps the caret
" where it is, so Paste inserts at the current file cursor.
set mousemodel=popup

" THE big one: Neovim maps Y -> y$ (charwise). Restore vi's Y = yy (linewise),
" so 'Yp' / 'Y' then 'p' duplicates a whole line onto the NEXT line.
silent! nunmap Y

" (marks + named registers like  mk ... "ay'k ... "ap  are standard and need no config)
