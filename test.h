#ifndef TEST_HPP
#define TEST_HPP

#include <cstdio>
#include <cmath>
#include <cctype>
#include <cstring>
#include <cstdlib>
#include <cstdarg>
#include <cstdlib>
#include <iostream>
#include <fstream>
#include <string>
#include <list>
#include <assert.h>

#include <vector>
#include <map>
#include <stack>
#include <unordered_map>

using namespace std;

//一些限制
#define MAX_PARAM 16
#define MAX_ARRAY_DIM 8
#define MAX_SCOPE_STACK 32
#define SCOPT_ID_BASE '1'


enum ValueType
{
    NOTYPE,
    VALUE_BOOL,
    VALUE_INT,
    VALUE_STRING,
    VALUE_VOID,
    VALUE_ARRAY,
    COMPOSE_FUNCTION
};

class Type
{
public:
    bool constvar;
    ValueType type;
    Type(ValueType valueType); //初始化为valueType的类型
    void copy(Type* a); //复制a

public:
    unsigned short paramNum; //函数类型需要使用
    Type* paramType[MAX_PARAM];
    Type* retType;
    void addParam(Type* t); //添加参数类型
    void addRet(Type* t); //添加返回值类型
 
    unsigned int dim;   //数组类型需要使用
    ValueType elementType;
    int dimSize[MAX_ARRAY_DIM];
    
    unsigned int visitDim = 0; // 下一次使用下标运算符会访问的维度

    int getSize();

public:
    string getTypeInfo();
    string getTypeInfo(ValueType type);
};

// 设置几个常量Type，可以节省空间开销
static Type* TYPE_INT = new Type(VALUE_INT);
static Type* TYPE_BOOL = new Type(VALUE_BOOL);
static Type* TYPE_STRING = new Type(VALUE_STRING);
static Type* TYPE_VOID = new Type(VALUE_VOID);
static Type* TYPE_NONE = new Type(NOTYPE);

int getSize(Type* type);


enum NodeType
{
	NODE_OP,
	NODE_CONST, 
	NODE_VAR,
	NODE_FUNCALL,

	NODE_PROG,
	NODE_STMT,
	NODE_EXPR,
	NODE_TYPE,
	NODE_VARLIST,
	NODE_PARAM,
};

enum OperatorType
{
	OP_EQ,  	// ==
	OP_NEQ, 	// !=
	OP_GRAEQ,	// >=
	OP_LESEQ,	// <=
	OP_DECLASSIGN,	// =
	OP_ASSIGN,	// =
	OP_GRA,		// >
	OP_LES,		// <
	OP_INC,		// ++
	OP_DEC,		// --
	OP_ADD,		// +
	OP_SUB,		// -
	OP_POS,		// + (一元运算符)
	OP_NAG,		// - (一元运算符)
	OP_MUL,		// *
	OP_DIV,		// /
	OP_MOD,		// %
	OP_NOT,		// !
	OP_AND, 	// &&
	OP_OR,		// ||
	OP_INDEX,	// [] 下标运算符
};

enum StmtType {
	STMT_SKIP,
	STMT_BLOCK,
	STMT_DECL,
	STMT_CONSTDECL,
	STMT_FUNCDECL,
	STMT_IFELSE,
	STMT_IF,
	STMT_WHILE,
	STMT_RETURN,
	STMT_CONTINUE,
	STMT_BREAK,
};

struct List {
	string true_list;
	string false_list;
	string begin_list;
	string next_list;
};

struct TreeNode {
public:
    int num_lines; //行数


	TreeNode* child = nullptr;
	TreeNode* brother = nullptr;

	NodeType nodeType;
	OperatorType optype;// 运算符类型
	StmtType stype;		// 表达式类型
	Type* type;			// 变量、类型、表达式结点，有类型。
	int int_val;
	char ch_val;
	bool b_val;
	string str_val;
	string var_name;
	string var_scope;	// 变量作用域标识符

	TreeNode(int num_lines, NodeType type);
	TreeNode(TreeNode* node);	// 仅用于叶节点拷贝
	TreeNode(int num_lines, NodeType type, int val);
	void addChild(TreeNode*);
	void addBrother(TreeNode*);
	int getLength();
	int getVal();

	// -------------- 类型检查 ----------------

	void typeCheck();
	void findReturn(vector<TreeNode *> &retList);

	// ------------- asm 代码生成 -------------

	int node_seq = 0;
	int temp_var_seq = 0;
	List list;

	void gen_var_list();
	void gen_str();

	string new_list();
	void get_list();

	void genCode();

	
	string getVarPos(TreeNode* p);

public:
	static string nodeType2String (NodeType type);
	static string opType2String (OperatorType type);
	static string sType2String (StmtType type);
};

void InitIONode();
static TreeNode *nodeScanf = new TreeNode(0, NODE_VAR);
static TreeNode* nodePrintf = new TreeNode(0, NODE_VAR);

extern bool typeError;

#endif