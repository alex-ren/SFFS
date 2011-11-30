
/* *************************
 * File name: error_handle.dats
 * Author: Zhiqiang Ren
 * Date: Nov 28, 2011
 * Description: error handling
** *************************/

staload "error_handle.sats"



absviewtype resource

extern fun operation2_1 {n:nat} (pf: tag n 
  | x: !resource,
  e: &ecode? >> ecode (e))
  :<1> #[e: int] (
  opt_tag (n, e) 
  | option_vt (
      rollback_res1 (resource, n+1), e == 0)
  )

extern fun operation2_2 {n:nat} (pf: tag n 
  | x: !resource,
  e: &ecode? >> ecode (e))
  :<1> #[e: int] (
  opt_tag (n, e) 
  | option_vt (
      rollback_res1 (resource, n+1), e == 0)
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

    


