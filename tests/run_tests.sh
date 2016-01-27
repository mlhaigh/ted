#!/bin/sh

# Set time limit for all operations
ulimit -t 30

rm -rf /tests/*.rslt

SignalError() {
    if [ $error -eq 0 ]; then
	   echo "FAILED"
	   error=1
    fi
    echo "  $1"
}

# Compare <outfile> <reffile> <difffile>
Compare() {
    if diff -b "$1" "$2" 
    then echo "########## TEST SUCCESS $3 ##########" && rm -f $1
    else echo "########## TEST FAIL $1 differs from $2 ##########" 
    fi
}

Check() {
    error=0
    echo "########## Testing $1 ##########"
    cat $1.ted
    $(../src/ted $1.ted && nasm -f elf64 $1.asm && gcc $1.o -I../libparse -L../libparse -lm -lparse -o $1 && ./$1 > $1.rslt)
    if [ -f $1.rslt ]; then
      Compare $1.rslt $1.asrt $1
    else
      echo "########## TEST FAIL (COMPILATION ERROR) ##########"
    fi
#    rm -f ${reffile}.o
#    rm -f ${reffile}.asm
#    rm -f $reffile
}


if [ $# -ge 1 ]; then
    files=$@
else
    files=$(find . -name "*.ted" -exec basename \{} .ted \;)
fi

for file in $files; do
    case $file in
	*test-*)
	    Check $file
	    echo "Press enter to continue..." && read answer
	    ;;
    esac
done

