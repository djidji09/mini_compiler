# mini_compiler
a mini compiler using flex + bison

# how to generate the files

## generate from the flex file (lexer)
```terminal
flex lang_f.l
```
## generate from the bison files (parser)
```terminal
bison -d lang_f.y
```
# compile everything into the program
```terminal
gcc lang_f.tab.c lex.yy.c -lfl -o myprogram
```
# run the program with the test files 
```terminal
./myprogram /test/...
```


