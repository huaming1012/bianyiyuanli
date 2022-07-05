%{
#include <stdio.h>
#include <malloc.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#define YYSTYPE TreeNode*
extern int num_lines;

int nodeid = 0;

typedef struct TreeNode{
    int id;
    int type;
    int length;
    struct TreeNode* child;
    struct TreeNode* brother;
    char* name;
}TreeNode, *Tree;

TreeNode* TreeNode1(char* name, int type){
    TreeNode* root = (TreeNode*)malloc(sizeof(TreeNode));
    root->id = 0;
    root->type = type;
    root->name = (char*)malloc(sizeof(char)*20);
    strcpy(root->name, name);
    root->child = NULL;
    root->brother = NULL;
    return root;
}

TreeNode* TreeNode2(int type){
    TreeNode* root = (TreeNode*)malloc(sizeof(TreeNode));
    root->id = 0;
    root->type = type;
    root->child = NULL;
    root->brother = NULL;
    root->name = (char*)malloc(sizeof(char)*20);
    return root;
}
void addBrother(TreeNode* root, TreeNode* brother);
void Traverse(TreeNode* root, FILE* fp);

void addChild(TreeNode* root, TreeNode* child){
        if(root->child == NULL){
            root->child = child;
        }else{
            addBrother(root->child, child);
        }
    }
void addBrother(TreeNode* root, TreeNode* brother){
        TreeNode* p = root;
        while(p->brother != NULL){
            p = p->brother;
        }
        p->brother = brother;
    }
void createID(TreeNode* root){
        root->id = nodeid++;
        if (root->child)
            createID(root->child);
        if (root->brother)
           createID(root->brother);
    }
void changeID(TreeNode* root){
        TreeNode* p = root->brother;
        while(p){
            p->id = root->id;
            p = p->brother;
        }
        if (root->child)
            changeID(root->child);
        if (root->brother)
            changeID(root->brother);
    }

void Print(TreeNode* root){
    createID(root);
    changeID(root);
    FILE* fp = fopen("Tree.dot", "w");
    root->length = 0;
    if(fp != NULL){
        fprintf(fp, "digraph \" \"\{\n");
        fprintf(fp, "node [shape = record,height=.1]\n");
        fprintf(fp, "node%d[label = \"<f0> CompUnit\"];\n", root->id);
        
        Traverse(root, fp);
        fprintf(fp, "\}");
        fclose(fp);
    }
}
void Traverse(TreeNode* root, FILE* fp){
    TreeNode* p = root->child;
    if(p){
    fprintf(fp, "node%d[label = \"", p->id);
    int num = 0;
    while(p){
        if(num) fprintf(fp,"|");
        p->length = num;
        fprintf(fp, "<f%d> %s", num++, p->name);
        p = p->brother;
    }
    p = root->child;
    fprintf(fp, "\"];\n");
    fprintf(fp, "\"node%d\":f%d->\"node%d\";\n", root->id, root->length, p->id);
    }
    if (root->child)
        Traverse(root->child, fp);
    if (root->brother)
        Traverse(root->brother, fp);
}

void Clean(TreeNode* root){
    if(root->child)
        Clean(root->child);
    if(root->brother)
        Clean(root->brother);
    free(root->name);
    free(root);

}

TreeNode* tree;

%}

%token INT MAIN CONTINUE CONST IF ELSE RETURN VOID WHILE ENUM SWITCH CASE FOR
%token SIZEOF STATIC TYPEDEF BREAK DO STRUCT SIGNED UNSIGNED DEFAULT
%token IDENT INTCONST PLUS MINUS TIMES DIVIDE MOD LT GT NOR EQ SAND SOR
%token PE ME TE DE LE GE EE SPLUS SMINUS AND OR LP RP LC RC LB RB COMMA SEMI SQ DQ

%right EQ
%left PLUS MINUS
%left TIMES DIVIDE

%%
//Program: CompUnit{tree = $1;
//Print(tree);
//printf("$$$$$$$$$$$$$\n");}
//;

CompUnit: Decl{$$ = TreeNode1("CompUnit", 0); addChild($$, $1); 
	tree = $$;
printf("CompUnit -> Decl\n");
}
|FuncDef{$$ = TreeNode1("CompUnit", 0); addChild($$, $1);
tree = $$; 
printf("CompUnit -> FuncDef\n");}
|CompUnit Decl{$$ = TreeNode1("CompUnit", 0); addChild($$, $1); addChild($$, $2); 
tree = $$;
printf("CompUnit -> CompUnit Decl\n");}
|CompUnit FuncDef{$$ = TreeNode1("CompUnit", 0); addChild($$, $1); addChild($$, $2);
tree = $$; 
printf("CompUnit -> CompUnit FuncDef\n");}
;

//常变量声明
Decl: ConstDecl{$$ = TreeNode1("Decl", 0); addChild($$, $1);printf("Decl -> ConstDecl\n");}
    |VarDecl{$$ = TreeNode1("Decl", 0); addChild($$, $1);printf("Decl -> VarDecl\n");}
;

ConstDecl: CONST INT ConstDefs SEMI{$$ = TreeNode1("ConstDecl", 0);
	 TreeNode* tmp1 = TreeNode1("const", 1);
TreeNode* tmp2 = TreeNode1("int", 1);
TreeNode* tmp3 = TreeNode1("\\;", 1);
addChild($$, tmp1);
addChild($$, tmp2);
addChild($$, $3);
addChild($$, tmp3);
printf("ConstDecl -> const int ConstDef {, ConstDef} ;\n");}
;

ConstDefs: ConstDef{$$ = TreeNode1("ConstDefs", 0); addChild($$, $1);}
	 |ConstDefs COMMA ConstDef{$$ = TreeNode1("ConstDefs", 0); 
TreeNode* tmp1 = TreeNode1("\\,", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);}
;

ConstDef: IDENT ArrayIdent EQ ConstInitVal{$$ = TreeNode1("ConstDef", 0);
	TreeNode* tmp1 = TreeNode1("\\=", 1);
addChild($$, $1);
addChild($$, $2);
addChild($$, tmp1);
addChild($$, $4);
printf("ConstDef -> Ident {'['ConstExp']'} = ConstInitVal\n");}
|IDENT EQ ConstInitVal{$$ = TreeNode1("ConstDef", 0);
TreeNode* tmp1 = TreeNode1("\\=", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("ConstDef -> Ident = ConstInitVal\n");}
;

ArrayIdent: LB ConstExp RB{$$ = TreeNode1("ArrayIdent", 0);
	  TreeNode* tmp1 = TreeNode1("\\[", 1);
TreeNode* tmp2 = TreeNode1("\\]", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);
}
|ArrayIdent LB ConstExp RB{$$ = TreeNode1("ArrayIdent", 0);
TreeNode* tmp1 = TreeNode1("\\[", 1);
TreeNode* tmp2 = TreeNode1("\\]", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
addChild($$, tmp2);}
;

ConstInitVal: ConstExp{$$ = TreeNode1("ConstInitVal", 0);
	    addChild($$, $1);
printf("ConstInitVal -> ConstExp\n");}
|LC ArrayInitVal RC{$$ = TreeNode1("ConstInitVal", 0);
TreeNode* tmp1 = TreeNode1("\\{", 1);
TreeNode* tmp2 = TreeNode1("\\}", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);
printf("ConstInitVal -> '{'ConstInitVal {, ConstInitVal}'}'\n");}
|LC RC{$$ = TreeNode1("ConstInitVal", 0);
TreeNode* tmp1 = TreeNode1("\\{", 1);
TreeNode* tmp2 = TreeNode1("\\}", 1);
addChild($$, tmp1);
addChild($$, tmp2);
printf("ConstInitVal -> '{''}'\n");}
;

ArrayInitVal: ConstInitVal{$$ = TreeNode1("ArrayInitVal", 0);
	    addChild($$, $1);}
|ArrayInitVal COMMA ConstInitVal{$$ = TreeNode1("ArrayInitVal", 0);
TreeNode* tmp1 = TreeNode1("\\,", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);}
;

VarDecl: INT VarDefs SEMI{$$ = TreeNode1("VarDecl", 0);
       TreeNode* tmp1 = TreeNode1("int", 1);
TreeNode* tmp2 = TreeNode1("\\;", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);
printf("VarDecl -> int VarDef {, VarDef} ;\n");}
;

VarDefs: VarDef{$$ = TreeNode1("VarDefs", 0);
       addChild($$, $1);}
|VarDefs COMMA VarDef{$$ = TreeNode1("VarDefs", 0);
TreeNode* tmp1 = TreeNode1("\\,", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);}
;

VarDef: IDENT{$$ = TreeNode1("VarDef", 0);
      addChild($$, $1);
printf("VarDef -> Ident\n");}
|IDENT EQ InitVal{$$ = TreeNode1("VarDef", 0);
TreeNode* tmp1 = TreeNode1("\\=", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("VarDef -> Ident = InitVal\n");}
|IDENT ArrayIdent{$$ = TreeNode1("VarDef", 0);
addChild($$, $1);
addChild($$, $2);
printf("VarDef -> Ident {'['ConstExp']'}\n");}
|IDENT ArrayIdent EQ InitVal{$$ = TreeNode1("VarDef", 0);
TreeNode* tmp1 = TreeNode1("\\=", 1);
addChild($$, $1);
addChild($$, $2);
addChild($$, tmp1);
addChild($$, $4);
printf("VarDef -> Ident {'['ConstExp']'} = InitVal\n");}
;

InitVal: Exp{$$ = TreeNode1("InitVal", 0);
       addChild($$, $1);
printf("InitVal -> Exp\n");}
|LC InitVals RC{$$ = TreeNode1("InitVal", 0);
TreeNode* tmp1 = TreeNode1("\\{", 1);
TreeNode* tmp2 = TreeNode1("\\}", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);
printf("InitVal -> '{'InitVal {, InitVal }'}'\n");}
|LC RC{$$ = TreeNode1("InitVal", 0);
TreeNode* tmp1 = TreeNode1("\\{", 1);
TreeNode* tmp2 = TreeNode1("\\}", 1);
addChild($$, tmp1);
addChild($$, tmp2);
printf("InitVal -> '{''}'\n");}
;

InitVals: InitVal{$$ = TreeNode1("InitVals", 0);
	addChild($$, $1);}
|InitVals COMMA InitVal{$$ = TreeNode1("InitVals", 0);
TreeNode* tmp1 = TreeNode1("\\,", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);}
;

//函数声明========
FuncDef: VOID IDENT LP RP Block{$$ = TreeNode1("FuncDef", 0);
       TreeNode* tmp1 = TreeNode1("void", 1);
TreeNode* tmp2 = TreeNode1("\\(", 1);
TreeNode* tmp3 = TreeNode1("\\)", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);
addChild($$, tmp3);
addChild($$, $5);
printf("FuncType -> void\n");
printf("FuncDef -> FuncType Ident '('')' Block\n");}
|INT IDENT LP RP Block{$$ = TreeNode1("FuncDef", 0);
TreeNode* tmp1 = TreeNode1("int", 1);
TreeNode* tmp2 = TreeNode1("\\(", 1);
TreeNode* tmp3 = TreeNode1("\\)", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);
addChild($$, tmp3);
addChild($$, $5);
printf("FuncType -> int\n");
printf("FuncDef -> FuncType Ident '('')' Block\n");}
|VOID IDENT LP FuncFParams RP Block{$$ = TreeNode1("FuncDef", 0);
TreeNode* tmp1 = TreeNode1("void", 1);
TreeNode* tmp2 = TreeNode1("\\(", 1);
TreeNode* tmp3 = TreeNode1("\\)", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);
addChild($$, $4);
addChild($$, tmp3);
addChild($$, $6);
printf("FuncType -> void\n");
printf("FuncDef -> FuncType Ident '('FuncFParams')' Block\n");}
|INT IDENT LP FuncFParams RP Block{$$ = TreeNode1("FuncDef", 0);
TreeNode* tmp1 = TreeNode1("int", 1);
TreeNode* tmp2 = TreeNode1("\\(", 1);
TreeNode* tmp3 = TreeNode1("\\)", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);
addChild($$, $4);
addChild($$, tmp3);
addChild($$, $6);
printf("FuncType -> int\n");
printf("FuncDef -> FuncType Ident '('FuncFParams')' Block\n");}
|INT MAIN LP RP Block{$$ = TreeNode1("FuncDef", 0);
TreeNode* tmp1 = TreeNode1("int", 1);
TreeNode* tmp2 = TreeNode1("main", 1);
TreeNode* tmp3 = TreeNode1("\\(", 1);
TreeNode* tmp4 = TreeNode1("\\)", 1);
addChild($$, tmp1);
addChild($$, tmp2);
addChild($$, tmp3);
addChild($$, tmp4);
addChild($$, $5);
printf("FuncDef -> int main '('')' Block\n");}
;

FuncFParams: FuncFParam{$$ = TreeNode1("FuncFParams", 0);
	   addChild($$, $1);
printf("FuncFParams -> FuncFParam {, FuncFParam}\n");}
|FuncFParams COMMA FuncFParam{$$ = TreeNode1("FuncFParams", 0);
TreeNode* tmp1 = TreeNode1("\\,", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("FuncFParams -> FuncFParam {, FuncFParam}\n");}
;

FuncFParam: INT IDENT{$$ = TreeNode1("FuncFParam", 0);
	  TreeNode* tmp1 = TreeNode1("int", 1);
addChild($$, tmp1);
addChild($$, $2);
printf("FuncFParam -> int Ident\n");}
|INT IDENT LB RB{$$ = TreeNode1("FuncFParam", 0);
TreeNode* tmp1 = TreeNode1("int", 1);
TreeNode* tmp2 = TreeNode1("\\[", 1);
TreeNode* tmp3 = TreeNode1("\\]", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);
addChild($$, tmp3);
printf("FuncFParam -> int Ident '[' ']'\n");}
|INT IDENT LB RB Params{$$ = TreeNode1("FuncFParam", 0);
TreeNode* tmp1 = TreeNode1("int", 1);
TreeNode* tmp2 = TreeNode1("\\[", 1);
TreeNode* tmp3 = TreeNode1("\\]", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);
addChild($$, tmp3);
addChild($$, $5);
printf("FuncFParam -> int Ident '[' ']' {'['Exp']'}\n");}
;

Params: LB Exp RB{$$ = TreeNode1("Params", 0);
      TreeNode* tmp1 = TreeNode1("\\[", 1);
TreeNode* tmp2 = TreeNode1("\\]", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);}
|Params LB Exp RB{$$ = TreeNode1("Params", 0);
TreeNode* tmp1 = TreeNode1("\\[", 1);
TreeNode* tmp2 = TreeNode1("\\]", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
addChild($$, tmp2);}
;

//语句块
Block: LC BlockItems RC{$$ = TreeNode1("Block", 0);
     TreeNode* tmp1 = TreeNode1("\\{", 1);
TreeNode* tmp2 = TreeNode1("\\}", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);
printf("Block -> '{'{ BlockItem }'}'\n");}
;

BlockItems: /*Empty*/{$$ = TreeNode1("BlockItems", 0);
	  TreeNode* tmp1 = TreeNode1("/*empty*/", 1);
addChild($$, tmp1);}
|BlockItems BlockItem{$$ = TreeNode1("BlockItems", 0);
addChild($$, $1);
addChild($$, $2);}
;

BlockItem: Decl{$$ = TreeNode1("BlockItem", 0);
	 addChild($$, $1);
printf("BlockItem -> Decl\n");}
|Stmt{$$ = TreeNode1("BlockItem", 0);
addChild($$, $1);
printf("BlockItem -> Stmt\n");}
;

Stmt: LVal EQ Exp SEMI{$$ = TreeNode1("Stmt", 0);
    TreeNode* tmp1 = TreeNode1("\\=", 1);
TreeNode* tmp2 = TreeNode1("\\;", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
addChild($$, tmp2);
printf("Stmt -> LVal = Exp ;\n");}
|SEMI{$$ = TreeNode1("Stmt", 0);
TreeNode* tmp1 = TreeNode1("\\;", 1);
addChild($$, tmp1);
printf("Stmt -> ;\n");}
|Exp SEMI{$$ = TreeNode1("Stmt", 0);
TreeNode* tmp1 = TreeNode1("\\;", 1);
addChild($$, $1);
addChild($$, tmp1);
printf("Stmt -> Exp ;\n");}
|Block{$$ = TreeNode1("Stmt", 0);
addChild($$, $1);
printf("Stmt -> Block\n");}
|IF LP Cond RP Stmt ELSE Stmt{$$ = TreeNode1("Stmt", 0);
TreeNode* tmp1 = TreeNode1("if", 1);
TreeNode* tmp2 = TreeNode1("\\(", 1);
TreeNode* tmp3 = TreeNode1("\\)", 1);
TreeNode* tmp4 = TreeNode1("else", 1);
addChild($$, tmp1);
addChild($$, tmp2);
addChild($$, $3);
addChild($$, tmp3);
addChild($$, $5);
addChild($$, tmp4);
addChild($$, $7);
printf("Stmt -> if '('Cond')' Stmt else Stmt\n");}
|IF LP Cond RP Stmt{$$ = TreeNode1("Stmt", 0);
TreeNode* tmp1 = TreeNode1("if", 1);
TreeNode* tmp2 = TreeNode1("\\(", 1);
TreeNode* tmp3 = TreeNode1("\\)", 1);
addChild($$, tmp1);
addChild($$, tmp2);
addChild($$, $3);
addChild($$, tmp3);
addChild($$, $5);
printf("Stmt -> if '('Cond')' Stmt\n");}
|WHILE LP Cond RP Stmt{$$ = TreeNode1("Stmt", 0);
TreeNode* tmp1 = TreeNode1("while", 1);
TreeNode* tmp2 = TreeNode1("\\(", 1);
TreeNode* tmp3 = TreeNode1("\\)", 1);
addChild($$, tmp1);
addChild($$, tmp2);
addChild($$, $3);
addChild($$, tmp3);
addChild($$, $5);
printf("Stmt -> while '('Cond')' Stmt\n");}
|BREAK SEMI{$$ = TreeNode1("Stmt", 0);
TreeNode* tmp1 = TreeNode1("break", 1);
TreeNode* tmp2 = TreeNode1("\\;", 1);
addChild($$, tmp1);
addChild($$, tmp2);
printf("Stmt -> break ;\n");}
|CONTINUE SEMI{$$ = TreeNode1("Stmt", 0);
TreeNode* tmp1 = TreeNode1("continue", 1);
TreeNode* tmp2 = TreeNode1("\\;", 1);
addChild($$, tmp1);
addChild($$, tmp2);
printf("Stmt -> continue ;\n");}
|RETURN Exp SEMI{$$ = TreeNode1("Stmt", 0);
TreeNode* tmp1 = TreeNode1("return", 1);
TreeNode* tmp2 = TreeNode1("\\;", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);
printf("Stmt -> return Exp ;\n");}
|RETURN SEMI{$$ = TreeNode1("Stmt", 0);
TreeNode* tmp1 = TreeNode1("return", 1);
TreeNode* tmp2 = TreeNode1("\\;", 1);
addChild($$, tmp1);
addChild($$, tmp2);
printf("Stmt -> return ;\n");}
;

//表达式
Exp: AddExp{$$ = TreeNode1("Exp", 0);
   addChild($$, $1);
printf("Exp -> AddExp\n");}
;

Cond: LOrExp{$$ = TreeNode1("Cond", 0);
    addChild($$, $1);
printf("Cond -> LOrExp\n");}
;

LVal: IDENT{$$ = TreeNode1("LVal", 0);
    addChild($$, $1);
printf("LVal -> Ident {'['Exp']'}\n");}
|IDENT LVals{$$ = TreeNode1("LVal", 0);
addChild($$, $1);
addChild($$, $2);
printf("LVal -> Ident {'['Exp']'}\n");}
;

LVals: LB Exp RB{$$ = TreeNode1("LVals", 0);
     TreeNode* tmp1 = TreeNode1("\\[", 1);
TreeNode* tmp2 = TreeNode1("\\]", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);}
|LVals LB Exp RB{$$ = TreeNode1("LVals", 0);
TreeNode* tmp1 = TreeNode1("\\[", 1);
TreeNode* tmp2 = TreeNode1("\\]", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
addChild($$, tmp2);}
;

PrimaryExp: LP Exp RP{$$ = TreeNode1("PrimaryExp", 0);
	  TreeNode* tmp1 = TreeNode1("\\(", 1);
TreeNode* tmp2 = TreeNode1("\\)", 1);
addChild($$, tmp1);
addChild($$, $2);
addChild($$, tmp2);
printf("PrimaryExp -> '('Exp')'\n");}
|LVal{$$ = TreeNode1("PrimaryExp", 0);
addChild($$, $1);
printf("PrimaryExp -> LVal\n");}
|Number{$$ = TreeNode1("PrimaryExp", 0);
addChild($$, $1);
printf("PrimaryExp -> Number\n");}
;

Number: INTCONST{$$ = TreeNode1("Number", 0);
      addChild($$, $1);
printf("Number -> IntConst\n");}
;

UnaryExp: PrimaryExp{$$ = TreeNode1("UnaryExp", 0);
	addChild($$, $1);
printf("UnaryExp -> PrimaryExp\n");}
|IDENT LP RP{$$ = TreeNode1("UnaryExp", 0);
TreeNode* tmp1 = TreeNode1("\\(", 1);
TreeNode* tmp2 = TreeNode1("\\)", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, tmp2);
printf("UnaryExp -> Ident '(' ')'\n");}
|IDENT LP FuncRParams RP{$$ = TreeNode1("UnaryExp", 0);
TreeNode* tmp1 = TreeNode1("\\(", 1);
TreeNode* tmp2 = TreeNode1("\\)", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
addChild($$, tmp2);
printf("UnaryExp -> Ident '('FuncRParams')'\n");}
|UnaryOp UnaryExp{$$ = TreeNode1("UnaryExp", 0);
addChild($$, $1);
addChild($$, $2);
printf("UnaryExp -> UnaryOp UnaryExp\n");}
;

UnaryOp: PLUS{$$ = TreeNode1("UnaryOp", 0);
       TreeNode* tmp1 = TreeNode1("\\+", 1);
addChild($$, tmp1);
printf("UnaryOp -> +\n");}
|MINUS{$$ = TreeNode1("UnaryOp", 0);
TreeNode* tmp1 = TreeNode1("\\-", 1);
addChild($$, tmp1);
printf("UnaryOp -> -\n");}
|NOR{$$ = TreeNode1("UnaryOp", 0);
TreeNode* tmp1 = TreeNode1("\\!", 1);
addChild($$, tmp1);
printf("UnaryOp -> !\n");}
;

FuncRParams: Exp{$$ = TreeNode1("FuncRParams", 0);
	   addChild($$, $1);
printf("FuncRParams -> Exp {, Exp}\n");}
|FuncRParams COMMA Exp{$$ = TreeNode1("FuncRParams", 0);
TreeNode* tmp1 = TreeNode1("\\,", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("FuncRParams -> Exp {, Exp}\n");}
;

MulExp: UnaryExp{$$ = TreeNode1("MulExp", 0);
      addChild($$, $1);
printf("MulExp -> UnaryExp\n");}
|MulExp TIMES UnaryExp{$$ = TreeNode1("MulExp", 0);
TreeNode* tmp1 = TreeNode1("\\*", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("MulExp -> MulExp * UnaryExp\n");}
|MulExp DIVIDE UnaryExp{$$ = TreeNode1("MulExp", 0);
TreeNode* tmp1 = TreeNode1("\\/", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("MulExp -> MulExp / UnaryExp\n");}
|MulExp MOD UnaryExp{$$ = TreeNode1("MulExp", 0);
TreeNode* tmp1 = TreeNode1("\\%", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("MulExp -> MulExp \% UnaryExp\n");}
;

AddExp: MulExp{$$ = TreeNode1("AddExp", 0);
      addChild($$, $1);
printf("AddExp -> MulExp\n");}
|AddExp PLUS MulExp{$$ = TreeNode1("AddExp", 0);
TreeNode* tmp1 = TreeNode1("\\+", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("AddExp -> AddExp + MulExp\n");}
|AddExp MINUS MulExp{$$ = TreeNode1("AddExp", 0);
TreeNode* tmp1 = TreeNode1("\\-", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("AddExp -> AddExp - MulExp\n");}
;

RelExp: AddExp{$$ = TreeNode1("RelExp", 0);
      addChild($$, $1);
printf("RelExp -> AddExp\n");}
|RelExp LT AddExp{$$ = TreeNode1("RelExp", 0);
TreeNode* tmp1 = TreeNode1("\\<", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("RelExp -> RelExp < AddExp\n");}
|RelExp GT AddExp{$$ = TreeNode1("RelExp", 0);
TreeNode* tmp1 = TreeNode1("\\>", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("RelExp -> RelExp > AddExp\n");}
|RelExp LE AddExp{$$ = TreeNode1("RelExp", 0);
TreeNode* tmp1 = TreeNode1("\\<\\=", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("RelExp -> RelExp <= AddExp\n");}
|RelExp GE AddExp{$$ = TreeNode1("RelExp", 0);
TreeNode* tmp1 = TreeNode1("\\>\\=", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("RelExp -> RelExp >= AddExp\n");}
;

EqExp: RelExp{$$ = TreeNode1("EqExp", 0);
     addChild($$, $1);
printf("EqExp -> RelExp\n");}
|EqExp EE RelExp{$$ = TreeNode1("EqExp", 0);
TreeNode* tmp1 = TreeNode1("\\=\\=", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("EqExp -> EqExp == RelExp\n");}
|EqExp NOR EQ RelExp{$$ = TreeNode1("EqExp", 0);
TreeNode* tmp1 = TreeNode1("\\!\\=", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $4);
printf("EqExp -> EqExp != RelExp\n");}
;

LAndExp: EqExp{$$ = TreeNode1("LAndExp", 0);
       addChild($$, $1);
printf("LAndExp -> EqExp\n");}
|LAndExp AND EqExp{$$ = TreeNode1("LAndExp", 0);
TreeNode* tmp1 = TreeNode1("\\&\\&", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("LAndExp -> LAndExp && EqExp\n");}
;

LOrExp: LAndExp{$$ = TreeNode1("LOrExp", 0);
      addChild($$, $1);
printf("LOrExp -> LAndExp\n");}
|LOrExp OR LAndExp{$$ = TreeNode1("LOrExp", 0);
TreeNode* tmp1 = TreeNode1("\\|\\|", 1);
addChild($$, $1);
addChild($$, tmp1);
addChild($$, $3);
printf("LOrExp -> LOrExp || LAndExp\n");}
;
ConstExp: AddExp{$$ = TreeNode1("ConstExp", 0);
	addChild($$, $1);
printf("ConstExp -> AddExp\n");}
;

%%

int yylex(void);

void yyerror(char* s){
    printf("Error:%s at line %d", s, num_lines);
}

int main(){
    yyparse();
    if(tree){
        Print(tree);
        Clean(tree);
    }
    return 0;
}

