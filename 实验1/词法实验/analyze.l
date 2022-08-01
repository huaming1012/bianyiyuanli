%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int num_lines = 1;
int num_cols = 1;
%}

commentbegin "/*"
commentend "*/"
%x COMMENT

IDENTIFIER [_A-Za-z][_A-Za-z0-9]*
DECIMAL 0|[1-9][0-9]*
OCTALCONS 0[0-7]+
HEXCONS 0[xX][0-9a-fA-F]+
INTCONST {DECIMAL}|{OCTALCONS}|{HEXCONS}
OPERATOR ([\+\-\*\/\%\<\>\!\=\&\|]|"+="|"-="|"*="|"/="|">="|"<="|"=="|"++"|"--"|"&&"|"||")
BORDER [\(\)\{\}\[\]\,\;\'\"]
NOTE_S \/\/(.)*\n

%%
\n {++num_lines; num_cols = 1;}
[ \t\r]+ {num_cols += yyleng;}
"int" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"main" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"continue" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"const" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"if" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"else" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"return" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"void" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"while" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"enum" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"switch" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"case" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"for" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"sizeof" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"static" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"typedef" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"break" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"do" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"struct" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"signed" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"unsigned" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
"default" {printf("%s: K, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
{NOTE_S}*   {++num_lines;num_cols = 1;}
{commentbegin} {num_cols += yyleng; BEGIN COMMENT;}
<COMMENT>. {num_cols += yyleng;}
<COMMENT>\n {++num_lines; num_cols = 1;}
<COMMENT>{commentend} {num_cols += yyleng; BEGIN INITIAL;}
{IDENTIFIER} {printf("%s: I, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
{INTCONST}  {printf("%s: C, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
{OPERATOR} {printf("%s: O, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
{BORDER}    {printf("%s: D, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
[0-9][_A-Za-z0-9]*  {printf("%s: T, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
.  {printf("%s: T, (%d, %d)\n", yytext, num_lines, num_cols); num_cols += yyleng;}
%%
int yywrap(){
    return 1;
}
int main(){
    yylex();
    return 0;
}
