" vim-search: A collection of tweaks for searching.
"
" http://code.arp242.net/vim-search
"
" Copyright © 2015 Martin Tournoij <martin@arp242.net>
" See below for full copyright
"
" Other scripts with features that look interesting:
" http://www.vim.org/scripts/script.php?script_id=479
" http://www.vim.org/scripts/script.php?script_id=474


"##########################################################
" Initialize some stuff
scriptencoding utf-8
if exists('g:loaded_vim_search') | finish | endif
let g:loaded_vim_search = 1
let s:save_cpo = &cpo
set cpo&vim


"##########################################################
" The default settings
if !exists('g:vim_search_highlight')
	let g:vim_search_highlight = 1
endif
if !exists('g:vim_search_highlight_group')
	let g:vim_search_highlight_group = 'CurrentSearch'
endif

if !exists('g:vim_search_blink')
	let g:vim_search_blink = 0
endif
if !exists('g:vim_search_highlight_pattern')
	let g:vim_search_blink_pattern = [['ErrorMsg', 100]]
endif

if !exists('g:vim_search_consistent_n')
	let g:vim_search_consistent_n = 1
endif
if !exists('g:vim_search_dont_move_star')
	let g:vim_search_dont_move_star = 1
endif

" This is a hack to set the CurrentSearch highlight group, but only if undefined
" or cleared.
" TODO: Is there a better way to do this?
fun! s:set_highlight()
	let l:hack = ''
	try
		redir => l:hack
			silent highlight CurrentSearch
		redir END
	catch /E411:/
		highlight CurrentSearch term=reverse ctermbg=14 guibg=Cyan
	endtry

	if l:hack =~# 'cleared$'
		highlight CurrentSearch term=reverse ctermbg=14 guibg=Cyan
	endif
endfun
call s:set_highlight()
augroup vim_search
	autocmd!
	autocmd ColorScheme * call s:set_highlight()
augroup end

" We need this setting
if !&wildcharm
	set wildcharm=<C-z>
endif


"##########################################################
" Mappings
" We need to override all these mappings because we want to call
" VimSearchHighlight() after jumping the cursor.

" With thanks to romainl: http://vi.stackexchange.com/q/3180/51
fun! IsSearch()
	return index(['/', '?'], getcmdtype()) > -1
endfun

cnoremap <expr>   <Plug>(vim-search-enter)      IsSearch() ? "<CR>:call VimSearchHighlight()<CR>" : "<CR>"
nnoremap <silent> <Plug>(vim-search-next)       :call VimSearchNext()<CR>
nnoremap <silent> <Plug>(vim-search-prev)       :call VimSearchPrev()<CR>
nnoremap <silent> <Plug>(vim-search-star)       :call VimSearchStar()<CR>
nnoremap <silent> <Plug>(vim-search-hash)       :call VimSearchHash()<CR>
nnoremap <silent> <Plug>(vim-search-clear)      :silent! call matchdelete(b:current_search)<CR>:nohlsearch<CR><C-L>
cnoremap <expr>   <Plug>(vim-search-jump-next)  IsSearch() ? VimSearchJump('/') : "<C-z>"
cnoremap <expr>   <Plug>(vim-search-jump-prev)  IsSearch() ? VimSearchJump('?') : "<S-Tab>"

cmap <CR>    <Plug>(vim-search-enter)
nmap n       <Plug>(vim-search-next)
nmap N       <Plug>(vim-search-prev)
nmap #       <Plug>(vim-search-hash)
nmap *       <Plug>(vim-search-star)
cmap <Tab>   <Plug>(vim-search-jump-next)
cmap <S-Tab> <Plug>(vim-search-jump-prev)
nmap <C-L>   <Plug>(vim-search-clear)


"##########################################################
" The actual code/functions

" Highlight the "current" search match with a different colour, and/or blink it
" when moving to it.
" It is inspired by the "More Instantly Better Vim" talk by Damian Conway, which
" you can view here: https://www.youtube.com/watch?v=aHm36-na4-4
"
" TODO: We want to be able to pass variables to override the global defaults
fun! VimSearchHighlight()
	" Always clear the method=highlight match
	silent! call matchdelete(b:current_search)

	" \c makes the pattern ignore case
	" \%# matches the cursor position
	let l:pattern = '\c\%#' . @/

	" Blink; highlight each entry in the list, sleep, and remove the highlight
	" again
	if g:vim_search_blink
		for [group, time] in g:vim_search_blink_pattern
			let l:ring = matchadd(l:group, l:pattern, 666)
			redraw
			execute 'sleep ' . l:time . 'm'
			call matchdelete(l:ring)
			redraw
		endfor
	endif

	" Highlight; add a new highlight group
	if g:vim_search_highlight
		let b:current_search = matchadd(g:vim_search_highlight_group, l:pattern, 666)
	endif

	if &hlsearch | set hlsearch | endif
	redraw
endfun


" Go to the net (or previous) match, and apply the highlighting and the
" 'consistent_n' options.
" The trick for 'consistent_n' was taken from Christian Brabandt:
" http://vi.stackexchange.com/a/2366/51
fun! VimSearchNext(...)
	let l:consistent_n = (a:0 >= 1) ? a:1 : g:vim_search_consistent_n
	let l:_dir = (a:0 >= 2) ? a:2 : 'next'

	" Don't have to modify behaviour of n/N
	if !l:consistent_n
		execute 'normal! ' . (l:_dir ==# 'next' ? 'n' : 'N')
		silent call VimSearchHighlight()
		return
	endif

	" Always make n search forward, and N search backwards
	try
		execute 'normal! ' . (l:_dir ==# 'next' ? 'Nn' : 'nN')[v:searchforward]
	" If wrapscan is off (otherwise this would show as an error in the function)
	catch /E38\(4\|5\):/
		echohl ErrorMsg | echo s:fmt_exception(v:exception) | echohl None
	endtry

	call VimSearchHighlight()
endfun

fun! s:fmt_exception(str)
	return a:str[stridx(a:str, ':')+1:]
endfun

fun! VimSearchPrev(...)
	let l:consistent_n = (a:0 >= 1) ? a:1 : g:vim_search_consistent_n
	call VimSearchNext(l:consistent_n, 'prev')
endfun


" Modify the * and # so it won't move the cursor
fun! VimSearchStar(...)
	let l:dont_move = (a:0 >= 1) ? a:1 : g:vim_search_dont_move_star
	let l:_dir = (a:0 >= 2) ? a:2 : 'next'

	let @/ = '\<' . expand('<cword>') .  '\>'

	" Move cursor to the start of the match
	let l:save_cursor = getpos('.')
	call search(@/, 'bc')
	call VimSearchHighlight()
	call setpos('.', l:save_cursor)

	if !l:dont_move
		execute 'normal ' (l:_dir ==# 'next' ? 'n' : 'N')
	endif
endfun

fun! VimSearchHash()
	let l:dont_move = (a:0 >= 1) ? a:1 : g:vim_search_dont_move_star
	call VimSearchStar(l:dont_move, 'prev')
endfun


" Jump to next/previous match *while* searching. This mapping only makes sense
" if 'incearch' is enabled
"
" This is based on a code snippet from romainl: http://vi.stackexchange.com/a/3629/51
fun! VimSearchJump(char)
	" TODO: Perhaps we should just enable this setting?
	if !&incsearch
		echoerr "VimSearchJump() only works if the 'incsearch' setting is enabled".
	endif

	let l:pattern = getcmdline()
	if !search(l:pattern, 'n' . (a:char == '?' ? 'b' : ''))
		if !&wrapscan
			echohl ErrorMsg
			echo 'Search hit ' . (a:char ==# '/' ? 'BOTTOM' : 'TOP') . ' without match for: ' . l:pattern
			echohl None

			" TODO: I don't like this delay, but without it's not clear you can
			" still type if you leave it there...
			redraw
			sleep 1000m
			echo a:char . l:pattern
			redraw
		else
			echohl ErrorMsg | echo "E385: search hit BOTTOM without match for: " . l:pattern | echohl None
		endif
		return ''
	else
		return "\<CR>" . a:char . "\<C-r>/"
	endif
endfun


let &cpo = s:save_cpo
unlet s:save_cpo


" The MIT License (MIT)
"
" Copyright © 2015 Martin Tournoij
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to
" deal in the Software without restriction, including without limitation the
" rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
" sell copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" The software is provided "as is", without warranty of any kind, express or
" implied, including but not limited to the warranties of merchantability,
" fitness for a particular purpose and noninfringement. In no event shall the
" authors or copyright holders be liable for any claim, damages or other
" liability, whether in an action of contract, tort or otherwise, arising
" from, out of or in connection with the software or the use or other dealings
" in the software.
