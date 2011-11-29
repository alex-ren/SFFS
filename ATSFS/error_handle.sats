/* *************************
 * File name: error_handle.sats
 * Author: Zhiqiang Ren
 * Date: Nov 26, 2011
 * Description: Error Handling
** *************************/

abst@ype error_code (e: int) = int
typedef ecode (e: int) = error_code (e)
typedef ecode = [e: int] ecode (e)
#define is_succ ecode_is_succ

fun ecode_is_succ {e: int} (e: ecode (e)):<> bool (e == 0)

absviewtype resource

absview tag (n: int)
prfun tag_create (): tag 0
prfun tag_free (t: tag 0): void

viewdef tagdec (n:int) = (tag n) -<lin, prf> tag (n-1)

praxi tag_inc {n:int} (t: tag n): (tag (n+1), tagdec (n+1))

absview opt_tag (n: int, e: int)
viewdef optt (n: int, e: int) = opt_tag (n, e)

praxi optt_succ {n: nat} (pf: tag (n+1)):<prf> opt_tag (n, 0)
praxi optt_unsucc {n: nat} (pf: opt_tag (n, 0)):<prf> tag (n+1)

praxi optt_fail   {n: nat} {e:int| e <> 0} (pf: tag n):<prf> opt_tag (n, e)
praxi optt_unfail {n: nat} {e:int| e <> 0} (pf: opt_tag (n, e)):<prf> tag n
