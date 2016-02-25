" powersearch.vim: several search-relating enhancements.
"
" http://code.arp242.net/powersearch.vim
"
" See the bottom of this file for copyright & license information.


"##########################################################
" Initialize some stuff
scriptencoding utf-8
if exists('g:loaded_powersearch') | finish | endif
let g:loaded_powersearch = 1
let s:save_cpo = &cpo
set cpo&vim


"##########################################################
" The default settings
if !exists('g:powersearch_highlight')
	let g:powersearch_highlight = 'CurrentSearch'
endif
if !exists('g:powersearch_blink')
	let g:powersearch_blink = 0
endif
if !exists('g:powersearch_consistent_n')
	let g:powersearch_consistent_n = 1
endif
if !exists('g:powersearch_dont_move_star')
	let g:powersearch_dont_move_star = 1
endif
if !exists('g:powersearch_no_match_error')
	let g:powersearch_no_match_error = 1
endif
if !exists('g:powersearch_show_match')
	let g:powersearch_show_match = 1
endif
if !exists('g:powersearch_inc_s')
	let g:powersearch_inc_s = 1
endif

" This is a hack to set the CurrentSearch highlight group, but only if undefined
" or cleared.
" TODO: Is there a better way to do this?
fun! s:set_highlight() abort
	highlight CurrentSearch term=reverse ctermbg=6 guibg=Cyan
endfun
augroup powersearch
	autocmd!
	autocmd ColorScheme * call s:set_highlight()
augroup end
call s:set_highlight()


"##########################################################
" Mappings
" We need to override all these mappings because we want to call
" vim_powersearch#highlight() after jumping the cursor.

if !&wildcharm | set wildcharm=<C-z> | endif

" With thanks to romainl: http://vi.stackexchange.com/q/3180/51
fun! <SID>IsSearch() abort
	return index(['/', '?'], getcmdtype()) > -1
endfun

fun! <SID>IsSub() abort
	return getcmdtype() == ':'
	":cmap <F7> <C-\>eescape(getcmdline(), ' \')<CR>
endfun

cnoremap <silent> <expr>   <Plug>(search-highlight-enter)      <SID>IsSearch() ? powersearch#start_search(getcmdtype()) : "<CR>"
cnoremap <silent> <expr>   <Plug>(search-highlight-preview)    <SID>IsSub() ? powersearch#preview_sub() : ""
nnoremap <silent> <Plug>(search-highlight-next)       :call powersearch#next()<CR>
nnoremap <silent> <Plug>(search-highlight-prev)       :call powersearch#prev()<CR>
nnoremap <silent> <Plug>(search-highlight-star)       :call powersearch#star()<CR>
nnoremap <silent> <Plug>(search-highlight-hash)       :call powersearch#hash()<CR>
nnoremap <silent> <Plug>(search-highlight-clear)      :silent! call matchdelete(b:current_search)<CR>:nohlsearch<CR><C-L>
cnoremap <silent> <expr>   <Plug>(search-highlight-jump-next)  <SID>IsSearch() ? powersearch#jump('/') : "<C-z>"
cnoremap <silent> <expr>   <Plug>(search-highlight-jump-prev)  <SID>IsSearch() ? powersearch#jump('?') : "<S-Tab>"

if !exists('g:powersearch_no_map') || empty(g:powersearch_no_map)
	cmap <CR>    <Plug>(search-highlight-enter)
	cmap <C-P>   <Plug>(search-hightlight-preview)
	nmap n       <Plug>(search-highlight-next)
	nmap N       <Plug>(search-highlight-prev)
	nmap #       <Plug>(search-highlight-hash)
	nmap *       <Plug>(search-highlight-star)
	cmap <Tab>   <Plug>(search-highlight-jump-next)
	cmap <S-Tab> <Plug>(search-highlight-jump-prev)
	nmap <C-L>   <Plug>(search-highlight-clear)
endif


fun! powersearch#preview_sub() abort
endfun


"##########################################################
" Functions

" Highlight the "current" search match with a different colour, and/or blink it
" when moving to it.
" It is inspired by the "More Instantly Better Vim" talk by Damian Conway, which
" you can view here: https://www.youtube.com/watch?v=aHm36-na4-4
" TODO: We want to be able to pass variables to override the global defaults
fun! powersearch#highlight() abort
	silent! call matchdelete(b:current_search)

	" \c - ignore case
	" \%#  - matches the cursor position
	let l:pattern = '\c\%#' . @/

	" Blink; highlight each entry in the list, sleep, and remove the highlight
	" again
	if !empty(g:powersearch_blink)
		for [group, time] in g:powersearch_blink
			let l:ring = matchadd(l:group, l:pattern, 666)
			redraw
			execute 'sleep ' . l:time . 'm'
			call matchdelete(l:ring)
			redraw
		endfor
	endif

	" Highlight
	if !empty(g:powersearch_highlight)
		let b:current_search = matchadd(g:powersearch_highlight, l:pattern, 666)
	endif

	" Make sure that we highlight after :nohlsearch
	if &hlsearch | set hlsearch | endif
	redraw
endfun


fun! powersearch#start_search(char) abort
	"let l:dir = (a:char ==# '/' ? 'next' : 'prev')
	"let l:pattern = getcmdline()

	" TODO: Get this working... We want to show a better error, but how to intercept the previous one?
	"if !search(l:pattern, 'nW' . (l:dir ==# 'prev' ? 'b' : ''))
		"let l:msg = ':E38' . (l:dir ==# 'prev' ? '4' : '5') . ': Search hit '
		"let l:msg .= (l:dir ==# 'next' ? 'BOTTOM' : 'TOP') . ' without match for: ' . l:pattern
		"return "\<CR>:call powersearch#better_error(0, 0)\<CR>"
	"endif

	return "\<CR>:silent call powersearch#highlight()\<CR>:call powersearch#nmatch()\<CR>"
endfun


" Go to the next (or previous) match, and apply the highlighting and the
" {consistent_n} options.
" The trick for {consistent_n} was taken from Christian Brabandt:
" http://vi.stackexchange.com/a/2366/51
fun! powersearch#next(...) abort
	let l:consistent_n = (a:0 >= 1) ? a:1 : g:powersearch_consistent_n
	let l:_dir = (a:0 >= 2) ? a:2 : 'next'

	" Don't have to modify behaviour of n/N
	if !l:consistent_n
		execute 'normal! ' . (l:_dir ==# 'next' ? 'n' : 'N')
		silent call powersearch#highlight()
		call powersearch#nmatch()
		return
	endif

	" Always make n search forward, and N search backwards
	try
		execute 'normal! ' . (l:_dir ==# 'next' ? 'Nn' : 'nN')[v:searchforward]
	" If wrapscan is off (otherwise this would show as an error in the function)
	catch /E38\(4\|5\):/
		call powersearch#better_error(v:exception, @/)
		return
	endtry

	silent call powersearch#highlight()
	call powersearch#nmatch()
endfun
fun! powersearch#prev(...) abort
	let l:consistent_n = (a:0 >= 1) ? a:1 : g:powersearch_consistent_n
	call powersearch#next(l:consistent_n, 'prev')
endfun


" Show match n of n
" https://github.com/henrik/vim-indexed-search
fun! powersearch#nmatch() abort
	if !g:powersearch_show_match | return | endif

	let l:max = 200

	let winview = winsaveview()
	let line = winview["lnum"]
	let col = winview["col"] + 1
	let [total, exact, after] = [0, -1, 0]

	call cursor(1, 1)
	let [matchline, matchcol] = searchpos(@/, 'Wc')
	while matchline && (total <= l:max)
		let total += 1
		if (matchline == line && matchcol == col)
			let exact = total
		elseif matchline < line || (matchline == line && matchcol < col)
			let after = total
		endif
		let [matchline, matchcol] = searchpos(@/, 'W')
	endwhile

	call winrestview(winview)

	echom "match " . exact . " of " . total
	redraw
    "return [total, exact, after]
endfun


" Modify the * and # so it won't move the cursor (unless a count is given)
fun! powersearch#star(...) abort
	let l:dont_move = (a:0 >= 1) ? a:1 : g:powersearch_dont_move_star
	let l:_dir = (a:0 >= 2) ? a:2 : 'next'

	let @/ = '\<' . expand('<cword>') .  '\>'

	" Move cursor to the start of the match
	let l:save_cursor = getpos('.')
	call search(@/, 'bc')

	silent call powersearch#highlight()
	call powersearch#nmatch()
	if v:count == 0
		call setpos('.', l:save_cursor)
	endif

	for i in range(0, v:count - (l:dont_move ? 1 : 0))
		execute 'normal ' (l:_dir ==# 'next' ? 'n' : 'N')
	endfor
endfun
fun! powersearch#hash() abort
	let l:dont_move = (a:0 >= 1) ? a:1 : g:powersearch_dont_move_star
	call powersearch#star(l:dont_move, 'prev')
endfun


" Jump to next/previous match *while* searching. This mapping only makes sense
" if 'incearch' is enabled
"
" This is based on a code snippet from romainl: http://vi.stackexchange.com/a/3629/51
fun! powersearch#jump(char) abort
	let l:dir = (a:char ==# '/' ? 'next' : 'prev')

	" TODO: Perhaps we should just enable this setting (and re-set it afterwards)?
	if !&incsearch
		echoerr "powersearch#jump() only works if the 'incsearch' setting is enabled".
	endif

	let l:pattern = getcmdline()
	if !search(l:pattern, 'nW' . (l:dir ==# 'prev' ? 'b' : ''))
		let l:msg = ':E38' . (l:dir ==# 'prev' ? '4' : '5') . ': Search hit '
		let l:msg .= (l:dir ==# 'next' ? 'BOTTOM' : 'TOP') . ' without match for: ' . l:pattern
		call powersearch#better_error(l:msg, l:pattern)
		call powersearch#highlight()
		"call powersearch#nmatch() TODO

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
fun! powersearch#better_error(errstr, pattern) abort
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
" Copyright © 2015-2016 Martin Tournoij
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
