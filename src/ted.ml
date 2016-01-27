open Opcode
open Ast
module StringMap = Map.Make(String)
module StringSet = Set.Make(String)

let _ =
  (* Reading File or stdin(put) *)
  let rec file_in =
    if Array.length Sys.argv > 1 then
      (try
        open_in Sys.argv.(1)
      with e-> 
        Printf.printf "Error Opening File %s\n" Sys.argv.(1);
        raise e;
      )
    else 
      stdin
  in 
  (* Creates output file or print to stdout *)
  let file_out =
    if Array.length Sys.argv > 1 then
      open_out ((String.sub (Sys.argv.(1)) 0 (String.index Sys.argv.(1)
      '.'))^".asm")
    else
      stdout
  in
  (* Lexing *)
  let lexbuf = Lexing.from_channel file_in in
  (* AST Building *)
  let ast = Parser.program Scanner.token lexbuf in
  let prgglob (var, fdecl) = 
    List.map (fun x -> match x with Var(_, n, _) -> n) var 
  in
  let externfunc = 
      {ftype   = Int;
       fname   = "print"; 
       formals =
         Arg(File, "stream")::Arg(String, "format")::Arg(Any, "vararg")::[];
       locals  = [];
       body    = [];
      }::{
       ftype   = File;
       fname   = "open";
       formals = Arg(String, "file")::Arg(String, "attr")::[];
       locals  = [];
       body    = []
      }::{
       ftype   = List;
       fname   = "listNew";
       formals = [];
       locals  = [];
       body    = []
      }::{
       ftype   = Any;
       fname   = "listHead";
       formals = Arg(List, "list")::[];
       locals  = [];
       body    = [];
      }::{
       ftype   = Any;
       fname   = "listAddLast";
       formals = Arg(List, "list")::Arg(Any, "data")::[];
       locals  = [];
       body    = [];
      }::{
       ftype   = Any;
       fname   = "listAddAfter";
       formals = Arg(List, "list")::Arg(Any, "data")::[];
       locals  = [];
       body    = [];
      }::{
       ftype   = Any;
       fname   = "listSet";
       formals = Arg(List, "list")::Arg(Any, "data")::[];
       locals  = [];
       body    = [];
      }::{
       ftype   = Any;
       fname   = "listRemove";
       formals = Arg(List, "list")::Arg(Int, "index")::[];
       locals  = [];
       body    = [];
      }::{
       ftype   = List;
       fname   = "listTail";
       formals = Arg(List, "list")::[];
       locals  = [];
       body    = [];
      }::{
       ftype   = List;
       fname   = "listConcat";
       formals = Arg(List, "list1")::Arg(List, "list2")::[];
       locals  = [];
       body    = []
      }::{
       ftype   = Page;
       fname   = "pageFetch";
       formals = Arg(String, "url")::[];
       locals  = [];
       body    = []
      }::{
       ftype   = String;
       fname   = "pageURL";
       formals = Arg(Page, "page")::[];
       locals  = [];
       body    = []
      }::{
       ftype   = String;
       fname   = "pageHTML";
       formals = Arg(Page, "page")::[];
       locals  = [];
       body    = []
      }::{
       ftype   = Element;
       fname   = "pageRoot";
       formals = Arg(Page, "page")::[];
       locals  = [];
       body    = []
      }::{
       ftype   = List;
       fname   = "pageFind";
       formals = Arg(Page, "page")::Arg(String, "selector")::[];
       locals  = [];
       body    = []
      }::{
        ftype = String;
        fname = "elementAttr";
        formals = Arg(Element, "element")::Arg(String, "selector")::[];
        locals = [];
        body = []
      }::{
        ftype = String;
        fname = "elementText";
        formals = Arg(Element, "element")::[];
        locals = [];
        body = []
      }::{
        ftype = String;
        fname = "elementType";
        formals = Arg(Element, "element")::[];
        locals = [];
        body = []
      }::{
        ftype = List;
        fname = "elementChildren";
        formals = Arg(Page, "page")::Arg(Element, "element")::[];
        locals = [];
        body = [];
      }::[]
  in
  let externfset = 
      List.fold_left 
        (fun set x -> x.fname::set) [] externfunc
  in
  let globals = prgglob ast in
  let complete_ast (var, fdecl) =
    let newvar = [Var(File, "stdout", Noexpr)] in
    (newvar@var, externfunc@fdecl)
  in
  let localfnameset (var, fdecl) =
    List.fold_left (fun m fd -> StringSet.add fd.fname m) StringSet.empty fdecl
  in
  let fnameset = localfnameset ast in
  let ast = complete_ast ast in
  (* SAST Building *)
  let sast (var, fdecl) = 
    let fnamemap = List.fold_left 
      (fun m func -> StringMap.add func.fname func.ftype m) 
      StringMap.empty fdecl
    in
    let sc_fdecl fd = 
      let varmap = 
        List.fold_left (fun m x -> match x with Ast.Var(t, n, _) -> StringMap.add n t m) 
        StringMap.empty (fd.locals@var)
      in
      let argmap = 
        List.fold_left (fun m x -> match x with Ast.Arg(t, n) -> StringMap.add n t m)
        StringMap.empty (fd.formals)
      in
      let rec sc_expr = function
        | Literal s         -> Int
        | Id s              -> (try StringMap.find s varmap 
                                 with Not_found -> try StringMap.find s argmap
                                 with Not_found -> try StringMap.find s fnamemap
                                 with Not_found -> raise (Failure ("Can't find ID")))
        | Stringlit s       -> String
        | Binop(lhs,op,rhs) -> let isvalid e =
                                 (match sc_expr e with
                                 | Int -> Int
                                 | _ -> raise (Failure ("Binop type mismatch")))
                               in
                               ignore (isvalid lhs);
                               ignore (isvalid rhs);
                               Int
        | Assign(v, e)      -> let vtype = StringMap.find v varmap in
                               let expr = sc_expr e in
                               if vtype = expr || expr = Any then vtype
                               else raise (Failure ("Type Mismatch"))
        | Call(s, e)        -> let rec matching lst1 lst2 =
                                 let hd = function
                                   | [] -> Nil
                                   | (Td t)::_ -> t
                                   | (Te t)::_ -> sc_expr t
                                 in
                                 let hd1 = hd lst1 and hd2 = hd lst2 in
                                 if hd2 != Any then (
                                 if hd1 != hd2 then raise (Failure ("Type Mismatch"))
                                 else if lst1 != [] then 
                                   matching (List.tl lst1) (List.tl lst2)
                                 else StringMap.find s fnamemap)
                                 else StringMap.find s fnamemap
                               in
                               let rec flist = function
                                 | [] -> []
                                 | hd::tl -> if s = hd.fname then hd.formals else flist tl
                               in
                               let encaps lst = 
                                 List.map (fun x -> match x with 
                                   | Literal _    | Id _         | Stringlit _ 
                                   | Binop(_,_,_) | Assign(_, _) | Call _
                                   | Noexpr -> Te x
                                   ) lst
                               in
                               matching (encaps e) (
                                 List.map (fun x -> match x with
                                   | Arg(t, _) -> Td t) (flist fdecl))
        | Noexpr            -> Nil
      in
      let rec sc_stmt = function
        | Block stmt_list   -> List.iter sc_stmt stmt_list
        | Expr e            -> ignore (sc_expr e)
        | Return e          -> if fd.ftype != (sc_expr e) then
                               raise (Failure ("Binop type mismatch"))
        | If (p, tb, fb)    -> if (sc_expr p) != Int then 
                                 raise (Failure ("Type Mismatch")) 
                               else
                               (sc_stmt tb);
                               (sc_stmt tb);
        | For(e1, e2, e3,s) -> ignore (sc_expr e1);
                               ignore (sc_expr e2);
                               ignore (sc_expr e3);
                               sc_stmt s;
        | While(e, s)       -> if sc_expr e != Int then raise (Failure ("Type Mismatch")) else 
                               sc_stmt s
      in
      let sc_var = function 
        | Var(t, _, e) -> 
          if e != Noexpr && t != (sc_expr e) && (sc_expr e) != Any then 
            raise (Failure ("Variable type mismatch"))
      in
      List.iter sc_var fd.locals;
      List.iter sc_stmt fd.body
    in
    List.iter sc_fdecl fdecl
  in
  sast ast;
  let program = ast in
  (* Creates an array of correlating bstmts(opcode.ml) *)
  let prg = (Compile.translate program fnameset).text in
  (* Creates the stringmap for string literals *)
  let stringlit = 
    let add_string str n map =
      if StringMap.mem str map then map 
      else StringMap.add str ("Str" ^ (string_of_int n)) map
    in
    let rec filter_strings n = function
      | []     -> StringMap.empty
      | hd::tl -> 
        (match hd with
        | Opcode.Str s | Opcode.Arg(_, Opcode.Str s)
        | Opcode.Arg(_, (Opcode.Arg(_, Opcode.Str s))) 
        | Opcode.Assign(_, Opcode.Str s) -> 
          add_string s n (filter_strings (n+1) tl)
        | _   -> filter_strings (n) tl
        )
    in
    filter_strings 0 (Array.to_list prg)
  in
  (*StringMap.iter (fun k v -> Printf.printf "%s->%s\n" k v) stringlit;*)
  (* Transfroms array into a list *)
  let prg_ops = Array.to_list prg in
  let rec makeheader = function
    | [] -> ""
    | hd :: tl -> (* Looks for functions *)
      (match hd with
        | Opcode.Prologue(s, _) ->
          (match s with
            | "fprintf" -> makeheader tl
            | "fopen"   -> makeheader tl
            | s         -> Printf.sprintf "%sglobal %s\n" (makeheader tl) s )
        | _ -> makeheader tl
      )
  in
  let full_prg = 
      [Opcode.Header
        ((List.fold_left (fun s n -> Printf.sprintf "%sglobal %s\n" s n)
          (makeheader prg_ops) globals),
        (List.fold_left (fun s n ->
          let fn = match n with
            | "print"      -> "fprintf" 
            | "open"       -> "fopen"
            | "listRemove" -> "list_remove"
            | "listConcat" -> "listConcate"
            | n            -> n
          in
          Printf.sprintf "%sextern %s\n" s fn) "\n" externfset))] 
      @ prg_ops @ [Opcode.Tail ("", globals)]
        in
  List.iter 
    (fun x -> Printf.fprintf file_out "%s" x) 
    (List.map (Opcode.string_of_stmt stringlit) full_prg)

