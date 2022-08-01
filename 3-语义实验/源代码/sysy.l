%{
#include <stdio.h>
#include "test.h"
#include <stdlib.h>
#include <string.h>
// typedef struct TreeNode{
//     int id;
//     int type;
//     int length;
//     struct TreeNode* child;
//     struct TreeNode* brother;
//     char* name;
// }TreeNode, *Tree;
#define YYSTYPE TreeNode*
#include "y.tab.h"
//extern TreeNode::TreeNode(int lineno, NodeType type);


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
"int" {return INT;}
"main" {return MAIN;}
"continue" {return CONTINUE;}
"const" {return CONST;}
"if" {return IF;}
"else" {return ELSE;}
"return" {return RETURN;}
"void" {return VOID;}
"while" {return WHILE;}
"enum" {return ENUM;}
"switch" {return SWITCH;}
"case" {return CASE;}
"for" {return FOR;}
"sizeof" {return SIZEOF;}
"static" {return STATIC;}
"typedef" {return TYPEDEF;}
"break" {return BREAK;}
"do" {return DO;}
"struct" {return STRUCT;}
"signed" {return SIGNED;}
"unsigned" {return UNSIGNED;}
"default" {return DEFAULT;}
"printf" {
    nodePrintf->var_name = "printf";
    nodePrintf->var_scope = "1";
    yylval = nodePrintf;
    return IDENT;
}
"scanf" {
    nodeScanf->var_name = "scanf";
    nodeScanf->var_scope = "1";
    yylval = nodeScanf;
    return IDENT;
}
{NOTE_S}*   {++num_lines;num_cols = 1;}
{commentbegin} {num_cols += yyleng; BEGIN COMMENT;}
<COMMENT>. {num_cols += yyleng;}
<COMMENT>\n {++num_lines; num_cols = 1;}
<COMMENT>{commentend} {num_cols += yyleng; BEGIN INITIAL;}
{IDENTIFIER} {TreeNode* node = new TreeNode(num_lines, NODE_VAR);
    node->var_name = string(yytext);
    yylval = node;
    return IDENT;
}
{INTCONST}  {TreeNode* node = new TreeNode(num_lines, NODE_CONST);
    node->type = TYPE_INT;
    node->type->constvar = true;
    node->int_val = strtol(yytext, NULL, 10);
    yylval = node;
    return INTCONST;
}
"+" {return PLUS;}
"-" {return MINUS;}
"*" {return TIMES;}
"/" {return DIVIDE;}
"%" {return MOD;}
"<" {return LT;}
">" {return GT;}
"!" {return NOR;}
"=" {return EQ;}
"&" {return SAND;}
"|" {return SOR;}
"+=" {return PE;}
"-=" {return ME;}
"*=" {return TE;}
"/=" {return DE;}
"<=" {return LE;}
">=" {return GE;}
"==" {return EE;}
"++" {return SPLUS;}
"--" {return SMINUS;}
"&&" {return AND;}
"||" {return OR;}
"(" {return LP;}
")" {return RP;}
"{" {return LC;}
"}" {return RC;}
"[" {return LB;}
"]" {return RB;}
"," {return COMMA;}
";" {return SEMI;}
"\'" {return SQ;}
"\"" {return DQ;}
.  {num_cols += yyleng;}
%%
int yywrap(){
    return 1;
}
