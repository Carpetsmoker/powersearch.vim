*powersearch.txt* Several search-related enhancements.

==============================================================================
INTRODUCTION                                                     *powersearch*

powersearch.vim adds several search-related enhancements, each of which can be
enabled individually:

- Highlight or blink the current match when using |n| or |N|.
- Show "Match 3 out of 7" when using |n|, |N|, |*|, or |#|.
- Jump to the next match without leaving incremental search.
- Don't jump immediately to the next match when using |*| or |#|.
- Always make |n| go to the next match (even if search was started with |?| or
  |#|).
- Better errors/feedback when 'wrapscan' is disabled.

==============================================================================
OPTIONS                                                  *powersearch-options*

*g:powersearch_highlight*                   (String, default: 'CurrentSearch')

    Highlight group to use for the current search match. Use an empty string
    or 0 to disable this feature.

*g:powersearch_blink*                                       (List, default: 0)

    Blink the current search match with this "pattern". The value is expected
    to be a list with 2 entries; the first one is a string with the name of
    the highlight group to apply, the second one is a number with the time to
    apply it for (in ms).

    A simple example which adds the ErrorMsg group for 100ms:
>
        let g:powersearch_blink = [['ErrorMsg', 100]]
<
    You can also use more advanced patterns. For example to make it blink
    twice you could use:
>
        let g:powersearch_blink = [['ErrorMsg', 75],
            \ ['Normal', 75], ['ErrorMsg', 75]]
<
    Use an empty string or 0 to disable this feature.

*g:powersearch_dont_move_star*                           (Boolean, default: 1)

    Don't move the cursor to the next match when using |*| or |#|, but
    stay on the current word. This is useful if you only want to highlight all
    the matches, rather than search for them.

*g:powersearch_consistent_n*                             (Boolean, default: 1)

    |n| will always search for the next match, and |N| will always search for
    the previous match; even if |?| or |#| is used.

*g:powersearch_no_match_error*                           (Boolean, default: 1)

    Show "|E486|: Pattern not found" when 'wrapscan' is off and the match
    isn't found in the document (rather than always showing |E384| and
    |E385|: "search hit BOTTOM without match").

*g:powersearch_no_map*                           (Boolean, default: undefined)

    Don't remap any keys. In case you want to setup your own mappings.

*g:powersearch_show_match*                            (Boolean, default: true)

    Show "Match 6 out of 42" when using |n|, |N|, |*|, or |#|.

==============================================================================
MAPPINGS                                                *powersearch-mappings*

By default powersearch.vim overwrites the following normal mode
mappings: |n|, |N|, |*|, |#|, |CTRL-L|; and the following cmdline
mappings: |<CR>|, |<Tab>|, |<S-Tab>|.
You can prevent this by setting |g:powersearch_no_map| to 1.


vim:tw=78:ts=8:ft=help:norl:expandtab
