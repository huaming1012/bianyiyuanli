%{
#include <stdio.h>
#include <malloc.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include "test.h"
#define YYSTYPE TreeNode*
extern int num_lines;

TreeNode* root = new TreeNode(0, NODE_PROG);

extern bool parserError;

// max_scope_id 是堆栈下一层结点的最大编号
unsigned char max_scope_id = SCOPT_ID_BASE;
string presentScope = "1";
unsigned int top = 0;

//<标识符名称， 作用域> 变量名列表（可重名）
extern multimap<string, string> idNameList;
//<<标识符名称， 作用域>, 结点指针> 变量列表
extern map<pair<string, string>, TreeNode*> idList;

// 用于检查continue和break是否在循环内部
bool inCycle = false;

int yylex();
void yyerror(char const * );
int scopeCmp(string preScope, string varScope);
void scopePush();
void scopePop();


%}

%token INT MAIN CONTINUE CONST IF ELSE RETURN VOID WHILE ENUM SWITCH CASE FOR
%token SIZEOF STATIC TYPEDEF BREAK DO STRUCT SIGNED UNSIGNED DEFAULT
%token IDENT INTCONST PLUS MINUS TIMES DIVIDE MOD LT GT NOR EQ SAND SOR
%token PE ME TE DE LE GE EE SPLUS SMINUS AND OR LP RP LC RC LB RB COMMA SEMI SQ DQ

%nonassoc IFX
%nonassoc ELSE
%right EQ
%left PLUS MINUS
%left TIMES DIVIDE

%%

CompUnit: Decl{root->addChild($1);}
|FuncDef{root->addChild($1);}
|CompUnit Decl{root->addChild($2);}
|CompUnit FuncDef{root->addChild($2);}
;

BType: INT{$$ = new TreeNode(num_lines, NODE_TYPE); $$->type = TYPE_INT;}
|VOID{$$ = new TreeNode(num_lines, NODE_TYPE); $$->type = TYPE_VOID;}
;

// ------ 复合标识符，包含数组，在变量声明外使用 -----
LVal
: Identifier {$$ = $1;}
| ArrayIdent {
	$$ = $1;
	$$->child->type->visitDim = 0;
  }
;

Identifier
: Identifiers{$$ = new TreeNode($1);}
;

ArrayIdent: Identifier LB Exp RB{
	$$ = new TreeNode(num_lines, NODE_OP);
	$$->optype = OP_INDEX;
	$$->addChild($1);

	// 计算数组偏移量倍数
	int biasRate = 1;
	for (unsigned int i = $1->type->visitDim + 1; i < $1->type->dim; i++) {
		biasRate *= $1->type->dimSize[i];
	}
	TreeNode* biasNode;
	if (biasRate == 1) {
		// 偏移倍数为1时省略乘法结点
		biasNode = $3;
	}
	else {
		biasNode = new TreeNode(num_lines, NODE_OP);
		biasNode->optype = OP_MUL;
		biasNode->addChild($3);
		TreeNode* biasRateExpr = new TreeNode(num_lines, NODE_EXPR);
		TreeNode* biasRateConst = new TreeNode(num_lines, NODE_CONST);
		biasRateConst->type = TYPE_INT;
		biasRateConst->int_val = biasRate;
		biasRateExpr->addChild(biasRateConst);
		biasNode->addChild(biasRateExpr);
	}
	$1->type->visitDim++;

	$$->addChild(biasNode);
  }
|ArrayIdent LB Exp RB{
	$$ = $1;
	TreeNode* newBiasNode = new TreeNode(num_lines, NODE_OP);
	newBiasNode->optype = OP_ADD;
	newBiasNode->addChild($$->child->brother);
	$$->child->brother = newBiasNode;

	// 计算数组偏移量倍数
	int biasRate = 1;
	for (unsigned int i = $$->child->type->visitDim + 1; i < $$->child->type->dim; i++) {
		biasRate *= $$->child->type->dimSize[i];
	}

	TreeNode* biasNode;
	if (biasRate == 1) {
		// 偏移倍数为1时省略乘法结点
		biasNode = $3;
	}
	else {
		biasNode->optype = OP_MUL;
		biasNode->addChild($3);
		TreeNode* biasRateExpr = new TreeNode(num_lines, NODE_EXPR);
		TreeNode* biasRateConst = new TreeNode(num_lines, NODE_CONST);
		biasRateConst->type = TYPE_INT;
		biasRateConst->int_val = biasRate;
		biasRateExpr->addChild(biasRateConst);
		biasNode->addChild(biasRateExpr);
	}
	$$->child->type->visitDim++;
	newBiasNode->addChild(biasNode);
  }
;

Identifiers :IDENT {
	$$ = $1;
	int idNameCount = idNameList.count($$->var_name);
	int declCnt = 0;
	int minDefDis = MAX_SCOPE_STACK;

	// 搜索变量是否已经声明
	auto it = idNameList.find($$->var_name);
	int resScoptCmp;
	while (idNameCount--) {
		resScoptCmp = scopeCmp(presentScope, it->second);
		if (resScoptCmp >= 0){
			// 寻找最近的定义
			if (resScoptCmp < minDefDis) {
				minDefDis = resScoptCmp;
				$$ = idList[make_pair(it->first, it->second)];
			}
			declCnt++;
		}
		it++;
	}
	if (declCnt == 0) {
		string t = "Undeclared identifier :'" + $1->var_name + "', scope : " + to_string(resScoptCmp);
		yyerror(t.c_str());
	}
};

//声明标识符

DeclIdentifier: IDENT {  
	$$ = $1;
	$$->var_scope = presentScope;
	$$->type = new Type(NOTYPE);
	if (idList.count(make_pair($$->var_name, $$->var_scope)) != 0) {
		string t = "Redeclared identifier : " + $$->var_name;
		yyerror(t.c_str());
	}
	idNameList.insert(make_pair($$->var_name, $$->var_scope));
	idList[make_pair($$->var_name, $$->var_scope)] = $$;
}
|MAIN{
    TreeNode* tmp = new TreeNode(num_lines, NODE_VAR);
    tmp->var_name = string("main");
    $$ = tmp;
	$$->var_scope = presentScope;
	$$->type = new Type(NOTYPE);
	if (idList.count(make_pair($$->var_name, $$->var_scope)) != 0) {
		string t = "Redeclared identifier : " + $$->var_name;
		yyerror(t.c_str());
	}
	idNameList.insert(make_pair($$->var_name, $$->var_scope));
	idList[make_pair($$->var_name, $$->var_scope)] = $$;
}
;


ArrayDeclIdent
: DeclIdentifier LB Exp RB {
  $$ = $1;
  $$->type->type = VALUE_ARRAY;
  $$->type->elementType = $1->type->type;
  $$->type->dimSize[$$->type->dim] = $3->child->int_val;
  $$->type->dim++;
}
|ArrayDeclIdent LB Exp RB {
  $$ = $1;
  $$->type->dimSize[$$->type->dim] = $3->child->int_val;
  $$->type->dim++;
}
;

//常变量声明
Decl: ConstDecl{$$ = $1;}
|VarDecl{$$ = $1;}
;

ConstDecl: CONST BType ConstDefs SEMI{$$ = new TreeNode(num_lines, NODE_STMT);
$$->stype = STMT_CONSTDECL;
$$->type = TYPE_NONE;
$$->addChild($2);
$$->addChild($3);
TreeNode* p = $3->child;
while(p != nullptr) {
    p->child->type->copy($2->type);
    p->child->type->constvar = true;
    p = p->brother;
}
}
;

ConstDefs: ConstDef{$$ = new TreeNode(num_lines, NODE_VARLIST); $$->addChild($1);}
|ConstDefs COMMA ConstDef{$$ = $1; $$->addChild($3);}
;

ConstDef: DeclIdentifier EQ ConstInitVal{
    //idList[make_pair($1->var_name, $1->var_scope)]->int_val = $3->int_val;
    $$ = new TreeNode(num_lines, NODE_OP); 
	$$->optype = OP_DECLASSIGN;
	$$->addChild($1); 
	$$->addChild($3);}
|ArrayDeclIdent EQ LC ArrayInitVal RC{
    $$ = new TreeNode(num_lines, NODE_OP);
	$$->optype = OP_DECLASSIGN;
	$$->addChild($1); 
	$$->addChild($4);}
;


ConstInitVal: Exp{$$ = $1;}
;

ArrayInitVal: ConstInitVal{$$ = new TreeNode(num_lines, NODE_VARLIST); $$->addChild($1);}
|ArrayInitVal COMMA ConstInitVal{$$ = $1; $$->addChild($3);}
;

VarDecl: BType VarDefs SEMI{
    $$ = new TreeNode(num_lines, NODE_STMT);
    $$->stype = STMT_DECL;
    $$->type = TYPE_NONE;
    $$->addChild($1);
    $$->addChild($2);
    TreeNode* p = $2->child;
    while(p != nullptr) {
        if (p->nodeType == NODE_OP) {
            p->child->type->copy($1->type);
        }
        else {
            p->type->copy($1->type);
        }
        p = p->brother;
    }
}
;

VarDefs: VarDef{$$ = new TreeNode(num_lines, NODE_VARLIST); $$->addChild($1);}
|VarDefs COMMA VarDef{$$ = $1; $$->addChild($3);}
;

VarDef: DeclIdentifier{$$ = $1;}
|ArrayDeclIdent{$$ = $1;}
|DeclIdentifier EQ Exp{
    $$ = new TreeNode(num_lines, NODE_OP);
    //idList[make_pair($1->var_name, $1->var_scope)]->int_val = $3->int_val;
	$$->optype = OP_DECLASSIGN;
	$$->addChild($1);
	$$->addChild($3);}
|ArrayDeclIdent EQ LC ArrayInitVal RC{
    $$ = new TreeNode(num_lines, NODE_OP);
	$$->optype = OP_DECLASSIGN;
	$$->addChild($1);
	$$->addChild($4);}
;

//函数声明
FuncDef: BType DeclIdentifier FuncLP RP LC BlockItems RC{
    $$ = new TreeNode(num_lines, NODE_STMT);
    $$->stype = STMT_FUNCDECL;
    $2->type->type = COMPOSE_FUNCTION;
    $2->type->retType = $1->type;
    $$->addChild($1);
    $$->addChild($2);
    $$->addChild(new TreeNode(num_lines, NODE_VARLIST));
    TreeNode* funcBlock = new TreeNode(num_lines, NODE_STMT);
    funcBlock->stype = STMT_BLOCK;
    funcBlock->addChild($6);
    $$->addChild(funcBlock);
    scopePop();
}
|BType DeclIdentifier FuncLP FuncFParams RP LC BlockItems RC{
    $$ = new TreeNode(num_lines, NODE_STMT);
	$$->stype = STMT_FUNCDECL;
	$2->type->type = COMPOSE_FUNCTION;
	TreeNode* param = $4;
	while (param != nullptr) {
		$2->type->paramType[$2->type->paramNum] = param->child->type;
		$2->type->paramNum++;
		param = param->brother;
	}
	$2->type->retType = $1->type;
	$$->addChild($1);
	$$->addChild($2);
	TreeNode* params = new TreeNode(num_lines, NODE_VARLIST);
	params->addChild($4);
	$$->addChild(params);
	TreeNode* funcBlock = new TreeNode(num_lines, NODE_STMT);
	funcBlock->stype = STMT_BLOCK;
	funcBlock->addChild($7);
	$$->addChild(funcBlock);
	scopePop();}
;

FuncLP: LP {scopePush();};

FuncFParams: FuncFParam{$$ = $1;}
|FuncFParams COMMA FuncFParam{$$ = $1; $$->addBrother($3);}
;

FuncFParam: BType DeclIdentifier{
    $$ = new TreeNode(num_lines, NODE_PARAM); 
	$$->addChild($1); 
	$$->addChild($2);
	$2->type->copy($1->type);}
|BType ArrayDeclIdent{
    $$ = new TreeNode(num_lines, NODE_PARAM); 
	$$->addChild($1); 
	$$->addChild($2);
	$2->type->elementType = $1->type->type;
}
;

//语句块
Block: blockLC BlockItems blockRC{
    $$ = new TreeNode(num_lines, NODE_STMT);
	$$->stype = STMT_BLOCK;
	$$->addChild($2);}
;

blockLC: LC{scopePush();};
blockRC: RC{scopePop();};

BlockItems: BlockItem{$$ = $1;}
|BlockItems BlockItem{$$ = $1; $$->addBrother($2);}
;

BlockItem: Decl{$$ = $1;}
|Stmt{$$ = $1;}
;

Stmts: LC BlockItems RC{
    $$ = new TreeNode(num_lines, NODE_STMT);
	$$->stype = STMT_BLOCK;
	$$->addChild($2);
}
|Stmt{$$ = $1;}
;

Stmt: SEMI{$$ = new TreeNode(num_lines, NODE_STMT); $$->stype = STMT_SKIP;}
|Exp SEMI{$$ = $1;}
|Block{$$ = $1;}
|IF_ LP Cond RP Stmts ELSE Stmts{
    $$ = new TreeNode(num_lines, NODE_STMT);
	$$->stype = STMT_IFELSE;
	$$->addChild($3);
	$$->addChild($5);
	$$->addChild($7);
	scopePop();
}
|IF_ LP Cond RP Stmts %prec IFX{
    $$ = new TreeNode(num_lines, NODE_STMT);
	$$->stype = STMT_IF;
	$$->addChild($3);
	$$->addChild($5);
	scopePop();
}
|WHILE_ LP Cond RP Stmts{
    $$ = new TreeNode(num_lines, NODE_STMT);
	$$->stype = STMT_WHILE;
	$$->addChild($3);
	$$->addChild($5);
	inCycle = false;
	scopePop();
}
|BREAK SEMI{
    if (!inCycle) {
		yyerror("break statement outside loop");
	}
	$$ = new TreeNode(num_lines, NODE_STMT); 
	$$->stype = STMT_BREAK; 
	$$->type = TYPE_NONE;
}
|CONTINUE SEMI{
    if (!inCycle) {
		yyerror("continue statement outside loop");
	}
	$$ = new TreeNode(num_lines, NODE_STMT); 
	$$->stype = STMT_CONTINUE; 
	$$->type = TYPE_NONE;
}
|RETURN Exp SEMI{
    $$ = new TreeNode(num_lines, NODE_STMT); 
    $$->stype = STMT_RETURN;
    $$->addChild($2);
    $$->type = TYPE_NONE;
}
|RETURN SEMI{
    $$ = new TreeNode(num_lines, NODE_STMT); 
    $$->stype = STMT_RETURN; 
    $$->type = TYPE_NONE;}
;

IF_: IF{scopePush();};
WHILE_: WHILE{inCycle = true; scopePush();};

//表达式
Exp: AddExp{$$ = $1; }
|LVal EQ Exp{
    $$ = new TreeNode(num_lines, NODE_OP);
    //$1->int_val = $3->int_val;
	$$->optype = OP_ASSIGN;
	$$->addChild($1);
	$$->addChild($3);
}
;

Cond: LOrExp{$$ = $1;}
;



Number: INTCONST{$$ = new TreeNode(num_lines, NODE_EXPR); $$->addChild($1); //$$->int_val = $1->int_val;
}
;


UnaryExp: PrimaryExp{$$ = $1;}
|PLUS UnaryExp{$$ = new TreeNode(num_lines, NODE_OP); $$->optype = OP_POS; $$->addChild($2);}
|MINUS UnaryExp{$$ = new TreeNode(num_lines, NODE_OP); $$->optype = OP_NAG; $$->addChild($2);}
|NOR UnaryExp{$$ = new TreeNode(num_lines, NODE_OP); $$->optype = OP_NOT; $$->addChild($2);}
;


AddExp: MulExp{$$ = $1;}
|AddExp PLUS MulExp{
    $$ = new TreeNode(num_lines, NODE_OP); 
    $$->optype = OP_ADD; 
    //$$->int_val = $1->int_val + $3->int_val;
    $$->addChild($1); 
    $$->addChild($3);}
|AddExp MINUS MulExp{
    $$ = new TreeNode(num_lines, NODE_OP); 
    $$->optype = OP_SUB; 
    //$$->int_val = $1->int_val - $3->int_val;
    $$->addChild($1); 
    $$->addChild($3);
}
;

MulExp: UnaryExp{$$ = $1;}
|MulExp TIMES UnaryExp{$$ = new TreeNode(num_lines, NODE_OP);  $$->optype = OP_MUL; //$$->int_val = $1->int_val * $3->int_val; 
$$->addChild($1); $$->addChild($3);}
|MulExp DIVIDE UnaryExp{$$ = new TreeNode(num_lines, NODE_OP); $$->optype = OP_DIV; //$$->int_val = $1->int_val / $3->int_val; 
$$->addChild($1); $$->addChild($3);}
|MulExp MOD UnaryExp{$$ = new TreeNode(num_lines, NODE_OP); $$->optype = OP_MOD; //$$->int_val = $1->int_val % $3->int_val; 
$$->addChild($1); $$->addChild($3);}
;


PrimaryExp: LP Exp RP{$$ = $2;}
|LVal{$$ = new TreeNode(num_lines, NODE_EXPR); $$->addChild($1); //$$->int_val = idList[make_pair($1->var_name, $1->var_scope)]->int_val;
}
|Number{$$ = $1;}
|Identifier LP RP{
    $$ = new TreeNode(num_lines, NODE_FUNCALL);
	$$->addChild($1);
	$$->addChild(new TreeNode(num_lines, NODE_VARLIST));
}
|Identifier LP FuncRParams RP{
    $$ = new TreeNode(num_lines, NODE_FUNCALL);
	$$->addChild($1);
	$$->addChild($3);
}
;

FuncRParams: Exp{$$ = new TreeNode(num_lines, NODE_VARLIST); $$->addChild($1);}
|FuncRParams COMMA Exp{$$ = $1; $$->addChild($3);}
;


RelExp: AddExp{$$ = $1;}
|RelExp LT AddExp{$$ = new TreeNode(num_lines, NODE_OP); $$->optype = OP_LES; $$->addChild($1); $$->addChild($3);}
|RelExp GT AddExp{$$ = new TreeNode(num_lines, NODE_OP); $$->optype = OP_GRA; $$->addChild($1); $$->addChild($3);}
|RelExp LE AddExp{$$ = new TreeNode(num_lines, NODE_OP); $$->optype = OP_LESEQ; $$->addChild($1); $$->addChild($3);}
|RelExp GE AddExp{$$ = new TreeNode(num_lines, NODE_OP); $$->optype = OP_GRAEQ; $$->addChild($1); $$->addChild($3);}
;

EqExp: RelExp{$$ = $1;}
|EqExp EE RelExp{$$ = new TreeNode(num_lines, NODE_OP); $$->optype = OP_EQ; $$->addChild($1); $$->addChild($3);}
|EqExp NOR EQ RelExp{$$ = new TreeNode(num_lines, NODE_OP); $$->optype = OP_NEQ; $$->addChild($1); $$->addChild($4);}
;

LAndExp: EqExp{$$ = $1;}
|LAndExp AND EqExp{$$ = new TreeNode(num_lines, NODE_OP); $$->optype = OP_AND; $$->addChild($1); $$->addChild($3);}
;

LOrExp: LAndExp{$$ = $1;}
|LOrExp OR LAndExp{$$ = new TreeNode(num_lines, NODE_OP); $$->optype = OP_OR; $$->addChild($1); $$->addChild($3);}
;

%%

int yylex(void);

void yyerror(char const * message)
{
    printf("Error:%s at line %d", message, num_lines);
    parserError = true;
}


//比较作用域,相同返回0,当前作用域在内层返回正数,当前作用域在外层返回-1,不相交返回-2
int scopeCmp(string presScope, string varScope) {
	unsigned int plen = presScope.length(), vlen = varScope.length();
	unsigned int minlen = min(plen, vlen);
	if (presScope.substr(0, minlen) == varScope.substr(0, minlen)) {
		if (plen >= vlen)
			return plen - vlen;
		else
			return -1;
	}
	return -2;
}

void scopePush() {
	presentScope += max_scope_id;
	max_scope_id = SCOPT_ID_BASE;
	top++;
}

void scopePop() {
	max_scope_id = presentScope[top] + 1;
	presentScope = presentScope.substr(0, presentScope.length() - 1);
	top--;
}


extern int yyparse();
bool parserError = false;
bool typeError = false;

using namespace std;
int main(int argc, char *argv[]) {
    InitIONode();
    yyparse();

    if (parserError)
        return 0;

    root->typeCheck();

    if (typeError)
        return 0;

    root->genCode();

    return 0;
}
