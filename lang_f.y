%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

extern int line;
extern int column;
extern FILE* yyin;
extern int yylex(void);
void yyerror(const char *msg);
%}

%union {
    int integer;
    float real;
    char* str;
    int boolean;
}

%{
/* Symbol Table Structure */
typedef struct
{
    char EntityName[20];
    char EntityCode[20];
    char TypeEntity[20];
    int is_const;
    int declared_line;
} TypeTS;

TypeTS ts[100];
int CpTabSym = 0;
int error_count = 0;

/* Current type for declarations */
char current_decl_type[20] = "";

/* Function Prototypes */
int search(char entity[]);
void printS();
const char* get_identifier_type(const char* name);
void check_type_compatibility(const char* type1, const char* type2, const char* operation);
void check_assignment_compatibility(const char* var_name, const char* expr_type);
%}

%token BEGIN_PROG END_PROG
%token INT_TOK FLOAT_TOK BOOL_TOK CONST_TOK
%token FOR_TOK IF_TOK ELSE_TOK
%token TRUE_TOK FALSE_TOK
%token IDF
%token INT_CONST_TOK REAL_CONST_TOK
%token ASSIGN EQUALS SEMI COMMA LPAREN RPAREN LBRACE RBRACE
%token ADD SUB MUL DIV
%token LT LE GT GE EQ NE
%token INCREMENT DECREMENT

%type <str> IDF type
%type <integer> INT_CONST_TOK
%type <real> REAL_CONST_TOK
%type <str> const_value expr condition

%left ADD SUB
%left MUL DIV
%nonassoc LT LE GT GE EQ NE
%right UMINUS

%%

program:
    decls BEGIN_PROG instrs END_PROG { 
        printf("\n=== COMPILATION FINISHED ===\n");
        printS();
        if (error_count == 0) {
            printf("Compilation completed successfully!\n"); 
        } else {
            printf("Compilation completed with %d error(s)\n", error_count); 
        }
        YYACCEPT;
    }
    ;

decls:
    /* empty */
    | decls decl
    | decls error SEMI  /* Error recovery for declarations */
    ;

decl:
    simple_decl SEMI
    | const_decl SEMI
    /* Detect missing semicolon */
    | simple_decl {
        fprintf(stderr, "Syntax error at line %d, column %d: Missing semicolon after declaration\n", 
                line, column);
        error_count++;
    }
    | const_decl {
        fprintf(stderr, "Syntax error at line %d, column %d: Missing semicolon after constant declaration\n", 
                line, column);
        error_count++;
    }
    ;

simple_decl:
    type ids
    ;

ids:
    IDF {
        if (search($1) == -1) {
            strcpy(ts[CpTabSym].EntityName, $1);
            strcpy(ts[CpTabSym].EntityCode, "idf");
            strcpy(ts[CpTabSym].TypeEntity, current_decl_type);
            ts[CpTabSym].is_const = 0;
            ts[CpTabSym].declared_line = line;
            CpTabSym++;
        } else {
            fprintf(stderr, "Semantic error at line %d, column %d: Identifier '%s' already declared\n", 
                    line, column, $1);
            error_count++;
        }
        free($1);
    }
    | ids COMMA IDF {
        if (search($3) == -1) {
            strcpy(ts[CpTabSym].EntityName, $3);
            strcpy(ts[CpTabSym].EntityCode, "idf");
            strcpy(ts[CpTabSym].TypeEntity, current_decl_type);
            ts[CpTabSym].is_const = 0;
            ts[CpTabSym].declared_line = line;
            CpTabSym++;
        } else {
            fprintf(stderr, "Semantic error at line %d, column %d: Identifier '%s' already declared\n", 
                    line, column, $3);
            error_count++;
        }
        free($3);
    }
    /* Catch trailing comma errors */
    | ids COMMA {
        fprintf(stderr, "Syntax error at line %d, column %d: Trailing comma in declaration\n", 
                line, column);
        error_count++;
    }
    /* Catch double comma errors */
    | ids COMMA COMMA {
        fprintf(stderr, "Syntax error at line %d, column %d: Multiple consecutive commas in declaration\n", 
                line, column);
        error_count++;
    }
    /* Catch leading comma errors */
    | COMMA IDF {
        fprintf(stderr, "Syntax error at line %d, column %d: Leading comma in declaration\n", 
                line, column);
        error_count++;
        free($2);
    }
    ;

const_decl:
    CONST_TOK type IDF EQUALS const_value {
        if (search($3) == -1) {
            strcpy(ts[CpTabSym].EntityName, $3);
            strcpy(ts[CpTabSym].EntityCode, "idf");
            strcpy(ts[CpTabSym].TypeEntity, $2);
            ts[CpTabSym].is_const = 1;
            ts[CpTabSym].declared_line = line;
            CpTabSym++;
        } else {
            fprintf(stderr, "Semantic error at line %d, column %d: Identifier '%s' already declared\n", 
                    line, column, $3);
            error_count++;
        }
        free($3);
    }
    ;

type:
    INT_TOK { $$ = "INT"; strcpy(current_decl_type, "INT"); }
    | FLOAT_TOK { $$ = "FLOAT"; strcpy(current_decl_type, "FLOAT"); }
    | BOOL_TOK { $$ = "BOOL"; strcpy(current_decl_type, "BOOL"); }
    ;

const_value:
    INT_CONST_TOK { $$ = "INT"; }
    | REAL_CONST_TOK { $$ = "FLOAT"; }
    | TRUE_TOK { $$ = "BOOL"; }
    | FALSE_TOK { $$ = "BOOL"; }
    | SUB INT_CONST_TOK { $$ = "INT"; }
    | ADD INT_CONST_TOK { $$ = "INT"; }
    | SUB REAL_CONST_TOK { $$ = "FLOAT"; }
    | ADD REAL_CONST_TOK { $$ = "FLOAT"; }
    ;

instrs:
    /* empty */
    | instrs instr
    | instrs error SEMI  /* Error recovery for instructions */
    ;

instr:
    assign_instr SEMI
    | increment_decrement SEMI
    | if_instr
    | for_instr
    /* Detect missing semicolon after assignment */
    | assign_instr {
        fprintf(stderr, "Syntax error at line %d, column %d: Missing semicolon after assignment\n", 
                line, column);
        error_count++;
    }
    | increment_decrement {
        fprintf(stderr, "Syntax error at line %d, column %d: Missing semicolon after increment/decrement\n", 
                line, column);
        error_count++;
    }
    ;

assign_instr:
    IDF ASSIGN expr {
        int pos = search($1);
        if (pos == -1) {
            fprintf(stderr, "Semantic error at line %d, column %d: Identifier '%s' not declared\n", 
                    line, column, $1);
            error_count++;
        } else if (ts[pos].is_const) {
            fprintf(stderr, "Semantic error at line %d, column %d: Cannot assign to constant '%s'\n", 
                    line, column, $1);
            error_count++;
        } else {
            check_assignment_compatibility($1, $3);
        }
        free($1);
    }
    /* Error in assignment */
    | IDF ASSIGN error {
        fprintf(stderr, "Syntax error at line %d, column %d: Invalid expression in assignment\n", 
                line, column);
        error_count++;
    }
    ;

increment_decrement:
    IDF INCREMENT {
        int pos = search($1);
        if (pos == -1) {
            fprintf(stderr, "Semantic error at line %d, column %d: Identifier '%s' not declared\n", 
                    line, column, $1);
            error_count++;
        } else if (ts[pos].is_const) {
            fprintf(stderr, "Semantic error at line %d, column %d: Cannot modify constant '%s'\n", 
                    line, column, $1);
            error_count++;
        } else if (strcmp(ts[pos].TypeEntity, "INT") != 0) {
            fprintf(stderr, "Semantic error at line %d, column %d: Increment only works on INT variables\n", 
                    line, column, $1);
            error_count++;
        }
        free($1);
    }
    | IDF DECREMENT {
        int pos = search($1);
        if (pos == -1) {
            fprintf(stderr, "Semantic error at line %d, column %d: Identifier '%s' not declared\n", 
                    line, column, $1);
            error_count++;
        } else if (ts[pos].is_const) {
            fprintf(stderr, "Semantic error at line %d, column %d: Cannot modify constant '%s'\n", 
                    line, column, $1);
            error_count++;
        } else if (strcmp(ts[pos].TypeEntity, "INT") != 0) {
            fprintf(stderr, "Semantic error at line %d, column %d: Decrement only works on INT variables\n", 
                    line, column, $1);
            error_count++;
        }
        free($1);
    }
    ;

if_instr:
    IF_TOK LPAREN condition RPAREN LBRACE instrs RBRACE SEMI
    | IF_TOK LPAREN condition RPAREN LBRACE instrs RBRACE {
        fprintf(stderr, "Syntax error at line %d, column %d: Missing semicolon after if statement\n", 
                line, column);
        error_count++;
    }
    | IF_TOK LPAREN condition RPAREN LBRACE instrs RBRACE ELSE_TOK LBRACE instrs RBRACE SEMI
    | IF_TOK LPAREN condition RPAREN LBRACE instrs RBRACE ELSE_TOK LBRACE instrs RBRACE {
        fprintf(stderr, "Syntax error at line %d, column %d: Missing semicolon after if-else statement\n", 
                line, column);
        error_count++;
    }
    /* Catch if with just semicolon */
    | IF_TOK LPAREN condition RPAREN SEMI {
        fprintf(stderr, "Syntax error at line %d, column %d: If statement must have a body\n", 
                line, column);
        error_count++;
    }
    ;

for_instr:
    FOR_TOK LPAREN assign_instr_no_semi SEMI condition SEMI assign_instr_no_semi RPAREN LBRACE instrs RBRACE SEMI
    | FOR_TOK LPAREN assign_instr_no_semi SEMI condition SEMI assign_instr_no_semi RPAREN LBRACE instrs RBRACE {
        fprintf(stderr, "Syntax error at line %d, column %d: Missing semicolon after for statement\n", 
                line, column);
        error_count++;
    }
    ;

/* FIXED RULE: Now handles both assignment and increment/decrement */
assign_instr_no_semi:
    IDF ASSIGN expr {
        int pos = search($1);
        if (pos == -1) {
            fprintf(stderr, "Semantic error at line %d, column %d: Identifier '%s' not declared\n", 
                    line, column, $1);
            error_count++;
        } else if (ts[pos].is_const) {
            fprintf(stderr, "Semantic error at line %d, column %d: Cannot assign to constant '%s'\n", 
                    line, column, $1);
            error_count++;
        } else {
            check_assignment_compatibility($1, $3);
        }
        free($1);
    }
    /* ADDED: Handle increment in FOR loops */
    | IDF INCREMENT {
        int pos = search($1);
        if (pos == -1) {
            fprintf(stderr, "Semantic error at line %d, column %d: Identifier '%s' not declared\n", 
                    line, column, $1);
            error_count++;
        } else if (ts[pos].is_const) {
            fprintf(stderr, "Semantic error at line %d, column %d: Cannot modify constant '%s'\n", 
                    line, column, $1);
            error_count++;
        } else if (strcmp(ts[pos].TypeEntity, "INT") != 0) {
            fprintf(stderr, "Semantic error at line %d, column %d: Increment only works on INT variables\n", 
                    line, column, $1);
            error_count++;
        }
        free($1);
    }
    /* ADDED: Handle decrement in FOR loops */
    | IDF DECREMENT {
        int pos = search($1);
        if (pos == -1) {
            fprintf(stderr, "Semantic error at line %d, column %d: Identifier '%s' not declared\n", 
                    line, column, $1);
            error_count++;
        } else if (ts[pos].is_const) {
            fprintf(stderr, "Semantic error at line %d, column %d: Cannot modify constant '%s'\n", 
                    line, column, $1);
            error_count++;
        } else if (strcmp(ts[pos].TypeEntity, "INT") != 0) {
            fprintf(stderr, "Semantic error at line %d, column %d: Decrement only works on INT variables\n", 
                    line, column, $1);
            error_count++;
        }
        free($1);
    }
    ;

condition:
    expr LT expr { check_type_compatibility($1, $3, "comparison"); $$ = "BOOL"; }
    | expr LE expr { check_type_compatibility($1, $3, "comparison"); $$ = "BOOL"; }
    | expr GT expr { check_type_compatibility($1, $3, "comparison"); $$ = "BOOL"; }
    | expr GE expr { check_type_compatibility($1, $3, "comparison"); $$ = "BOOL"; }
    | expr EQ expr { check_type_compatibility($1, $3, "comparison"); $$ = "BOOL"; }
    | expr NE expr { check_type_compatibility($1, $3, "comparison"); $$ = "BOOL"; }
    ;

expr:
    expr ADD expr { 
        check_type_compatibility($1, $3, "addition");
        if (strcmp($1, "INT") == 0 && strcmp($3, "INT") == 0) $$ = "INT";
        else if (strcmp($1, "FLOAT") == 0 || strcmp($3, "FLOAT") == 0) $$ = "FLOAT";
        else $$ = "ERROR";
    }
    | expr SUB expr { 
        check_type_compatibility($1, $3, "subtraction");
        if (strcmp($1, "INT") == 0 && strcmp($3, "INT") == 0) $$ = "INT";
        else if (strcmp($1, "FLOAT") == 0 || strcmp($3, "FLOAT") == 0) $$ = "FLOAT";
        else $$ = "ERROR";
    }
    | expr MUL expr { 
        check_type_compatibility($1, $3, "multiplication");
		
        if (strcmp($1, "INT") == 0 && strcmp($3, "INT") == 0) $$ = "INT";
        else if (strcmp($1, "FLOAT") == 0 || strcmp($3, "FLOAT") == 0) $$ = "FLOAT";
        else $$ = "ERROR";
    }
    | expr DIV expr { 
        check_type_compatibility($1, $3, "division");
        if (strcmp($1, "INT") == 0 && strcmp($3, "INT") == 0) $$ = "INT";
        else if (strcmp($1, "FLOAT") == 0 || strcmp($3, "FLOAT") == 0) $$ = "FLOAT";
        else $$ = "ERROR";
    }
    /* SIMPLIFIED ERROR RULES - no conflicts */
    | error DIV error {
        fprintf(stderr, "Syntax error at line %d, column %d: Invalid expression with '/'\n", 
                line, column);
        error_count++;
        $$ = "ERROR";
    }
    | error ADD error {
        fprintf(stderr, "Syntax error at line %d, column %d: Invalid expression with '+'\n", 
                line, column);
        error_count++;
        $$ = "ERROR";
    }
    | error SUB error {
        fprintf(stderr, "Syntax error at line %d, column %d: Invalid expression with '-'\n", 
                line, column);
        error_count++;
        $$ = "ERROR";
    }
    | error MUL error {
        fprintf(stderr, "Syntax error at line %d, column %d: Invalid expression with '*'\n", 
                line, column);
        error_count++;
        $$ = "ERROR";
    }
    /* Add unary plus and minus */
    | ADD expr %prec UMINUS { 
        $$ = $2;
    }
    | SUB expr %prec UMINUS { 
        if (strcmp($2, "INT") == 0) $$ = "INT";
        else if (strcmp($2, "FLOAT") == 0) $$ = "FLOAT";
        else $$ = "ERROR";
    }
    | IDF { 
        if (search($1) == -1) {
            fprintf(stderr, "Semantic error at line %d, column %d: Identifier '%s' not declared\n", 
                    line, column, $1);
            error_count++;
            $$ = "ERROR";
        } else {
            $$ = (char*)get_identifier_type($1);
        }
        free($1);
    }
    | INT_CONST_TOK { $$ = "INT"; }
    | REAL_CONST_TOK { $$ = "FLOAT"; }
    | TRUE_TOK { $$ = "BOOL"; }
    | FALSE_TOK { $$ = "BOOL"; }
    | LPAREN expr RPAREN { $$ = $2; }
    | LPAREN error RPAREN {
        fprintf(stderr, "Syntax error at line %d, column %d: Invalid expression inside parentheses\n", 
                line, column);
        error_count++;
        $$ = "ERROR";
    }
    ;

%%

/* Keep all the helper functions exactly as before */
int search(char entity[])
{
    int i = 0;
    while(i < CpTabSym)
    {
        if (strcmp(entity, ts[i].EntityName) == 0) return i;
        i++;
    }
    return -1;
}

const char* get_identifier_type(const char* name) {
    int pos = search((char*)name);
    if (pos != -1) {
        return ts[pos].TypeEntity;
    }
    return "ERROR";
}

void check_type_compatibility(const char* type1, const char* type2, const char* operation) {
    if (strcmp(type1, "ERROR") == 0 || strcmp(type2, "ERROR") == 0) return;
    
    if (strcmp(operation, "addition") == 0 || 
        strcmp(operation, "subtraction") == 0 || 
        strcmp(operation, "multiplication") == 0 ||
        strcmp(operation, "division") == 0) {
        
        if ((strcmp(type1, "INT") == 0 || strcmp(type1, "FLOAT") == 0) &&
            (strcmp(type2, "INT") == 0 || strcmp(type2, "FLOAT") == 0)) {
            return;
        } else {
            fprintf(stderr, "Semantic error at line %d, column %d: Type mismatch in %s - cannot use type '%s' with '%s'\n",
                    line, column, operation, type1, type2);
            error_count++;
        }
    }
    else if (strcmp(operation, "comparison") == 0) {
        if (strcmp(type1, type2) != 0) {
            fprintf(stderr, "Semantic error at line %d, column %d: Type mismatch in comparison - cannot compare '%s' with '%s'\n",
                    line, column, type1, type2);
            error_count++;
        }
    }
}

void check_assignment_compatibility(const char* var_name, const char* expr_type) {
    if (strcmp(expr_type, "ERROR") == 0) return;
    
    const char* var_type = get_identifier_type(var_name);
    if (strcmp(var_type, "ERROR") == 0) return;
    
    if (strcmp(var_type, "BOOL") == 0) {
        if (strcmp(expr_type, "BOOL") != 0) {
            fprintf(stderr, "Semantic error at line %d, column %d: Cannot assign type '%s' to BOOL variable '%s'\n",
                    line, column, expr_type, var_name);
            error_count++;
        }
    }
    else if (strcmp(var_type, "INT") == 0) {
        if (strcmp(expr_type, "INT") != 0) {
            fprintf(stderr, "Semantic error at line %d, column %d: Cannot assign type '%s' to INT variable '%s'\n",
                    line, column, expr_type, var_name);
            error_count++;
        }
    }
    else if (strcmp(var_type, "FLOAT") == 0) {
        if (strcmp(expr_type, "FLOAT") != 0 && strcmp(expr_type, "INT") != 0) {
            fprintf(stderr, "Semantic error at line %d, column %d: Cannot assign type '%s' to FLOAT variable '%s'\n",
                    line, column, expr_type, var_name);
            error_count++;
        }
    }
}

void printS()
{
    if (CpTabSym == 0) {
        printf("\nSymbol table is empty\n");
        return;
    }
    
    printf("\n/*********** SYMBOL TABLE ***********/\n");
    printf("+--------------+-------------+---------+----------+------+\n");
    printf("| Entity Name  | Entity Code | Type    | Constant | Line |\n");
    printf("+--------------+-------------+---------+----------+------+\n");
    
    int i = 0;
    while(i < CpTabSym)
    {
        printf("| %-12s | %-11s | %-7s | %-8s | %-4d |\n", 
               ts[i].EntityName, 
               ts[i].EntityCode, 
               ts[i].TypeEntity,
               ts[i].is_const ? "Yes" : "No",
               ts[i].declared_line);
        i++;
    }
    
    printf("+--------------+-------------+---------+----------+------+\n");
    printf("Total entries: %d\n", CpTabSym);
}

void yyerror(const char* msg) {
    fprintf(stderr, "Syntax error at line %d, column %d: %s\n", line, column, msg);
    error_count++;
}

int main(int argc, char* argv[]) {
    error_count = 0;
    CpTabSym = 0;
    strcpy(current_decl_type, "");
    
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            fprintf(stderr, "Cannot open file %s\n", argv[1]);
            return 1;
        }
    } else {
        printf("Usage: compiler.exe source_file.txt\n");
        return 1;
    }
    
    yyparse();
    
    if (yyin != stdin) {
        fclose(yyin);
    }
    
    return (error_count > 0) ? 1 : 0;
}