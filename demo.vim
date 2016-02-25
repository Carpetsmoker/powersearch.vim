fun! XX()
	let @/ = 'where'
	exe '/where'
	redraw | sleep 500m
	normal n
	redraw | sleep 500m
	normal n
	"sleep 200m
	"let g:search_highlight = 0
	    "let g:search_highlight_blink = [['ErrorMsg', 100]]
	    "let g:search_highlight_blink = [['ErrorMsg', 75], ['Normal', 75], ['ErrorMsg', 75]]
	"n
	"sleep 200m
	"N
endfun

fun! Demo()
python << EOF
import time, vim
EOF
endfun
