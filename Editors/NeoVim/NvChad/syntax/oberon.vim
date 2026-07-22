" Active Oberon (A2 / Fox) syntax — keywords from the Fox scanner (2026 snapshot).
" END is colored to match the construct it closes (via matchgroup regions).
" Regex-structural => approximate; a tree-sitter grammar would be exact.
" Drop-in for minia2 SDK users; independent of NVChad.
if exists("b:current_syntax") | finish | endif

" ---- leaf tokens ----
syn keyword oberonStatement    MODULE IMPORT DEFINITION CONST TYPE VAR PROCEDURE OPERATOR
syn keyword oberonKeyword      RETURN AWAIT CODE IGNORE EXTERN IN IS OR ELSIF ELSE THEN
syn keyword oberonKeyword      UNTIL DIV MOD OUT IMAG NEW SELF RESULT ARRAY POINTER ALIAS ANY PORT
syn keyword oberonBoolean      TRUE FALSE
syn keyword oberonConstant     NIL
syn keyword oberonType         BOOLEAN CHAR INTEGER LONGINTEGER RANGE INTEGERSET REAL COMPLEX
syn keyword oberonType         SIGNED8 SIGNED16 SIGNED32 SIGNED64 UNSIGNED8 UNSIGNED16 UNSIGNED32 UNSIGNED64
syn keyword oberonType         FLOAT32 FLOAT64 COMPLEX32 COMPLEX64 SET SET8 SET16 SET32 SET64
syn keyword oberonType         ADDRESS SIZE SYSTEM
syn keyword oberonBuiltin      ABS ASH CAP CHR ENTIER FLOOR ENTIERH ORD ORD32 LEN LONG SHORT
syn keyword oberonBuiltin      MAX MIN ODD LSH ROT ROL ROR SHL SHR INCR SUM DIM CAS FIRST LAST STEP RE IM
syn keyword oberonBuiltin      ADDRESSOF SIZEOF ASSERT COPY DEC INC EXCL INCL DISPOSE HALT
syn keyword oberonBuiltin      GETPROCEDURE TRACE RESHAPE ALL INCMUL DECMUL WAIT CONNECT RECEIVE SEND DELEGATE

syn region  oberonComment      start="(\*" end="\*)" contains=oberonComment,@Spell
syn region  oberonString       start=+"+ end=+"+ oneline
syn region  oberonString       start=+'+ end=+'+ oneline
syn match   oberonFloat        "\<\d\+\.\d*\([EeDd][-+]\=\d\+\)\=\>"
syn match   oberonNumber       "\<\d[0-9A-Fa-f]*[XH]\>"
syn match   oberonNumber       "\<0[xX][0-9A-Fa-f]\+\>"
syn match   oberonNumber       "\<0[bB][01]\+\>"
syn match   oberonNumber       "\<\d\+\>"
syn match   oberonModifier     "{[^}]*}"

" everything that may appear inside a block (leaves + nested blocks)
syn cluster oberonItems contains=oberonStatement,oberonKeyword,oberonBoolean,oberonConstant,oberonType,oberonBuiltin,oberonComment,oberonString,oberonFloat,oberonNumber,oberonModifier,@oberonBlocks

" ---- block regions: the closing END takes the opener's color (matchgroup) ----
syn region oberonBlkIf   matchgroup=oberonDelimIf   start="\<IF\>"    end="\<END\>" transparent contains=@oberonItems
syn region oberonBlkCase matchgroup=oberonDelimCase start="\<CASE\>"  end="\<END\>" transparent contains=@oberonItems
syn region oberonBlkLoop matchgroup=oberonDelimLoop start="\<WHILE\>" start="\<FOR\>" start="\<LOOP\>" end="\<END\>" transparent contains=@oberonItems
syn region oberonBlkWith matchgroup=oberonDelimWith start="\<WITH\>"  end="\<END\>" transparent contains=@oberonItems
syn region oberonBlkType matchgroup=oberonDelimType start="\<RECORD\>" start="\<OBJECT\>" start="\<ENUM\>" start="\<CELL\>" start="\<CELLNET\>" end="\<END\>" transparent contains=@oberonItems

syn cluster oberonBlocks contains=oberonBlkIf,oberonBlkCase,oberonBlkLoop,oberonBlkWith,oberonBlkType

" Body/module/procedure END (not one of the control/type blocks above): colored as
" a structure delimiter — same family as MODULE / PROCEDURE / BEGIN.
syn keyword oberonStructure BEGIN
syn match   oberonEnd "\<END\>"

hi def link oberonStatement    Statement
hi def link oberonKeyword      Keyword
hi def link oberonType         Type
hi def link oberonBuiltin      Function
hi def link oberonBoolean      Boolean
hi def link oberonConstant     Constant
hi def link oberonComment      Comment
hi def link oberonString       String
hi def link oberonNumber       Number
hi def link oberonFloat        Float
hi def link oberonModifier     PreProc
hi def link oberonStructure    Statement
hi def link oberonEnd          Statement

" END inherits the color of what it closes:
hi def link oberonDelimIf      Conditional
hi def link oberonDelimCase    Conditional
hi def link oberonDelimLoop    Repeat
hi def link oberonDelimWith    Keyword
hi def link oberonDelimType    Type
hi def link oberonDelimBody    Statement

let b:current_syntax = "oberon"
