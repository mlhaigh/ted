open Ast
open Opcode

module StringMap = Map.Make(String)
module StringSet = Set.Make(String)

(* Symbol table: Information about all the names in scope *)
type env = {
  function_index : string StringMap.t; (* Index for each function *)
  global_index   : StringSet.t; (* "Address" for global variables *)
  local_index    : int StringMap.t; (* Frame pointer offset for args, locals *)
}

(* enum : int -> int -> ’a list -> (int * ’a) list
 * enum 1 2 [14,23,42] = [ (2,14), (3,23), (4,43) ] 
 *)
let rec enum stride n = function
    | []     -> []
    | hd::tl -> (n, hd) :: enum stride (n+stride) tl
;;

let string_map_pairs map pairs =
  List.fold_left (fun m (i, n) -> StringMap.add n i m) map pairs
;;

(* Translate a program in AST form into a bytecode program.  Throw an
 * exception if something is wrong, e.g., a reference to an unknown
 * variable or function *)
let translate (globals, functions) localfnameset =

  (* Allocate "addresses for each global variable" *)
  let global_indexes =
    List.fold_left
      (fun m x -> match x with Ast.Var(_, n, _) -> StringSet.add n m) 
      StringSet.empty globals
  in
  (* Assign indexes to built-in functions is special *)
  let rec string_map_create = function
    | []     -> StringMap.empty
    | (fn, fp)::tl -> StringMap.add fn fp (string_map_create tl)
  in
  let function_indexes = string_map_create ([
    ("print", "fprintf"); 
    ("open", "fopen");
    ("get", "get_title"); 
    ("find", "find"); 
    ("head", "head"); 
    ("addafter", "addafter"); 
    ("addbefore", "addbefore"); 
    ("remove", "remove");
    ("getdata", "getdata")] @ List.map (fun x -> (x.fname, x.fname)) functions) 
  in

  (* Translate a function in AST form into a list of bytecode statements *)
  let translate env fdecl =
    if not (StringSet.mem fdecl.fname localfnameset) then [Fakenop] else
    (* Bookkeeping: frame pointer offsets for locals and arguments *)
    let formal_strings = (List.map (fun x -> match x with Ast.Arg(_, s) -> s) fdecl.formals) in
    let local_offsets = (* -8 because we are in 64bit system *)
      enum (-8) (-8) (List.map (fun x -> match x with Ast.Var(_, s, _) -> s) fdecl.locals)
    and formal_offsets = (* +1 because of ret pointer *)
      enum (-8) (((List.length fdecl.locals)+1)*(-8)) formal_strings in
    let env = { env with local_index = string_map_pairs
      StringMap.empty (formal_offsets @ local_offsets) } in
    let unlist = function [x] -> x | _ -> Fakenop in
    let int_to_var = function
      | 1 -> "rdi"
      | 2 -> "rsi"
      | 3 -> "rdx"
      | 4 -> "rcx"
      | 5 -> "r8"
      | 6 -> "r9"
      | x -> if x > 6 then Printf.sprintf "%d" ((x-7))
             else Printf.sprintf "[rbp-%xH]" (abs x)
    in
    let rec to_arg acc hd =
      Arg((int_to_var (acc+1)), hd)
    in
    let rec expr = function
      | Literal i -> [Lit i]
      | Id s -> 
        (try [Local_var (StringMap.find s env.local_index)]
          with Not_found -> try [Glob_var (StringSet.find s env.global_index)]
          with Not_found -> raise (Failure ("undeclared variable " ^ s)))
      | Stringlit s    -> [Str s]
      | Binop (lhs, op, rhs) -> [Mov("rcx", unlist (expr rhs))] @ [Mov("rax", unlist (expr lhs))] @ [Bin op]
      | Assign (s, e) -> 
        let asn = 
          (try [Str_var (int_to_var (StringMap.find s env.local_index))]
            with Not_found -> try [Get_gvar (StringSet.find s env.global_index)]
            with Not_found -> raise (Failure ("undeclared variable" ^ s)))
        in
        (match e with
        | Call(fn, a)    -> (expr e) @ [Opcode.Assign(unlist asn, Call(fn, List.length a))]
        | Binop(_, _, _) -> (expr e) @ [Opcode.Assign(unlist asn, Fakenop)]
        | Stringlit(s)   -> [Opcode.Assign(unlist asn, Str s)]
        | _              -> [Opcode.Assign(unlist asn, unlist (expr e))]
        )
      | Call (fname, actuals) -> 
        (try (List.rev (List.mapi to_arg (List.concat (List.map expr actuals)))) @
          [Opcode.Call ((StringMap.find fname env.function_index), (List.length actuals))]
          with Not_found -> 
            StringMap.iter (fun k v -> Printf.printf "%s->%s\n" k v) env.function_index;
            Printf.printf "TESTING:%s\n" (StringMap.find fname env.function_index);
            raise (Failure ("undeclared function " ^ fname)))
      | Noexpr -> []
    in

    let rec stmt fnameb n = function
      | Block sl        -> List.concat (List.mapi (stmt fnameb) sl)
      | Expr e          -> expr e @ []
      | Return e        -> 
        (match e with
        | Binop(_, _, _) -> expr e
        | _              -> [Ret (unlist (expr e))]
        )
      | If(p, t, f) -> 
        let fnameb = fnameb ^ (string_of_int n) in
        let tblock = stmt (fnameb^"t") n t and fblock = stmt (fnameb^"f") n f in
        expr p @ [Jmp_true (fnameb ^ "t")] @ fblock @ [Jmp (fnameb^"bend")] @ 
        [Label (fnameb ^ "t")] @ tblock @ [Label (fnameb^"bend")]
      | While(e, b) ->
        let fnameb = fnameb ^ (string_of_int n) ^ "w" in
        let blk = stmt fnameb n b and cond = expr e in
        [Label fnameb] @ cond @ [Jmp_false (fnameb ^ "end")] @ blk @ 
        [Jmp (fnameb)] @ [Label (fnameb^"end")]
      | For(e1, e2, e3, b) ->
        stmt (fnameb ^ (string_of_int n) ^ "f") n 
        (Block([Expr(e1); While(e2, Block([b; Expr(e3)]))]))
    in
    let rec var_asn_list = function
      | []     -> []
      | Var(_, s, e)::tl ->
        (match e with
        | Noexpr -> var_asn_list tl
        | _     -> (Expr (Ast.Assign(s, e))) :: var_asn_list tl
        )
    in
    let arg_to_var = 
        (try List.mapi (fun x arg -> Arg_to_var(int_to_var (StringMap.find arg env.local_index), (int_to_var (x+1)))) formal_strings
          with Not_found -> raise (Failure ("Undefined Problem")))
    in
    [Prologue(fdecl.fname, (((StringMap.cardinal env.local_index)+(List.length fdecl.formals))*8))] @ 
      (stmt fdecl.fname 0 (Block (var_asn_list fdecl.locals))) @ (arg_to_var) @
      (stmt fdecl.fname 0 (Block fdecl.body)) @ [Epilogue]
  in
  let env = {
    function_index = function_indexes;
    global_index = global_indexes;
    local_index = StringMap.empty}
  in

  let func_bodies = List.map (translate env) functions in

  { num_globals = List.length globals;
    (* Concatenate the compiled functions and replace the function
       indexes in Jsr statements with PC values *)
    text = Array.of_list (
      List.map (
        function
          (*| Jsr i when i > 0 -> Jsr func_offset.(i)*)
          | _ as s -> s) (List.concat func_bodies)
    )
  }

