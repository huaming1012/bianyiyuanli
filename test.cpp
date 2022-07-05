#include "test.h"

// ----------------------- 全局变量 ----------------------------


//<标识符名称， 作用域> 变量名列表 （可重名但不能同一作用域内）
multimap<string, string> idNameList;
//<<标识符名称， 作用域>, 结点指针> 变量列表
map<pair<string, string>, TreeNode *> idList;


// <作用域+变量名， 变量相对于ebp偏移量> 局部变量表，在每次函数定义前清空
// <"11a", "-12"> 表示第一个函数的栈上第一个分配的局部变量（前3个4字节为bx,cx,dx备份用，始终保留）
map<string, int> LocalVarList;
// 栈上为局部变量分配的空间总大小，在return时进行清理
int stackSize;

// 当前所处函数的声明结点指针，return使用
TreeNode *pFunction;

// 循环体栈，为continue与break配对使用
TreeNode *cycleStack[10];
int cycleStackTop = -1;

Type::Type(ValueType valueType) { //初始化为valueType的类型
    this->type = valueType;
    this->paramNum = 0;
    this->constvar = false;
    this->retType = nullptr;
    this->dim = 0;
    this->visitDim = 0;
}

void Type::copy(Type* a) {  //复制a
    this->type = a->type;
    this->constvar = a->constvar;
    if (a->paramNum) {
        this->paramNum = a->paramNum;
        for (unsigned short i=0;i<a->paramNum;i++) {
            this->paramType[i] = a->paramType[i];
        }
        this->retType = a->retType;
    }
    if (a->dim) {
        this->dim = a->dim;
        this->elementType = a->elementType;
        for (unsigned int i=0;i<a->dim;i++) {
            this->dimSize[i] = a->dimSize[i];
        }
    }
}

string Type::getTypeInfo() { //返回其类型信息
    return getTypeInfo(this->type);
}

string Type::getTypeInfo(ValueType type) { //返回其类型信息
    switch(type) {
        case VALUE_BOOL:
            return "bool";
        case VALUE_INT:
            return "int";
        case VALUE_STRING:
            return "string";
        case VALUE_ARRAY:
            if (this->dim > 0) {
                string buf = getTypeInfo(this->elementType);
                for (unsigned int i = 0; i < dim && i < MAX_ARRAY_DIM; i++) {
                    buf += "[" + to_string(dimSize[i]) + "]";
                }
                return buf;
            }
            return "";
        case VALUE_VOID:
            return "void";
        case NOTYPE:
            return "no type";
        default:
            return "?";
    }
}

void Type::addParam(Type* param){ //添加参数类型
    this->paramType[paramNum++] = param;
}

void Type::addRet(Type* t){ //添加返回值类型
    this->retType = t;
}

int Type::getSize() { //计算该类型所占空间大小
    int size = 1;
    int eleSize;
    switch (type)
    {
    case VALUE_BOOL:
    case VALUE_INT:
    case VALUE_STRING:
        return 4;
    case VALUE_ARRAY:
        eleSize = 4;
        for (unsigned int i = 0; i < dim; i++)
            size *= dimSize[i];
        return eleSize * size;
    default:
        return 0;
    }
}


//重载string相关运算符+和+=
string operator + (string &content, int number) {
    return content + to_string(number);
}
string& operator += (string &content, int number) {
	return content = content + to_string(number);
}



// ------------------------ 代码 ------------------------------

TreeNode::TreeNode(int num_lines, NodeType type) {  //用行号和节点类型初始化
    this->num_lines = num_lines;
    this->nodeType = type;
}
TreeNode::TreeNode(int num_lines, NodeType type, int val) {  //用行号和节点类型初始化
    this->num_lines = num_lines;
    this->nodeType = type;
    this->int_val = int_val;
}

TreeNode::TreeNode(TreeNode* node) { //复制另一个节点node来初始化
    this->num_lines = node->num_lines;
    this->nodeType = node->nodeType;
    this->optype = node->optype;
	this->stype = node->stype;
	this->type = node->type;
	this->int_val = node->int_val;
	this->ch_val = node->ch_val;
	this->b_val = node->b_val;
	this->str_val = node->str_val;
	this->var_name = node->var_name;
	this->var_scope = node->var_scope;
}

void TreeNode::addChild(TreeNode* child) {  //添加子节点
    if (this->child == NULL) {
        this->child = child;
    }
    else {
        this->child->addBrother(child); //已有子节点时添加到子节点的兄弟节点
    }
}

void TreeNode::addBrother(TreeNode* brother) { //添加兄弟节点
    TreeNode* p = this; 
    while (p->brother != nullptr) {
        p = p->brother;
    }
    p->brother = brother;
}

int TreeNode::getLength() { //返回其子节点代表的规约式长度
    int num = 0;
    for (TreeNode *p = this->child; p != nullptr; p = p->brother)
        num++;
    return num;
}

int TreeNode::getVal() {//返回该节点或其子节点（如果为常数值）的值
    if (nodeType == NODE_CONST) {
        switch (type->type)
        {
        case VALUE_BOOL:
            return (b_val ? 1 : 0);
        case VALUE_INT:
            return int_val;
        default:
            return 0;
        }
    }
    else if (child->nodeType == NODE_CONST) {
        return child->getVal();
    }
    return 0;
}


void TreeNode::typeCheck() { //类型检查

    // 类型检查时记录循环层数，为continue和break提供循环外错误检查
    if (nodeType == NODE_STMT && stype == STMT_WHILE) { //只有while语句是循环
        cycleStackTop++;
    }

    // 递归遍历子节点及其兄弟节点进行类型检查
    TreeNode *p = this->child;
    while (p != nullptr) {
        p->typeCheck();
        p = p->brother;
    }


    // 分情况检查类型错误并对部分情况作强制类型转换
    switch (this->nodeType)
    {
    case NODE_FUNCALL: // 函数调用，标识符类型是函数，且形参表与函数定义一致
        if (child->type->type == COMPOSE_FUNCTION) {
            if (child->var_name == "printf" || child->var_name == "scanf") { //scanf和printf的参数要是int类型
                if (child->brother->child->type->type != VALUE_INT) {
                    cout << "Wrong type: paramater type doesn`t fit function " << child->var_name
                         << "need <int>, got " << child->brother->child->type->getTypeInfo()
                         << " , at line " << num_lines << endl;
                    typeError = true;
                }
                break;
            }
            if (child->brother->getLength() == child->type->paramNum) { 
                int paracnt = 0;
                TreeNode *param = child->brother->child;
                while (param!=nullptr) {
                    if (child->type->paramType[paracnt] != TYPE_NONE // 具体类型不符
                        && child->type->paramType[paracnt]->type != param->type->type) {
                        cout << "Wrong type: paramater type doesn`t fit function " << child->var_name
                                << " got " << param->type->getTypeInfo()
                                << " need " << child->type->paramType[paracnt]->getTypeInfo()
                                << ", at line " << num_lines << endl;
                        typeError = true;
                    }
                    paracnt++;
                    param = param->brother;
                }
            }
            else { //数量不符
                cout << "Wrong type: paramater num doesn`t fit function " << child->var_name << " , at line " << num_lines << endl;
                typeError = true;
            }
        }
        else {
            cout << "Wrong type: identifier " << child->var_name << " isn`t a function, at line " << num_lines << endl;
            typeError = true;
        }
        if (!type)
            this->type = new Type(NOTYPE);
        this->type->copy(child->type->retType); //设置为其返回值类型
        break;
    case NODE_STMT:// 语句
        this->type = TYPE_NONE;
        switch (stype) {
        case STMT_FUNCDECL: {  //函数声明
            vector<TreeNode *> retList;
            findReturn(retList);
            int size = retList.size();
            if (child->brother->type->retType->type == VALUE_VOID) {
                // void函数只能return；或没有return
                for (int i = 0; i < size; i++) {
                    if (retList[i]->child) {
                        cout << "Wrong return: none void return in void function, at line " << retList[i]->num_lines << endl;
                        typeError = true;
                    }
                }
            }
            else {// 其它函数（int）必须return且类型一致
                if (size == 0) {
                    cout << "Wrong return: none void function without any return statement, function decl at line " << child->brother->num_lines << endl;
                    typeError = true;
                }
                else {
                    for (int i = 0; i < size; i++) {
                        if (retList[i]->child) {
                            if (retList[i]->child->type->type != child->type->type) {
                                cout << "Wrong type: return type can`t fit function return type, at line " 
                                << retList[i]->num_lines << endl;
                            typeError = true;
                            }
                        }
                        else {
                            cout << "Wrong return: return nothing in none void function, at line " << retList[i]->num_lines << endl;
                            typeError = true;
                        }
                    }
                }
            }
            break;
        }
        case STMT_IF:
        case STMT_IFELSE:
        case STMT_WHILE:
            if (child->type->type != VALUE_BOOL) {
                if (child->type->type == VALUE_INT) {
                    // 强制类型转换，添加一个"!=0"运算过程
                    TreeNode *eq = new TreeNode(child->num_lines, NODE_OP);
                    eq->brother = child->brother;
                    eq->child = child;
                    eq->type = TYPE_BOOL;
                    eq->optype = OP_NEQ;
                    child->brother = new TreeNode(child->num_lines, NODE_CONST);
                    child->brother->type = TYPE_INT;
                    child->brother->int_val = 0;
                    child = eq;
                    cout << "# Type Cast from <int> to <bool> because of a \""
                         << this->sType2String(stype)
                         << "\" statement, at line " << child->num_lines << endl;
                }
                else {
                    cout << "Wrong type: need <bool>, got " << child->type->getTypeInfo()
                         << ", at line " << child->num_lines << endl;
                    typeError = true;
                }
            }
            if (stype == STMT_WHILE)
                cycleStackTop--;
            break;
        case STMT_BREAK:
        case STMT_CONTINUE:
            if (cycleStackTop < 0) {
                cout << "Error cycle control statement: " << sType2String(stype)
                     << ", outside a cycle, at line " << num_lines << endl;
                typeError = true;
            }
            break;
        case STMT_RETURN:

            break;
        default:
            break;
        }
        break;
    case NODE_EXPR:
        this->type = this->child->type;
        break;
    case NODE_OP:
        if (optype == OP_INC || optype == OP_DEC || optype == OP_POS || optype == OP_NAG) {
            // 一元运算符++,--,+(一元),-(一元)，操作数int
            if (this->child->type->type != VALUE_INT) {
                cout << "Wrong type: need <int>, got <" << child->type->getTypeInfo()
                     << ">, operator is " << opType2String(optype) << ", at line " << num_lines << endl;
                typeError = true;
            }
            this->type = TYPE_INT;
        } 
        else if(optype == OP_NOT){
            if (this->child->type->type != VALUE_INT && this->child->type->type != VALUE_BOOL) {
                cout << "Wrong type: need <bool>, got <" << child->type->getTypeInfo()
                     << ">, operator is " << opType2String(optype) << ", at line " << num_lines << endl;
                typeError = true;
            }
            this->type = TYPE_BOOL;
        }
        else if (optype == OP_EQ || optype == OP_NEQ || optype == OP_ASSIGN || optype == OP_DECLASSIGN) {
            // 二元运算符==,!=,=（赋值)，两侧同类型
            if (this->child->type->type != this->child->brother->type->type) {
                cout << "Wrong type: type in two sides of " << opType2String(optype)
                     << " operator mismatched, got <" << child->type->getTypeInfo()
                     << "> and <" << child->brother->type->getTypeInfo()
                     << ">, at line " << num_lines << endl;
                typeError = true;
            }
            if (optype == OP_ASSIGN && child->type->constvar) { //不能给常数赋值
                cout << "Wrong assign: assign to a const varable, at line " << num_lines;
                typeError = true;
            }
            if (optype == OP_ASSIGN || optype == OP_DECLASSIGN)
                this->type = this->child->type;
            else
                this->type = TYPE_BOOL;
        }
        else if (optype == OP_GRA || optype == OP_LES || optype == OP_GRAEQ || optype == OP_LESEQ) {
            // 二元运算符>,<,>=,<=，操作数int，结果bool
            if (this->child->type->type != this->child->brother->type->type || this->child->type->type != VALUE_INT) {
                cout << "Wrong type: need <int>, got <" << child->type->getTypeInfo()
                     << "> and <" << child->brother->type->getTypeInfo()
                     << ">, operator is " << opType2String(optype) << ", at line " << num_lines << endl;
                typeError = true;
            }
            this->type = TYPE_BOOL;
        }
        else if (optype == OP_AND || optype == OP_OR) {
            // 二元运算符&&,||，操作数bool
            if ((this->child->type->type != VALUE_BOOL && this->child->type->type != VALUE_INT) || (this->child->brother->type->type != VALUE_BOOL && this->child->brother->type->type !=VALUE_INT)){
                cout << "Wrong type: need <bool>, got <" << child->type->getTypeInfo()
                     << "> and <" << child->brother->type->getTypeInfo()
                     << ">, operator is " << opType2String(optype) << ", at line " << num_lines << endl;
                typeError = true;
            }
            this->type = TYPE_BOOL;
        }
        else if (optype == OP_INDEX) {
            // 二元运算符，输入int，输出左值类型，[]下标运算符
            if (this->child->brother->type->type != VALUE_INT) {
                cout << "Wrong type: need <int>, got <" << child->brother->type->getTypeInfo()
                     << ">, operator is " << opType2String(optype) << ", at line " << num_lines << endl;
                typeError = true;
            }
            this->type = this->child->type;
        }
        else {
            // 二元运算符，输入int，输出int，+,-,*,/,%
            if (this->child->type->type != this->child->brother->type->type || this->child->type->type != VALUE_INT) {
                cout << "Wrong type: need <int>, got <" << child->type->getTypeInfo()
                     << "> and <" << child->brother->type->getTypeInfo()
                     << ">, operator is " << opType2String(optype) << ", at line " << num_lines << endl;
                typeError = true;
            }
            this->type = TYPE_INT;
        }
        break;
    case NODE_PROG:
        this->type = TYPE_NONE;
        break;
    case NODE_VARLIST:
    case NODE_PARAM:
        if (this->child)
            this->type = this->child->type;
        break;
    default:
        break;
    }
    

}

void TreeNode::findReturn(vector<TreeNode *> &retList) { //找到所有return语句
    if (nodeType == NODE_STMT && stype == STMT_RETURN)
        retList.push_back(this);
    else {
        TreeNode *p = child;
        while (p) {
            p->findReturn(retList);
            p = p->brother;
        }
    }
}



void TreeNode::genCode() { //生成汇编代码
    TreeNode *p = child;
    TreeNode **q;
    int N = 0, n = 1, pSize = 0;
    string varCode = "";
    switch (nodeType)
    {
    case NODE_PROG:
        gen_var_list(); //生成根节点区域（全局变量）列表
        gen_str(); //检测并生成模式串
        cout << "\t.text" << endl;
        while (p) {  
            if (p->nodeType == NODE_STMT && p->stype == STMT_FUNCDECL)
                p->genCode();
            p = p->brother;
        }
        break;
    case NODE_FUNCALL: //函数调用
        if (p->var_name == "scanf"){
            string varCode = getVarPos(p->brother->child->child);
                cout << "\tleaq\t" << varCode << "%rsi" << endl
                    << "\tleaq\t" << ".LC0(%rip), %rdi" << endl
                    << "\tcall\t__isoc99_scanf@PLT" << endl;
        }else if(p->var_name == "printf"){
            if(p->brother->child->child->type->constvar){
                cout << "\tleaq\t$" << p->brother->child->child->int_val << ", %rsi" << endl
                    << "\tleaq\t" << ".LC1(%rip), %rdi" << endl
                    << "\tcall\tprintf@PLT" << endl;
            }else{
                p->brother->child->genCode();
                cout << "\tleaq\t" << "%rax" << ", %rsi" << endl
                    << "\tleaq\t" << ".LC1(%rip), %rdi" << endl
                    << "\tcall\tprintf@PLT" << endl;
            }
            
        }else{
            N = p->brother->getLength();

            q = new TreeNode *[N];  //为了从右向左压栈，存放反向的参数列表
            p = p->brother->child;
            while (p) {
                q[N - n++] = p;
                p = p->brother;
            }
            // 从右向左压栈
            for (int i = 0; i < N; i++) {
                q[i]->genCode();
                cout << "\tpushq\t%rax" << endl;
                pSize += this->child->type->paramType[i]->getSize();
            }
            // call和参数栈清理
            cout << "\tcall\t" << child->var_name << endl
                << "\taddq\t$" << pSize << ", %rsp" << endl;
        }
        break;
    case NODE_STMT: //语句
        switch (stype)
        {
        case STMT_FUNCDECL:  //函数声明
            cycleStackTop = -1;
            pFunction = this;
            get_list(); //
            cout << "\t.globl\t" << p->brother->var_name << endl
                 << "\t.type\t" << p->brother->var_name << ", @function" << endl
                 << p->brother->var_name << ":" << endl;
            gen_var_list(); //生成变量列表
            cout << "\tpushq\t%rbp" << endl
                 << "\tmovl\t%rsp, %rbp" << endl;
            // 在栈上分配局部变量
            cout << "\tsubq\t$" << -stackSize << ", %rsp" << endl;
            // 内部代码递归生成
            p->brother->brother->brother->genCode();
            // 产生返回标签代码
            cout << this->list.next_list << ":" << endl;
            // 清理局部变量栈空间
            cout << "\taddq\t$" << -stackSize << ", %rsp" << endl;
            cout << "\tpopq\t%ebp" << endl
                 << "\tret" << endl;
            pFunction = nullptr;
            break;
        case STMT_DECL:
        case STMT_CONSTDECL:
            p = p->brother->child;
            while (p) {
                if (p->nodeType == NODE_OP) {
                    p->child->brother->genCode();
                    cout << "\tmovl\t%rax, " << LocalVarList[p->child->var_scope + p->child->var_name] << "(%rbp)" << endl;
                }
                p = p->brother;
            }
            break;
        case STMT_IF:
            get_list();
            cout << list.begin_list << ":" << endl;
            this->child->genCode();
            cout << list.true_list << ":" << endl;
            this->child->brother->genCode();
            cout << list.false_list << ":" << endl;
            break;
        case STMT_IFELSE:
            get_list();
            cout << list.begin_list << ":" << endl;
            this->child->genCode();
            cout << list.true_list << ":" << endl;
            this->child->brother->genCode();
            cout << "\tjmp\t\t" << list.next_list << endl;
            cout << list.false_list << ":" << endl;
            this->child->brother->brother->genCode();
            cout << list.next_list << ":" << endl;
            break;
        case STMT_WHILE:
            get_list();
            cycleStack[++cycleStackTop] = this;
            cout << list.next_list << ":" << endl;
            this->child->genCode();
            cout << list.true_list << ":" << endl;
            this->child->brother->genCode();
            cout << "\tjmp\t\t" << list.next_list << endl;
            cout << list.false_list << ":" << endl;
            cycleStackTop--;
            break;
        case STMT_BREAK:
            cout << "\tjmp\t\t" << cycleStack[cycleStackTop]->list.false_list << endl;
            break;
        case STMT_CONTINUE:
            cout << "\tjmp\t\t" << cycleStack[cycleStackTop]->list.next_list << endl;
            break;
        case STMT_RETURN:
            if (p) {
                p->genCode();
            }
            cout << "\tjmp\t\t" << pFunction->list.next_list << endl;
            break;
        case STMT_BLOCK:
            while (p) {
                p->genCode();
                p = p->brother;
            }
            break;
        default:
            break;
        }
        break;
    case NODE_EXPR:
        if (child->nodeType == NODE_VAR) {
            // 内存变量（全局/局部）
            string varCode = getVarPos(this->child);
            cout << "\tmovl\t" << varCode << ", %rax" << endl;
        }
        else if (child->nodeType == NODE_OP && child->optype == OP_INDEX) {
            // 数组
            child->genCode();
        }
        else {
            cout << "\tmovl\t$" << child->getVal() << ", %rax" << endl;
        }
        break;
    case NODE_OP:
        switch (optype)
        {
        case OP_EQ:
            p->genCode();
            cout << "\tpushq\t%rax" << endl;
            p->brother->genCode();
            cout << "\tpopq\t%rbx" << endl
                 << "\tcmpq\t%rax, %rbx" << endl
                 << "\tsete\t%al" << endl;
            if (list.true_list != "") {
                cout << "\tje\t\t" << list.true_list << endl
                     << "\tjmp\t\t" << list.false_list << endl;
            }
            break;
        case OP_NEQ:
            p->genCode();
            cout << "\tpushq\t%rax" << endl;
            p->brother->genCode();
            cout << "\tpopq\t%rbx" << endl
                 << "\tcmpq\t%rax, %rbx" << endl
                 << "\tsetne\t%al" << endl;
            if (list.true_list != "") {
                cout << "\tjne\t\t" << list.true_list << endl
                     << "\tjmp\t\t" << list.false_list << endl;
            }
            break;
        case OP_GRA:
            p->genCode();
            cout << "\tpushq\t%rax" << endl;
            p->brother->genCode();
            cout << "\tpopq\t%rbx" << endl
                 << "\tcmpq\t%rax, %rbx" << endl
                 << "\tsetg\t%al" << endl;
            if (list.true_list != "") {
                cout << "\tjg\t\t" << list.true_list << endl
                     << "\tjmp\t\t" << list.false_list << endl;
            }
            break;
        case OP_LES:
            p->genCode();
            cout << "\tpushq\t%rax" << endl;
            p->brother->genCode();
            cout << "\tpopq\t%rbx" << endl
                 << "\tcmpq\t%rax, %rbx" << endl
                 << "\tsetl\t%al" << endl;
            if (list.true_list != "") {
                cout << "\tjl\t\t" << list.true_list << endl
                     << "\tjmp\t\t" << list.false_list << endl;
            }
            break;
        case OP_GRAEQ:
            p->genCode();
            cout << "\tpushq\t%rax" << endl;
            p->brother->genCode();
            cout << "\tpopq\t%rbx" << endl
                 << "\tcmpq\t%rax, %rbx" << endl
                 << "\tsetge\t%al" << endl;
            if (list.true_list != "") {
                cout << "\tjge\t\t" << list.true_list << endl
                     << "\tjmp\t\t" << list.false_list << endl;
            }
            break;
        case OP_LESEQ:
            p->genCode();
            cout << "\tpushq\t%rax" << endl;
            p->brother->genCode();
            cout << "\tpopq\t%rbx" << endl
                 << "\tcmpq\t%rax, %rbx" << endl
                 << "\tsetle\t%al" << endl;
            if (list.true_list != "") {
                cout << "\tjle\t\t" << list.true_list << endl
                     << "\tjmp\t\t" << list.false_list << endl;
            }
            break;
        case OP_NOT:
            get_list();
            p->genCode();
            cout << "\torq\t%rax, $0" << endl
                << "\tsete\t%al" << endl;
            break;
        case OP_AND:
            get_list();
            p->genCode();
            cout << "\tpushq\t%rax" << endl;
            cout << child->list.true_list << ":" << endl;
            p->brother->genCode();
            cout << "\tpopq\t%rbx" << endl
                 << "\tandq\t%rax, %rbx" << endl
                 << "\tsetne\t%al" << endl;
            break;
        case OP_OR:
            get_list();
            p->genCode();
            cout << "\tpushq\t%rax" << endl;
            cout << child->list.false_list << ":" << endl;
            p->brother->genCode();
            cout << "\tpopq\t%rbx" << endl
                 << "\torq\t%rax, %rbx" << endl
                 << "\tsetne\t%al" << endl;
            break;
        case OP_DECLASSIGN:
        case OP_ASSIGN:
            p->brother->genCode();
            if (p->nodeType == NODE_VAR)
                cout << "\tmovl\t%rax, " << getVarPos(p) << endl;
            else {  // 左值是数组
                cout << "\tpushq\t%rax" << endl;
                // 计算偏移量到%eax
                p->child->brother->genCode();
                cout << "\tpopq\t%rbx" << endl
                     << "\tmovl\t%rbx, " << getVarPos(p) << endl;
            }
            break;
        case OP_INC:
            varCode = getVarPos(p);
            cout << "\tmovl\t" << varCode << ", %rax" << endl
                 << "\tincq\t" << varCode << endl;
            break;
        case OP_DEC:
            varCode = getVarPos(p);
            cout << "\tmovl\t" << varCode << ", %rax" << endl
                 << "\tdecq\t" << varCode << endl;
            break;
        case OP_ADD:
            p->genCode();
            cout << "\tpushq\t%rax" << endl;
            p->brother->genCode();
            cout << "\tpopq\t%rbx" << endl;
            cout << "\taddq\t%rbx, %rax" << endl;
            break;
        case OP_SUB:
            p->genCode();
            cout << "\tpushq\t%rax" << endl;
            p->brother->genCode();
            cout << "\tmovl\t%rax, %rbx" << endl
                 << "\tpopq\t%rax" << endl
                 << "\tsubq\t%rbx, %rax" << endl;
            break;
        case OP_POS:
            p->genCode();
            break;
        case OP_NAG:
            p->genCode();
            cout << "\tnegq\t%rax" << endl;
            break;
        case OP_MUL:
            p->genCode();
            cout << "\tpushq\t%rax" << endl;
            p->brother->genCode();
            cout << "\tpopq\t%rbx" << endl;
            cout << "\timulq\t%rbx, %rax" << endl;
            break;
        case OP_DIV:
            p->genCode();
            cout << "\tpushq\t%rax" << endl;
            p->brother->genCode();
            cout << "\tmovl\t%rax, %rbx" << endl
                 << "\tpopq\t%rax" << endl
                 << "\tcltd" << endl
                 << "\tidivq\t%rbx" << endl;
            break;
        case OP_MOD:
            p->genCode();
            cout << "\tpushq\t%rax" << endl;
            p->brother->genCode();
            cout << "\tmovl\t%rax, %rbx" << endl
                 << "\tpopq\t%rax" << endl
                 << "\tcltd" << endl
                 << "\tidivq\t%rbx" << endl
                 << "\tmovl\t%rdx, %rax" << endl;
            break;
        case OP_INDEX:
            // 这里只生成下标运算在右值时的代码（即按下标取数值）
            p->brother->genCode();
            cout << "\tmovl\t" << getVarPos(this) << ", %rax" << endl;
            break;
        default:
            break;
        }
    default:
        break;
    }
}


void TreeNode::gen_var_list() {  //生成对应区域变量列表
    if (nodeType == NODE_PROG) {
        // 根节点下只处理全局变量声明
        TreeNode *p = child;
        bool print_data = false;
        while(p) {
            // 发现了p为定义语句，LeftChild为类型，RightChild为声明表
            if (p->stype == STMT_DECL || p->stype == STMT_CONSTDECL) {
                TreeNode* q = p->child->brother->child;
                // q为变量表语句，可能为标识符或者赋值声明运算符
                while (q) {
                    if (!print_data) {
                        // 第一次遇到全局变量的时候输出
                        print_data = true;
                        cout << "\t.text" << endl
                            << "\t.data" << endl
                            << "\t.align\t4" << endl;
                    }
                    TreeNode *t = q;
                    if (q->nodeType == NODE_OP && q->optype == OP_DECLASSIGN) {
                        t = q->child;
                    }
                    // 遍历常变量列表
                    int varsize = t->type->getSize();
                    if (t->type->dim > 0) {
                        t->type->elementType = p->child->type->type;
                        t->type->type = VALUE_ARRAY;
                        varsize = t->type->getSize();
                    }
                    cout << "\t.globl\t" << t->var_name << endl
                         << "\t.type\t" << t->var_name << ", @object" << endl
                         << "\t.size\t" << t->var_name << ", " << varsize << endl
                         << t->var_name << ":" << endl;
                    if (q->nodeType == NODE_OP && q->optype == OP_DECLASSIGN) {
                        // 声明时赋值
                        // 只处理字面量初始化值
                        if (t->type->dim == 0) {    // 单个值                    
                            cout << "\t.long\t" << t->brother->getVal() << endl;
                        }
                        else {    // 数组                    
                            for (TreeNode *pe = t->brother->child; pe != nullptr; pe = pe->brother)
                                cout << "\t.long\t" << 4 * pe->getVal() << endl;
                        }
                    }
                    else {
                        // 声明时未赋值，默认初始化值为0
                        // 只处理字面量初始化值
                        if (t->type->dim == 0) { // 单个值
                            cout << "\t.long\t0" << endl;
                        }
                        else {  // 数组
                            int size = 1;
                            for (unsigned int i = 0; i < t->type->dim; i++)
                                size *= t->type->dimSize[i];
                            cout << "\t.zero\t" << size << endl;
                        }
                    }
                    q = q->brother;
                }
            }
            p = p->brother;
        }
    }
    else if (nodeType == NODE_STMT && stype == STMT_FUNCDECL) {
        // 对于函数声明语句，递归查找局部变量声明
        LocalVarList.clear();
        stackSize = -12;
        int paramSize = 8;
        // 遍历参数定义列表
        TreeNode *p = child->brother->brother->child;
        while (p) {
            // 只能是基本数据类型，简便起见一律分配4字节
            LocalVarList[p->child->brother->var_scope + p->child->brother->var_name] = paramSize;
            paramSize += 4;
            p = p->brother;
        }
        // 遍历代码段，查找函数内声明的局部变量
        p = child->brother->brother->brother->child;
        while (p) {
            p->gen_var_list();
            p = p->brother;
        }
    }
    else if (nodeType == NODE_STMT && (stype == STMT_DECL || stype == STMT_CONSTDECL)) {
        // 找到了局部变量定义
        TreeNode* q = child->brother->child;
        while (q) {
            // 遍历常变量列表
            // q为标识符或声明赋值运算符
            TreeNode *t = q;
            // 声明时赋值
            if (q->nodeType == NODE_OP && q->optype == OP_DECLASSIGN)
                t = q->child;
            int varsize =t->type->getSize();
            if (t->type->dim > 0) {
                t->type->type = VALUE_ARRAY;
                varsize = t->type->getSize();
            }
            LocalVarList[t->var_scope + t->var_name] = stackSize;
            stackSize -= varsize;
            q = q->brother;
        }
    } 
    else {
        // 在函数定义语句块内部递归查找局部变量声明
        TreeNode *p = child;
        while (p) {
            p->gen_var_list();
            p = p->brother;
        }
    }
}

void TreeNode::gen_str() {  //检测是否出现scanf和printf，输出对应模式串
    static int strseq = 0;
    static bool print_rodata = false;
    static bool print_scanf = false;
    static bool print_printf = false;
    TreeNode *p = this->child;
    while (p) {
        if (p->nodeType == NODE_VAR && p->var_name == "scanf") {
            if (!print_rodata) {
                print_rodata = true;
                cout << "\t.section\t.rodata" << endl;
            }
            if (!print_scanf) {
                print_scanf = true;
                cout << ".LC0:" << endl
                        << "\t.string\t" << "\"" << "%d" << "\"" << endl;
            }
        } 
        else if (p->nodeType == NODE_VAR && p->var_name == "printf") {
            if (!print_rodata) {
                print_rodata = true;
                cout << "\t.section\t.rodata" << endl;
            }
            if (!print_printf) {
                print_printf = true;
                cout << ".LC1:" << endl
                        << "\t.string\t" << "\"" << "%d\\n" << "\"" << endl;
            }
        }
        else if (p->child) {
            p->gen_str();
        }
        p = p->brother;
    }
}


string TreeNode::new_list() {  //生成并返回新的基本块的标签（不断累加）
    static int list_seq = 0;
    string listStr = ".L";
    listStr += list_seq++;
    return listStr;
}

void TreeNode::get_list() {  //分配标签号
    string temp;
    switch (nodeType)
    {
    case NODE_STMT: //语句，串联相应语句的list链
        switch (stype)
        {
        case STMT_FUNCDECL:  //函数定义用函数名开头
            this->list.begin_list = this->child->brother->var_name;
            // next为return和局部变量清理
            this->list.next_list = ".LRET_" + this->child->brother->var_name;
            break;
        case STMT_IF:
            this->list.begin_list = new_list();
            this->list.true_list = new_list();
            this->list.false_list = this->list.next_list = new_list();
            this->child->list.true_list = this->list.true_list;
            this->child->list.false_list = this->list.false_list;
            break;
        case STMT_IFELSE:
            this->list.begin_list = new_list();
            this->list.true_list = new_list();
            this->list.false_list = new_list();
            this->list.next_list = new_list();
            this->child->list.true_list = this->list.true_list;
            this->child->list.false_list = this->list.false_list;
            break;
        case STMT_WHILE:
            this->list.begin_list = this->list.next_list = new_list();
            this->list.true_list = new_list();
            this->list.false_list = new_list();
            this->child->list.true_list = this->list.true_list;
            this->child->list.false_list = this->list.false_list;
            break;
        default:
            break;
        }
        break;
    case NODE_OP: //布尔表达式，串联相应的list链
        switch (optype)
        {
        case OP_AND:
            child->list.true_list = new_list();
            child->brother->list.true_list = list.true_list;
            child->list.false_list = child->brother->list.false_list = list.false_list;
            break;
        case OP_OR:
            child->list.true_list = child->brother->list.true_list = list.true_list;
            child->list.false_list = new_list();
            child->brother->list.false_list = list.false_list;
            break;
        case OP_NOT:
            child->list.true_list = list.false_list;
            child->list.false_list = list.true_list;
            break;
        default:
            break;
        }
        break;   
    default:
        break;
    }
}


string TreeNode::getVarPos(TreeNode* p) { //返回对应变量名的访问
    string varCode = "";
    if (p->nodeType == NODE_VAR) {
        // 标识符
        if (p->var_scope == "1") {
            // 全局变量
            varCode = p->var_name;
        }
        else {
            // 局部变量（不要跨定义域访问）
            varCode += LocalVarList[p->var_scope + p->var_name];
            varCode += "(%rbp)";                
        }
    }
    else {
        // 数组
        if (p->child->var_scope == "1") {
            varCode = p->child->var_name + "(,%rax,4)";
        }
        else {
            varCode += LocalVarList[p->child->var_scope + p->child->var_name];
            varCode += "(%rbp,%rax,4)";
        }
    }
    return varCode;
}

string TreeNode::nodeType2String (NodeType type){
    switch (type)
    {
    case NODE_CONST:
        return "<const>";
    case NODE_VAR:
        return "<var>";
    case NODE_EXPR:
        return "<expression>";
    case NODE_TYPE:
        return "<type>";
    case NODE_FUNCALL:
        return "function call";
    case NODE_STMT:
        return "<statment>";
    case NODE_PROG:
        return "<program>";
    case NODE_VARLIST:
        return "<variable list>";
    case NODE_PARAM:
        return "function format parameter";
    case NODE_OP:
        return "<operation>";
    default:
        return "<?>";
    }
}

string TreeNode::sType2String(StmtType type) {
    switch (type)
    {
    case STMT_SKIP:
        return "skip";
    case STMT_DECL:
        return "declaration";
    case STMT_CONSTDECL:
        return "const declaration";
    case STMT_FUNCDECL:
        return "function declaration";
    case STMT_BLOCK:
        return "block";
    case STMT_IF:
        return "if";
    case STMT_IFELSE:
        return "if with else";
    case STMT_WHILE:
        return "while";
    case STMT_RETURN:
        return "return";
    case STMT_CONTINUE:
        return "continue";
    case STMT_BREAK:
        return "break";
    default:
        return "?";
    }
}

string TreeNode::opType2String(OperatorType type) {
    switch (type)
    {
	case OP_EQ:
		return "equal";
	case OP_NEQ:
		return "not equal";
	case OP_GRAEQ:
		return "grater equal";
	case OP_LESEQ:
		return "less equal";
	case OP_ASSIGN:
		return "assign";
	case OP_DECLASSIGN:
		return "assign(decl)";
	case OP_GRA:
		return "grater";
	case OP_LES:
		return "less";
    case OP_INC:
        return "auto increment";
    case OP_DEC:
        return "auto decrement";
    case OP_ADD:
        return "add";
	case OP_SUB:
		return "sub";
	case OP_POS:
		return "positive";
	case OP_NAG:
		return "nagative";
	case OP_MUL:
		return "multiply";
	case OP_DIV:
		return "divide";
	case OP_MOD:
		return "Modulo";
	case OP_NOT:
		return "not";
	case OP_AND:
		return "and";
	case OP_OR:
        return "or";
    case OP_INDEX:
        return "index";
    default:
        return "?";
    }
}

void InitIONode() { //把scanf和printf添加到变量列表
    int k = 4;
    nodeScanf->num_lines = -1;
    nodeScanf->var_name = "scanf";
    nodeScanf->var_scope = "1";
    nodeScanf->type = new Type(COMPOSE_FUNCTION);
    nodeScanf->type->retType = TYPE_VOID;
    // nodeScanf->type->paramType[nodeScanf->type->paramNum++] = TYPE_STRING;
    // for (int i = 0; i < k;i++)
    //     nodeScanf->type->paramType[nodeScanf->type->paramNum++] = TYPE_INT;
    idNameList.insert(make_pair("scanf", "1"));
    idList[make_pair("scanf", "1")] = nodeScanf;
    nodePrintf->num_lines = -1;
    nodePrintf->var_name = "printf";
    nodePrintf->var_scope = "1";
    nodePrintf->type = new Type(COMPOSE_FUNCTION);
    nodePrintf->type->retType = TYPE_VOID;
    // nodePrintf->type->paramType[nodePrintf->type->paramNum++] = TYPE_STRING;
    // for (int i = 0; i < k;i++)
    //     nodePrintf->type->paramType[nodePrintf->type->paramNum++] = TYPE_INT;
    idNameList.insert(make_pair("printf", "1"));
    idList[make_pair("printf", "1")] = nodePrintf;
}
