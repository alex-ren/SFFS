

// ? rollback needs resource
// // assume single thread
// 
// staload "error_handle.sats"
// 
// abst@ype error_code (e: int) = int
// typedef ecode (e: int) = error_code (e)
// typedef ecode = [e: int] ecode (e)
// 
// extern fun ecode_is_succ {e: int} (e: ecode (e)):<> bool (e == 0)
// 
// #define is_succ ecode_is_succ
// 
// extern fun operation1_1 {n:nat} (x: int, 
//   rli: !rollback (n) >> optrb (n, e), 
//   e: & ecode? >> ecode (e)): #[e: int] void
// 
// extern fun operation1_2 {n:nat} (x: int, 
//   rli: !rollback (n) >> optrb (n, e), 
//   e: & ecode? >> ecode (e)): #[e: int] void
// 
// fun operation1 {n:nat} (x: int, 
//   rli: !rollback (n) >> optrb (n, e), 
//   e: & ecode? >> ecode (e)): #[e: int] void = let
// 
//   val rl = rollback_create ()
//   val () = operation1_1(23, rl, e)
// in
//   if is_succ (e) then let
//     val () = optrb_unsucc (rl)
//     val () = operation1_2(33, rl, e)
//   in
//     if is_succ (e) then let
//       val () = optrb_unsucc (rl)
//       val re = rollback_pack (rl)
//       val () = rollback_add (rli, re)
//       val () = optrb_succ (rli)
//     in
//       ()
//     end else let
//       val () = optrb_unfail (rl)
//       val r = rollback_do (rl)  // don't care error
//       val () = optrb_fail (rli)
//     in
//       ()
//     end
//   end else let
//     val () = optrb_unfail (rl)
//     val r = rollback_do (rl)  // don't care error
//     val () = optrb_fail (rli)
//   in
//     ()
//   end
// end
 
(* ********** ********** *)
abst@ype error_code (e: int) = int
typedef ecode (e: int) = error_code (e)
typedef ecode = [e: int] ecode (e)
#define is_succ ecode_is_succ

extern fun ecode_is_succ {e: int} (e: ecode (e)):<> bool (e == 0)

absviewtype resource

absview tag (n: int)
extern prfun tag_create (): tag 0
extern prfun tag_free (t: tag 0): void

viewdef tagdec (n:int) = (tag n) -<lin, prf> tag (n-1)

extern praxi tag_inc {n:int} (t: tag n): (tag (n+1), tagdec (n+1))

absview opt_tag (n: int, e: int)
viewdef optt (n: int, e: int) = opt_tag (n, e)

extern praxi optt_succ {n: nat} (pf: tag (n+1)):<prf> opt_tag (n, 0)
extern praxi optt_unsucc {n: nat} (pf: opt_tag (n, 0)):<prf> tag (n+1)

extern praxi optt_fail   {n: nat} {e:int| e <> 0} (pf: tag n):<prf> opt_tag (n, e)
extern praxi optt_unfail {n: nat} {e:int| e <> 0} (pf: opt_tag (n, e)):<prf> tag n


extern fun operation2_1 {n:nat} (pf: tag n 
  | x: !resource,
  e: &ecode? >> ecode (e))
  :<1> #[e: int] (
  opt_tag (n, e) 
  | option_vt (
      ((tag (n+1) | !resource) -<lin, cloptr1> (tag n | int)), e == 0)
  )

extern fun operation2_2 {n:nat} (pf: tag n 
  | x: !resource,
  e: &ecode? >> ecode (e))
  :<1> #[e: int] (
  opt_tag (n, e) 
  | option_vt (
      ((tag (n+1) | !resource) -<lin, cloptr1> (tag n | int)), e == 0)
  )


fun operation2 {n:nat} .<>. (vtag: tag n 
  | x: !resource,
  e: &ecode? >> ecode (e))
  :<1> #[e: int] (
  opt_tag (n, e) 
  | option_vt (
      ((tag (n+1) | !resource) -<lin, cloptr1> (tag n | int)), e == 0)
  ) = let
  prval vtag0 = tag_create ()
  val (opt_vtag1 | opt_f1) = operation2_1 (vtag0 | x, e)
in
  if is_succ (e) then let
    prval vtag1 = optt_unsucc (opt_vtag1)
    val ~Some_vt (vf1) = opt_f1
    val (opt_vtag2 | opt_f2) = operation2_2 (vtag1 | x, e)
  in
    if is_succ (e) then let
      prval vtag2 = optt_unsucc (opt_vtag2)
      val ~Some_vt (vf2) = opt_f2
      prval (vtag', fpf) = tag_inc{n} (vtag)
      prval opt_vtag' = optt_succ (vtag')

      // vtag2, vf1, vf2, fpf needs to be consumed
      val rollback = llam (pf:tag (n+1) | x: !resource) =<lin,cloptr1> (let
        val (vtag1 | ret) = vf2 (vtag2 | x)
        val () = cloptr_free (vf2)
        val (vtag0 | ret) = vf1 (vtag1 | x)
        val () = cloptr_free (vf1)
        prval () = tag_free (vtag0)
        
        prval pf' = fpf (pf)
      in
        (pf' | 1)
      end):(tag n | int) 
    in
      (opt_vtag' | Some_vt (rollback))
    end else let
      prval vtag1 = optt_unfail (opt_vtag2)
      val (vtag0 | ret) = vf1 (vtag1 | x)
      val () = cloptr_free (vf1)
      prval () = tag_free (vtag0)
      val ~None_vt () = opt_f2
    in
      (optt_fail (vtag) | None_vt ())
    end
  end else let
    prval vtag0 = optt_unfail (opt_vtag1)
    prval () = tag_free (vtag0)
    val ~None_vt () = opt_f1
  in
    (optt_fail (vtag) | None_vt ())
  end
end


fun foo (): void = let
  val ff0 = lam () =<fun> 1
  val x = ff0 ()
  val x = ff0 ()
  
  val ff1 = lam () =<lin,cloptr1> 1
  // cannot call ff1 () twice
  val x = ff1 ()
  // must free ff1
  val () = cloptr_free (ff1)
  val ff2 = lam () =<lin, fun> 1
  // cannot call ff2 () twice
  val x = ff2 ()

  // "lin" has no effect on function definition
  fn ff3 ():<lin> int = 1
  val x = ff3 ()
  val x = ff3 ()

  viewdef tagdec (n:int) = (tag n) -<lin, prf> tag (n-1)
  prfun foo .<>. ():<> void = let
    prval t = tag_create ()
    prval (t1, ft) = tag_inc (t)
    prval t = ft (t1)
    prval () = tag_free (t)
  in
  end

in end
      
extern fun abort {a: viewt@ype} (err: int):<!exn> a

    


