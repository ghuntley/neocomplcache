"=============================================================================
" FILE: syntax_complete.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 17 Apr 2009
" Usage: Just source this file.
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
" Version: 1.14, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.14:
"    - Improved abbr.
"   1.13:
"    - Delete nextgroup.
"    - Improved filtering.
"   1.12:
"    - Optimized caching.
"    - Caching event changed.
"   1.11:
"    - Optimized.
"   1.10:
"    - Caching when set filetype.
"    - Analyze match.
"   1.03:
"    - Not complete 'Syntax items' message.
"   1.02:
"    - Fixed get syntax list.
"   1.01:
"    - Caching when initialize.
"   1.00:
"    - Initial version.
" }}}
"-----------------------------------------------------------------------------
" TODO: "{{{
"     - Nothing.
""}}}
" Bugs"{{{
"     - Nothing.
""}}}
"=============================================================================

function! neocomplcache#syntax_complete#initialize()"{{{
    " Initialize
    let s:syntax_list = {}

    augroup neocomplecache"{{{
        " Caching events
        autocmd CursorHold * call s:caching_event() 
    augroup END"}}}

endfunction"}}}

function! neocomplcache#syntax_complete#finalize()"{{{
endfunction"}}}

function! neocomplcache#syntax_complete#get_keyword_list(cur_keyword_str)"{{{
    if empty(&filetype) || !has_key(s:syntax_list, &filetype)
        return []
    endif

    return neocomplcache#keyword_filter(copy(s:syntax_list[&filetype]), a:cur_keyword_str)
endfunction"}}}

" Dummy function.
function! neocomplcache#syntax_complete#calc_rank(cache_keyword_buffer_list)"{{{
    return
endfunction"}}}
function! neocomplcache#syntax_complete#calc_prev_rank(cache_keyword_buffer_list, prev_word, prepre_word)"{{{
    return
endfunction"}}}

function! s:initialize_syntax()"{{{
    " Get current syntax list.
    redir => l:syntax_list
    silent! syntax list
    redir END

    if l:syntax_list =~ '^E\d\+' || l:syntax_list =~ '^No Syntax items'
        return []
    endif

    let l:group_name = ''
    let l:keyword_list = []
    let l:abbr_pattern = printf('%%.%ds..%%s', g:NeoComplCache_MaxKeywordWidth-10)
    if has_key(g:NeoComplCache_KeywordPatterns, &filetype)
        let l:keyword_pattern = g:NeoComplCache_KeywordPatterns[&filetype]
    else
        let l:keyword_pattern = g:NeoComplCache_KeywordPatterns['default']
    endif
    let l:dup_check = {}
    for l:line in split(l:syntax_list, '\n')
        if l:line =~ '^\h\w\+'
            " Change syntax group name.
            let l:group_name = printf('[S] %.'. g:NeoComplCache_MaxFilenameWidth.'s', matchstr(l:line, '^\h\w\+'))
            let l:line = substitute(l:line, '^\h\w\+\s*xxx', '', '')
        endif

        if l:line =~ 'Syntax items' || l:line =~ '^\s*links to' ||
                    \l:line =~ '^\s*nextgroup='
            " Next line.
            continue
        endif

        let l:line = substitute(l:line, 'contained\|skipwhite\|skipnl\|oneline', '', 'g')
        let l:line = substitute(l:line, '^\s*nextgroup=.*\ze\s', '', '')

        if l:line =~ '^\s*match'
            let l:line = s:substitute_candidate(matchstr(l:line, '/\zs[^/]\+\ze/'))
            "echomsg l:line
        elseif l:line =~ '^\s*start='
            let l:line = 
                        \s:substitute_candidate(matchstr(l:line, 'start=/\zs[^/]\+\ze/')) . ' ' .
                        \s:substitute_candidate(matchstr(l:line, 'end=/zs[^/]\+\ze/'))
        endif

        " Add keywords.
        let l:match_num = 0
        let l:line_max = len(l:line) - g:NeoComplCache_MinKeywordLength
        while 1
            let l:match_str = matchstr(l:line, l:keyword_pattern, l:match_num)
            if empty(l:match_str)
                break
            endif

            " Ignore too short keyword.
            if len(l:match_str) >= g:NeoComplCache_MinKeywordLength && !has_key(l:dup_check, l:match_str)
                let l:keyword = {
                            \ 'word' : l:match_str, 'menu' : l:group_name,
                            \ 'rank' : 1, 'prev_rank' : 0, 'prepre_rank' : 0
                            \}
                let l:keyword.abbr_save = 
                            \ (len(l:match_str) > g:NeoComplCache_MaxKeywordWidth)? 
                            \ printf(l:abbr_pattern, l:match_str, l:match_str[-8:]) : l:match_str
                call add(l:keyword_list, l:keyword)
            endif

            let l:match_num += len(l:match_str)
            if l:match_num > l:line_max
                break
            endif
        endwhile
    endfor

    return sort(l:keyword_list, 'neocomplcache#compare_words')
endfunction"}}}

function! s:substitute_candidate(candidate)"{{{
    let l:candidate = a:candidate

    " Collection.
    let l:candidate = substitute(l:candidate,
                \'\%(\\\\\|[^\\]\)\zs\[.*\]', ' ', 'g')
    if l:candidate =~ '\\v'
        " Delete.
        let l:candidate = substitute(l:candidate,
                    \'\%(\\\\\|[^\\]\)\zs\%([=?+*]\|%[\|\\s\*\)', '', 'g')
        " Space.
        let l:candidate = substitute(l:candidate,
                    \'\%(\\\\\|[^\\]\)\zs\%([<>{()|$^]\|\\z\?\a\)', ' ', 'g')
    else
        " Delete.
        let l:candidate = substitute(l:candidate,
                    \'\%(\\\\\|[^\\]\)\zs\%(\\[=?+]\|\\%[\|\\s\*\|\*\)', '', 'g')
        " Space.
        let l:candidate = substitute(l:candidate,
                    \'\%(\\\\\|[^\\]\)\zs\%(\\[<>{()|]\|[$^]\|\\z\?\a\)', ' ', 'g')
    endif

    " \
    let l:candidate = substitute(l:candidate, '\\\\', '\\', 'g')
    return l:candidate
endfunction"}}}

function! s:caching_event()"{{{
    " Caching.
    if !empty(&filetype) && !has_key(s:syntax_list, &filetype)
        let s:syntax_list[&filetype] = s:initialize_syntax()
    endif
endfunction"}}}

" vim: foldmethod=marker