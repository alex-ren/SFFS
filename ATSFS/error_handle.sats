/* *************************
 * File name: error_handle.sats
 * Author: Zhiqiang Ren
 * Date: Nov 26, 2011
 * Description: Error Handling
** *************************/

absviewtype rollback_ele
absviewtype rollback (n: int)

fun rollback_create (): rollback (0)
fun rollback_pack {n:nat} (r1: rollback (n)): rollback_ele
fun rollback_add {n:nat}(rb: !rollback (n) >> rollback (n+1), re: rollback_ele): void
fun rollback_do {n:nat} (r: rollback (n)): int

// fun operation {n:nat}(pf: tag n | x: int): (tag (n+1) | (rollback (n+1), erase(n+1), b))

absviewtype opt_rollback (n: int, e: int) = rollback (n)
viewtypedef optrb (n: int, e: int) = opt_rollback (n, e)

praxi optrb_succ   {n: nat} (x: !(rollback (n+1)) >> optrb (n, 0)):<prf> void
praxi optrb_unsucc {n: nat} (x: !optrb (n, 0) >> rollback (n+1)):<prf> void
//
praxi optrb_fail   {n:nat} {e:int| e <> 0} (x: !(rollback (n)) >> optrb (n, e)):<prf> void
praxi optrb_unfail {n:nat} {e:int| e <> 0} (x: !optrb (n, e) >> rollback (n)):<prf> void
//

 
