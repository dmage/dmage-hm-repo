" vim: et ts=2 sts=2 sw=2 spelllang= :
syntax on
set ruler
set ts=4 sts=4 sw=4 et
set termencoding=utf8
set encoding=utf8
"set spell spelllang=en,ru
set modeline
set modelines=65000
let c_warn_trigraph = 1
nmap <silent> <A-Up> :wincmd k<CR>
nmap <silent> <A-Down> :wincmd j<CR>
nmap <silent> <A-Left> :wincmd h<CR>
nmap <silent> <A-Right> :wincmd l<CR>
map <C-S-F12> :!ctags -R --c++-kinds=+p --fields=+iaS --extra=+q .<CR>

set viminfo='100,<50,s10,h

" persistent undo
try
  set undodir=~/.vim/undo
  set undofile
catch
endtry
