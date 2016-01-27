module StringMap = Map.Make(String)

type bstmt =
  | Lit of int                  (* Integer Literal *)
  | Str of string               (* String Literal *)
  | Arg of string * bstmt
  | Reg of string
  | Bin of Ast.op               (* Binary Operators *)
  (*| Unop of Ast.unop          (* Unary Operators *)*)
  | Mov of string * bstmt       (* Mov instruction *)
  | Local_var of int            (* Local Variables, Relative Frame Pointer offset *)
  | Glob_var of string          (* Global Variables, by absolute label *)
  | Get_gvar of string          (* Gets Global Variables *)
  | Set_gvar of string          (* Sets Global Variables  *)
  | Call of string * int        (* Call function by name or address *)
  | Fdecl of string             (* Function Declaration *)
  | Imprt                       (* Import/Extern function *)
  | Prologue of string * int    (* Start of every stack frame *)
  | Epilogue                    (* End of every stack frame *)
  | Assign of bstmt * bstmt     (* Set variable *)
  | Ld_var of string            (* Load variable *)
  | Ld_reg of string            (* Load register into id *)
  | Ld_lit of int               (* Load lit into register *)
  | Str_var of string           (* Stores variable *)
  | Jmp_true of string          (* Jump if equal to zero *)
  | Jmp_false of string         (* Jump if not equal to zero*)
  | Jmp of string               (* Unconditional Jump to label *)
  | Label of string             (* Label for jumps *)
  | Header of string * string   (* Creates standard header *)
  | Tail of string * string list(* Creates a standard string *)
  | Arg_to_var of string * string
  | Fakenop
  | Ret of bstmt
;;

type prog = {
    num_globals : int;  (* Number of global variables *)
    text : bstmt array; (* Code for all the functions *)
  }

let explode s =
  let rec exp i l =
    if i < 0 then l 
    else
      let ch = s.[i] in
      exp (i - 1) (Char.code ch :: l)
  in
  exp (String.length s - 1) []
;;

let rec define_global acc = function
  | [] -> 
    if acc = 0 then "\n\t\tdb 00H, 00H, 00H, 00H\n" 
    else if (acc+1) mod 4 = 0 then "00H\n"
    else "00H, " ^ define_global (acc+1) []
  | hd :: tl -> 
    if acc = 0 then 
      "\n\t\tdb " ^ (Printf.sprintf "%02XH, " hd) ^ define_global (acc+1) tl
    else if acc = 7 then
      (Printf.sprintf "%02XH" hd) ^ define_global 0 tl
    else 
      (Printf.sprintf "%02XH, " hd) ^ define_global (acc+1) tl
;;


let unescape s =
    Scanf.sscanf ("\"" ^ s ^ "\"") "%S%!" (fun u -> u);;

let rec build_str kv_list =
  match kv_list with
    | []     -> ""
    | (k, v)::tl -> v ^ ":\t\t;\"" ^ k ^ "\"" ^
      (define_global 0 (explode (unescape k))) ^ (build_str tl)
;;

let rec string_of_stmt strlit_map blist =
  let to_string x = string_of_stmt strlit_map x in
  match blist with
  | Lit(x)            -> string_of_int x
  | Str(s)            -> (try StringMap.find s strlit_map with Not_found ->
                           raise (Failure ("Undeclared string " ^ s)))
  | Arg(lhs, rhs)     -> 
    (match rhs with 
    | Call(s, n) -> let suffix =
                      if n-6 > 0 then Printf.sprintf "\tadd rsp, %XH\n" ((n-6)*8)
                      else ""
                    in
                    "\tmov\t" ^ lhs ^ ", rax\nRHS:"^ (to_string rhs) ^ suffix
    | Str  s     -> Printf.sprintf "\tmov\t%s, %s\n" lhs (to_string rhs)
    | _          -> (try Printf.sprintf "\tmov\trax, %s\n\tmov\t[rsp+%XH], rax\n" 
                      (to_string rhs) (int_of_string lhs)
                      with Failure "int_of_string" -> 
                        "\tmov\t" ^ lhs ^ ", " ^ (to_string rhs) ^ "\n")
    )
  | Reg s             -> s
  | Bin(Ast.Add)      -> "\tadd\trax, rcx\n"
  | Bin(Ast.Sub)      -> "\tsub\trax, rcx\n"
  | Bin(Ast.Mult)     -> "\timul\trcx\n"
  | Bin(Ast.Div)      -> "\tcdq\n\tidiv\trcx\n"
  | Bin(Ast.Equal)    -> "\txor\trax, rcx\n\tcmp\trax, 0\n"
  | Bin(Ast.Neq)      -> "\tcmp\trax, rcx\n\tsetne\tdl\n\tcmp\tdl, 1\n"
  | Bin(Ast.Less)     -> "\tcmp\trax, rcx\n\tsetl\tdl\n\tcmp\tdl, 1\n"
  | Bin(Ast.Leq)      -> "\tcmp\trax, rcx\n" ^
                         "\tsetle dl\n" ^
                         "\tcmp\tdl, 1\n"
  | Bin(Ast.Greater)  -> "\tcmp\trax, rcx\n" ^
                         "\tsetg dl\n" ^
                         "\tcmp\tdl, 1\n"
  | Bin(Ast.Geq)      -> "\tcmp\trax, rcx\n" ^
                         "\tsetge dl\n" ^
                         "\tcmp\tdl, 1\n"
  | Mov(dst, src)     -> Printf.sprintf "\tmov\t%s, %s\n" dst (to_string src)
  | Ret(b)            -> 
    (match b with
    | Lit _ | Str _ 
    | Glob_var _ | Local_var _ -> "\tmov\trax, " ^ (to_string b) ^ "\n"
    | Call(_, _)               -> (to_string b)
    | Bin _                    -> (to_string b)
    | _                        -> ""
    )
  | Prologue(s, n)       -> 
      let offset = if n mod 16 = 0 then n+16 else n+24 in
      s ^ ":\n\tpush\trbp\n\tmov\trbp, rsp\n\tsub\trsp, " ^ 
      Printf.sprintf "%02XH\n" offset
  | Epilogue             -> "\tleave\n\tret\n"
  | Local_var(x)         -> Printf.sprintf "[rbp-%XH]" (abs x)
  | Arg_to_var(var, arg) -> "\tmov\t" ^ var ^ ", " ^ arg ^ "\n"
  | Glob_var(s)          -> "["^s^"]"
  | Set_gvar(s)          -> "\tmov\t" ^ s ^ ", rax\n"
  | Get_gvar(s)          -> "\tmov\trax, " ^ s ^ "\n"
  | Call(s, n)           -> let name = match s with 
                              | "listRemove"     -> "list_remove"
                              | "listConcat" -> "listConcate"
                              | _                 -> s
                            in 
                            "\tcall\t" ^ name ^ "\n"
  | Fdecl(s)             -> "global " ^ s ^ "\n"
  | Imprt                -> "extern fprintf\nextern fopen\n"
  | Assign(dst, src)     -> 
    (match src with
    | Call(s, n) -> (to_string dst)
    | Fakenop    -> (to_string dst)
    | _          -> "\tmov\trax, " ^ (to_string src)  ^ "\n" ^ (to_string dst)
    )
  | Jmp_true(lbl)     -> "\tjz " ^ lbl ^ "\n"
  | Jmp_false(lbl)    -> "\tjnz " ^ lbl ^ "\n"
  | Jmp(lbl)          -> "\tjmp " ^ lbl ^ "\n"
  | Label(lbl)        -> lbl ^ ":\n"
  | Ld_var(var)       -> "\tmov\trdx, rax\n\tmov\t" ^ var ^ ", rax\n"
  | Ld_reg(reg)       -> "\tmov\trax, " ^ reg ^ "\n"
  | Ld_lit(lit)       -> "\tmov\trax, " ^ (string_of_int lit) ^ "\n" 
  | Str_var(var)      -> "\tmov\tqword " ^ var ^", rax\n"
  | Header(s, extn)   -> s ^ extn ^
                         "extern stdout\n" ^
                         "\nSECTION .text\n"
  | Tail(s, g)        -> "\nSECTION .data\n" ^
                         (List.fold_left 
                           (fun s n -> 
                             Printf.sprintf "%s\n%s:\n\t\tdd 00000005H\n" s n) "" g) ^
                         "SECTION .bss\n" ^
                         "SECTION .rodata\n" ^
                         (build_str (StringMap.bindings strlit_map)) ^ "\n" ^ 
                         s ^ "\n"
  | Fakenop           -> ""
;;
