.PHONY: default
default: ted

ted: scanner.ml parser ast parser.cmo opcode.cmo compile.cmo ted.cmo
	ocamlc -o ted parser.cmo scanner.cmo opcode.cmo compile.cmo ted.cmo

ted.cmo: ted.ml
	ocamlc -c ted.ml

parser.cmo: parser.mli
	ocamlc -c parser.mli
	ocamlc -c scanner.ml
	ocamlc -c parser.ml

opcode.cmo: opcode.ml
	ocamlc -c opcode.ml

compile.cmo: compile.ml
	ocamlc -c compile.ml

parser.ml: parser.mly
	ocamlyacc parser.mly

ast:
	ocamlc -c ast.mli

parser:
	ocamlyacc parser.mly

scanner.ml: scanner.mll
	ocamllex scanner.mll

.PHONY: clean
clean:
	rm -f *.cmo *.cmi *.o *.asm ted scanner.ml parser.mli parser.ml
	rm -f ../tests/*rslt ../tests/*.asm ../tests/*.o && rm -f `find ../tests/ -type f -executable ! -name "*.sh" -print`

clean-tests:
	rm -f ../tests/*rslt ../tests/*.asm ../tests/*.o && rm -f `find ../tests/ -type f -executable ! -name "*.sh" -print`

tests: ted
	echo -n "\n"
	cd ../tests/ && ./run_tests.sh && cd -

.PHONY: all
all: clean default
