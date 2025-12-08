%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lang_f.tab.h"

int line = 1;
int column = 1;

void print_error(const char *msg);
int check_identifier_rules(const char *id);
%}

%option noyywrap

DIGIT           [0-9]
INT_CONST       {DIGIT}+
REAL_CONST      {DIGIT}*\.{DIGIT}+
LETTER_UPPER    [A-Z]
LETTER_LOWER    [a-z]
LETTER          [A-Za-z]
ALNUM           [A-Za-z0-9]
IDF_CORE        {LETTER_UPPER}({ALNUM}|_){0,19}
COMMENT         \/\/[^\n]*

%%

[ \t]+          { column += yyleng; }
\r              { /* ignore */ }
\n              { line++; column = 1; }

"BEGIN"         { column += yyleng; return BEGIN_PROG; }
"END"           { column += yyleng; return END_PROG; }
"INT"           { column += yyleng; return INT_TOK; }
"FLOAT"         { column += yyleng; return FLOAT_TOK; }
"BOOL"          { column += yyleng; return BOOL_TOK; }
"CONST"         { column += yyleng; return CONST_TOK; }
"For"           { column += yyleng; return FOR_TOK; }
"If"            { column += yyleng; return IF_TOK; }
"else"          { column += yyleng; return ELSE_TOK; }
"true"          { column += yyleng; return TRUE_TOK; }
"false"         { column += yyleng; return FALSE_TOK; }

{COMMENT}       { column += yyleng; }

{IDF_CORE}      {
    if (yyleng > 10) {
        fprintf(stderr, "Lexical error at line %d, column %d: Identifier '%s' exceeds 10 characters (has %d)\n", 
                line, column, yytext, yyleng);
        column += yyleng;
    } else if (check_identifier_rules(yytext) != 0) {
        column += yyleng;
    } else {
        column += yyleng;
        yylval.str = strdup(yytext);
        return IDF;
    }
}

[a-z][A-Za-z0-9_]* {
    fprintf(stderr, "Lexical error at line %d, column %d: Identifier '%s' must start with uppercase letter\n", 
            line, column, yytext);
    column += yyleng;
}

[A-Z][A-Za-z0-9_]*\'[A-Za-z0-9_]* {
    fprintf(stderr, "Lexical error at line %d, column %d: Identifier '%s' contains invalid apostrophe character\n", 
            line, column, yytext);
    column += yyleng;
}

{REAL_CONST}    { column += yyleng; yylval.real = atof(yytext); return REAL_CONST_TOK; }
{INT_CONST}     { column += yyleng; yylval.integer = atoi(yytext); return INT_CONST_TOK; }

":="            { column += 2; return ASSIGN; }
"="             { column++; return EQUALS; }
"=="            { column += 2; return EQ; }
"<="            { column += 2; return LE; }
">="            { column += 2; return GE; }
"<>"            { column += 2; return NE; }
"<"             { column++; return LT; }
">"             { column++; return GT; }

"+"             { column++; return ADD; }
"-"             { column++; return SUB; }
"*"             { column++; return MUL; }
"/"             { column++; return DIV; }
"++"            { column += 2; return INCREMENT; }
"--"            { column += 2; return DECREMENT; }

";"             { column++; return SEMI; }
","             { column++; return COMMA; }
"("             { column++; return LPAREN; }
")"             { column++; return RPAREN; }
"{"             { column++; return LBRACE; }
"}"             { column++; return RBRACE; }

.               { 
    print_error("Unrecognized token"); 
    column++;
}
%%

void print_error(const char *msg) {
    fprintf(stderr, "Lexical error at line %d, column %d: %s\n", line, column, msg);
}

int check_identifier_rules(const char *id) {
    int len = strlen(id);
    
    // Check for consecutive __
    for (int i = 0; i < len - 1; i++) {
        if (id[i] == '_' && id[i+1] == '_') {
            fprintf(stderr, "Lexical error at line %d, column %d: Identifier '%s' contains consecutive '__' symbols\n", 
                    line, column, id);
            return 1;
        }
    }
    
    // Check if ends with _
    if (len > 0 && id[len-1] == '_') {
        fprintf(stderr, "Lexical error at line %d, column %d: Identifier '%s' ends with '_' symbol\n", 
                line, column, id);
        return 1;
    }
    
    return 0;
}