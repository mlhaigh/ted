#!/bin/bash
MENHIR="menhir --interpret --interpret-show-cst ../parser.mly"
PROMPT="echo Press enter to continue"
NEXT="read answer"

function test() {
  for var in "$@"
  do          
    eval str="$var"
    printf "Test: \"$str\"\n"
    echo "$str" | $MENHIR
    $PROMPT && $NEXT
  done
}

STRING_FUN="STRING ID LPAREN STRING ID RPAREN LBRACE RETURN ID SEMI RBRACE"
LIST_FUN="LIST ID LPAREN LIST ID RPAREN LBRACE RETURN ID SEMI RBRACE"
PAGE_FUN="PAGE ID LPAREN PAGE ID RPAREN LBRACE RETURN ID SEMI RBRACE"
ELEM_FUN="ELEMENT ID LPAREN ELEMENT ID RPAREN LBRACE RETURN ID SEMI RBRACE"
MAIN_GENERIC="INT ID LPAREN RPAREN LBRACE ID LPAREN ID COMMA STRING_LIT RPAREN SEMI RETURN LITERAL SEMI RBRACE"


test "\${STRING_FUN}" "\$LIST_FUN" "\$PAGE_FUN" "\$ELEM_FUN" "\$MAIN_GENERIC"
                                                                                        
