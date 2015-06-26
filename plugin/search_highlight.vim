" search-highlight.vim: add better highlighting when searching, as well as some
" other search-related enhancements.
"
" http://code.arp242.net/vim-search-highlight
"
" Copyright © 2015 Martin Tournoij <martin@arp242.net>
" See below for full copyright.
"


"##########################################################
" Initialize some stuff
scriptencoding utf-8
"if exists('g:loaded_search_highlight') | finish | endif
let g:loaded_search_highlight = 1
let s:save_cpo = &cpo
set cpo&vim


"##########################################################
" The default settings
if !exists('g:search_highlight')
	let g:search_highlight = 'CurrentSearch'
endif
if !exists('g:search_highlight_blink')
	let g:search_highlight_blink = 0
endif
if !exists('g:search_highlight_consistent_n')
	let g:search_highlight_consistent_n = 1
endif
if !exists('g:search_highlight_dont_move_star')
	let g:search_highlight_dont_move_star = 1
endif
if !exists('g:search_highlight_no_match_error')
	let g:search_highlight_no_match_error = 1
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
augroup search_highlight
	autocmd!
	autocmd ColorScheme * call s:set_highlight()
augroup end

if !&wildcharm | set wildcharm=<C-z> | endif


"##########################################################
" Mappings
" We need to override all these mappings because we want to call
" vim_search_highlight#highlight() after jumping the cursor.

" With thanks to romainl: http://vi.stackexchange.com/q/3180/51
fun! IsSearch()
	return index(['/', '?'], getcmdtype()) > -1
endfun

cnoremap <expr>   <Plug>(search-highlight-enter)      IsSearch() ? search_highlight#start_search(getcmdtype()) : "<CR>"
nnoremap <silent> <Plug>(search-highlight-next)       :call search_highlight#next()<CR>
nnoremap <silent> <Plug>(search-highlight-prev)       :call search_highlight#prev()<CR>
nnoremap <silent> <Plug>(search-highlight-star)       :call search_highlight#star()<CR>
nnoremap <silent> <Plug>(search-highlight-hash)       :call search_highlight#hash()<CR>
nnoremap <silent> <Plug>(search-highlight-clear)      :silent! call matchdelete(b:current_search)<CR>:nohlsearch<CR><C-L>
cnoremap <expr>   <Plug>(search-highlight-jump-next)  IsSearch() ? search_highlight#jump('/') : "<C-z>"
cnoremap <expr>   <Plug>(search-highlight-jump-prev)  IsSearch() ? search_highlight#jump('?') : "<S-Tab>"

" TODO: maybe use:
" if !hasmapto('<Plug>TypecorrAdd')
"     map <unique> <Leader>a  <Plug>TypecorrAdd
" endif
cmap <CR>    <Plug>(search-highlight-enter)
nmap n       <Plug>(search-highlight-next)
nmap N       <Plug>(search-highlight-prev)
nmap #       <Plug>(search-highlight-hash)
nmap *       <Plug>(search-highlight-star)
cmap <Tab>   <Plug>(search-highlight-jump-next)
cmap <S-Tab> <Plug>(search-highlight-jump-prev)
nmap <C-L>   <Plug>(search-highlight-clear)


"##########################################################
" The actual code/functions

" Highlight the "current" search match with a different colour, and/or blink it
" when moving to it.
" It is inspired by the "More Instantly Better Vim" talk by Damian Conway, which
" you can view here: https://www.youtube.com/watch?v=aHm36-na4-4
" TODO: We want to be able to pass variables to override the global defaults
fun! search_highlight#highlight()
	" Always clear the method=highlight match
	silent! call matchdelete(b:current_search)

	" \c makes the pattern ignore case
	" \%# matches the cursor position
	let l:pattern = '\c\%#' . @/

	" Blink; highlight each entry in the list, sleep, and remove the highlight
	" again
	if g:search_highlight_blink != 0
		for [group, time] in g:search_highlight_blink
			let l:ring = matchadd(l:group, l:pattern, 666)
			redraw
			execute 'sleep ' . l:time . 'm'
			call matchdelete(l:ring)
			redraw
		endfor
	endif

	" Highlight; add a new highlight group
	if g:search_highlight == 0
		let b:current_search = matchadd(g:search_highlight, l:pattern, 666)
	endif

	" Make sure that we highlight after :nohlsearch
	if &hlsearch | set hlsearch | endif
	redraw
endfun


" TODO: Get this working...
fun! search_highlight#start_search(char)
	let l:dir = (a:char ==# '/' ? 'next' : 'prev')
	let l:pattern = getcmdline()

	if !search(l:pattern, 'nW' . (l:dir ==# 'prev' ? 'b' : ''))
		"let l:msg = ':E38' . (l:dir ==# 'prev' ? '4' : '5') . ': Search hit '
		"let l:msg .= (l:dir ==# 'next' ? 'BOTTOM' : 'TOP') . ' without match for: ' . l:pattern
		return "\<CR>:call search_highlight#better_error(0, 0)\<CR>"
	endif

	return "\<CR>:call search_highlight#highlight()\<CR>"
endfun


" Go to the net (or previous) match, and apply the highlighting and the
" 'consistent_n' options.
" The trick for 'consistent_n' was taken from Christian Brabandt:
" http://vi.stackexchange.com/a/2366/51
fun! search_highlight#next(...)
	let l:consistent_n = (a:0 >= 1) ? a:1 : g:search_highlight_consistent_n
	let l:_dir = (a:0 >= 2) ? a:2 : 'next'

	" Don't have to modify behaviour of n/N
	if !l:consistent_n
		execute 'normal! ' . (l:_dir ==# 'next' ? 'n' : 'N')
		silent call search_highlight#highlight()
		return
	endif

	" Always make n search forward, and N search backwards
	try
		execute 'normal! ' . (l:_dir ==# 'next' ? 'Nn' : 'nN')[v:searchforward]
	" If wrapscan is off (otherwise this would show as an error in the function)
	catch /E38\(4\|5\):/
		call search_highlight#better_error(v:exception, @/)
	endtry

	call search_highlight#highlight()
endfun

fun! search_highlight#prev(...)
	let l:consistent_n = (a:0 >= 1) ? a:1 : g:search_highlight_consistent_n
	call search_highlight#next(l:consistent_n, 'prev')
endfun


" Modify the * and # so it won't move the cursor
fun! search_highlight#star(...)
	let l:dont_move = (a:0 >= 1) ? a:1 : g:search_highlight_dont_move_star
	let l:_dir = (a:0 >= 2) ? a:2 : 'next'

	let @/ = '\<' . expand('<cword>') .  '\>'

	" Move cursor to the start of the match
	let l:save_cursor = getpos('.')
	call search(@/, 'bc')
	call search_highlight#highlight()
	call setpos('.', l:save_cursor)

	if !l:dont_move
		execute 'normal ' (l:_dir ==# 'next' ? 'n' : 'N')
	endif
endfun

fun! search_highlight#hash()
	let l:dont_move = (a:0 >= 1) ? a:1 : g:search_highlight_dont_move_star
	call search_highlight#star(l:dont_move, 'prev')
endfun


" Jump to next/previous match *while* searching. This mapping only makes sense
" if 'incearch' is enabled
"
" This is based on a code snippet from romainl: http://vi.stackexchange.com/a/3629/51
fun! search_highlight#jump(char)
	" TODO: This is flawed, since we can shift-tab
	let l:dir = (a:char ==# '/' ? 'next' : 'prev')
	
	" TODO: Perhaps we should just enable this setting (and re-set it afterwards)?
	if !&incsearch
		echoerr "search_highlight#jump() only works if the 'incsearch' setting is enabled".
	endif

	let l:pattern = getcmdline()
	if !search(l:pattern, 'nW' . (l:dir ==# 'prev' ? 'b' : ''))
		let l:msg = ':E38' . (l:dir ==# 'prev' ? '4' : '5') . ': Search hit '
		let l:msg .= (l:dir ==# 'next' ? 'BOTTOM' : 'TOP') . ' without match for: ' . l:pattern
		call search_highlight#better_error(l:msg, l:pattern)

		if !&wrapscan
			" TODO: I don't like this delay, but without it's not clear you can
			" still type if you leave it there...
			redraw
			sleep 1000m
			echo a:char . l:pattern
			redraw
		endif
		return ''
	else
		return "\<CR>" . a:char . "\<C-r>/"
	endif
endfun


" Show 'E486: Pattern not found' when wrapscan is off and the match isn't found
" in the document.
" TODO: Works for n/N, but not for "/asd<CR>"
fun! search_highlight#better_error(errstr, pattern)
	let l:errstr = a:errstr[stridx(a:errstr, ':')+1:]
	let l:dir = l:errstr =~# '^E385' ? 'next' : 'prev'

	" No match at all in the file
	if !search(a:pattern, 'cnW' . (l:dir == 'next' ? '' : 'b'), 0, 3000)
		let l:errstr = 'E486: Pattern not found: ' . a:pattern
	endif

	echohl ErrorMsg | echo l:errstr | echohl None
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
