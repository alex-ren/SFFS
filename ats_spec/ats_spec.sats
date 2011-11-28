/* *************************
 * File name: ats_spec.sats
 * Author: Zhiqiang Ren
 * Date: 10/03/2011
 * Description: types and functions for specification in ATS
 * Refer to <<VDM-10 Language Manual>>
 * Refer to <<Validated Designes for Object-Oriented Systems>>
 * ************************/

(* ************** ****************** *)

// basic types

// abst@ype bool
// abst@ype nat

// how to deal with Quote Type?
// Used in scenario like file open mode, in which we need a limited number of entities
// type with only one element
// T = <France> | <Denmark> | <SouthAfrica>
// e.g. a = <France>
// a = <Denmar> is false

// token type
// may be used in scenario like user id, in which we only care about identity
abstype token
//constructor
fun {a: t@ype} token_make (x: a): token

// operation
fun token_eq (t1: token, t2: token): bool
fun token_neq (t1: token, t2: token): bool

(* ************** ****************** *)

// compound types

abstype set (a: t@ype)
abstype seq (a: t@ype)  // may be empty
abstype seq1 (a: t@ype)  // not empty
abstype map (a:t@ype, b: t@ype)
abstype inmap (a:t@ype, b: t@ype)  // injective map
abstype option (a: t@ype)
abstype option_vt (a: viewt@ype)

(* ************** ****************** *)

// Set
// Set construction
// refer to <<VDM-10 Language Manual>> P13

// Set enumeration
// {1, 2, 3, 5}

// Set comprehension
// {x * 3 | x in set {1, 2, 3, 4, 5}}
// {x * 3 | x: Nat & x < 10}

(* ************** ****************** *)

// Set operation
// refer to <<VDM-10 Language Manual>> P14

fun {a:t@ype} set_in (x: a, s: set a): bool

fun {a:t@ype} set_not_in (x: a, s: set a): bool

fun {a:t@ype} set_union (s1: set a, s2: set a): set a

// Intersection
fun {a:t@ype} set_inter (s1: set a, s2: set a): set a

// Difference
fun {a:t@ype} set_diff (s1: set a, s2: set a): set a

fun {a:t@ype} set_subset (s1: set a, s2: set a): bool

// proper subset
fun {a:t@ype} set_psubset (s1: set a, s2: set a): bool

fun {a:t@ype} set_eq (s1: set a, s2: set a): bool

fun {a:t@ype} set_neq (s1: set a, s2: set a): bool

// Cardinality
fun {a:t@ype} set_card (s1: set a, s2: set a): bool

// Distributed union
fun {a:t@ype} set_dunion (s: set (set a)): set a

// Distributed intersection
fun {a:t@ype} set_dinter (s: set (set a)): set a

// Finite power set
fun {a:t@ype} set_power (s: set a): set (set a)

(* ************** ****************** *)

// Sequence
// Sequence construction
// refer to <<VDM-10 Language Manual>> P15

// Sequence enumeration
// [1, 2, 4, 3]

// Sequence comprehension
// [3*x | x in set {1, 2, 4} & x > 1]

(* ************** ****************** *)

// Sequence operation
// refer to <<VDM-10 Language Manual>> P16

(* *************** ****************** *)
// add by Zhiqiang Ren
fun {a:t@ype} seq_update (s1: seq a, pos: int, c: a): seq a
fun {a:t@ype} seq_update_precond (s1: seq a, pos: int, c: a): bool
(*
  0 <= pos && pos < seq_len (s1) 
*)

fun {a:t@ype} seq_merge (s1: seq a, start: int, s2: seq a): seq a
fun {a:t@ype} seq_merge_precond (s1: seq a, start: int, s2: seq a): bool
(*
  0 <= start && start <= seq_len (s1) 
*)


fun {a:t@ype} seq_sub (s: seq a, start: int, len: int): seq a
fun {a:t@ype} seq_sub_precond (s: seq a, start: int, len: int): bool
(*
  0 <= start && (start + len) <= seq_len (s))
*)
(* *************** ****************** *)

fun {a:t@ype} seq1_hd (s: seq1 a): a

fun {a:t@ype} seq1_tl (s: seq1 a): seq a

fun {a:t@ype} seq_len (s: seq a): Nat

fun {a:t@ype} seq_elems (s: seq a): set a

// indexes
fun {a:t@ype} seq_inds (s: seq a): set Nat

// concatenation
fun {a:t@ype} seq_canc (s1: seq a, s2: seq a): seq a

// reverse
fun {a:t@ype} seq_reverse (s: seq a): seq a

// distributed concatenation
fun {a:t@ype} seq_disconc (s: seq (seq a)): seq a

// sequence modification
fun {a:t@ype} seq_map (s: seq a, m: map (Nat, a)): seq a

// sequence application
// n must be in the indexes of s
fun {a:t@ype} seq_app (s: seq a, n: Nat): a

fun {a:t@ype} seq_eq (s1: seq a, s2: seq a): bool

fun {a:t@ype} seq_neq (s1: seq a, s2: seq a): bool

(* ************** ****************** *)

// Map
// Map construction
// refer to <<VDM-10 Language Manual>> P18

// map enumeration
// {"JOhn" |-> 9, "Nico" |-> 8, "Peter" |-> 6}

// map comprehension
// {i |-> i*i | i: Nat & i <= 4}

(* ************** ****************** *)

// map operation
// refer to <<VDM-10 Language Manual>> P19

(* *************** ****************** *)
// add by Zhiqiang Ren
fun {a, b:t@ype} map_create (): map (a, b)
fun {a, b:t@ype} map_update (m: map (a, b), d: a, t: b): map (a, b)
(* *************** ****************** *)

fun {a, b:t@ype} map_dom (m: map (a, b)): set a

fun {a, b:t@ype} map_rng (m: map (a, b)): set b

// The two maps must be compatible. 
fun {a, b:t@ype} map_munion (m1: map (a, b), m2: map (a, b)): map (a, b)

// Overrride
// Any commn elements are mapped as by m2 (m2 overrides m1).
fun {a, b:t@ype} map_override (m1: map (a, b), m2: map (a, b)): map (a, b)

// distributed merge
// The maps in ms must be compatible.
// m1 ++ m2
fun {a, b:t@ype} map_merge (ms: set (map (a, b))): map (a, b)

// domain restrict to
// creates the map consisting of hte elements in m whose key is in s. 
// s need not be a subset of dom m
// s <: m
fun {a, b:t@ype} map_dom_restrict_to (s: set a, m: map (a, b)): map (a, b)

// domain restrict by
// creates the map consisting of tthe elements in m whose key is not in s. 
// s need not be a subset of dom m.
// s <-: m
fun {a, b:t@ype} map_dom_restrict_by (s: set a, m: map (a, b)): map (a, b)

// range restrict to
// creates the map consisting of hte elements in m whose information value is in s. 
// s need not be a subset of dom m
// m :> s
fun {a, b:t@ype} map_dom_restrict_to (m: map (a, b), s: set a): map (a, b)

// range restrict by
// creates the map consisting of hte elements in m whose information value is not in s. 
// s need not be a subset of dom m
// m :-> s
fun {a, b:t@ype} map_dom_restrict_to (m: map (a, b), s: set a): map (a, b)

// map apply
// d must be in the domain of m
// m(d)
fun {a, b:t@ype} map_apply (m: map (a, b), d: a): b

// map composition
// range of m2 must be a subsetof dom m1
// The current VDM interpreter shows the folowing
// {1 |-> 2, 2 |-> 3} comp {1 |-> 2, 0 |-> 3} = {0 |-> null, 1 |-> 3}
// but I think it should report "fatal error"
fun {a,b,c:t@ype} map_comp (m1: map (b, c), m2: map (a, b)): map (a, c)

// map iteration
// yields the map where m is composied with itself n times.
// n=0 yields the identity map where each element of dom m is mapped into
// itself; n=1 yields m itself. For n>1, the range of m must be asubset of dom m.
// m ** n
fun {a:t@ype} map_iter (m: map (a, a), n: Nat): map (a, a)

fun {a, b:t@ype} map_eq (m1: map (a, b), m1: map (a, b)): bool

fun {a, b:t@ype} map_neq (m1: map (a, b), m1: map (a, b)): bool

// m must be 1-to-1 mapping
fun {a, b:t@ype} map_inverse (m: inmap (a, b)): inmap (b, a)


(* ************** ****************** *)

// Product Types
// similar to the tuple in ATS
// refer to <<VDM-10 Language Manual>> P22
// T = T1 * T2 * T3

// constructor
// mk_(1, 'a')

// pattern matching

// Operation
// Select   T * Nat -> T
// equality T * T -> bool
// Inequality T * T -> bool



(* ************** ****************** *)

// Union Types
// Use datatype instead?
// or abstype union (a: t@ype, b: t@ype}
// T = T1 | T2 | T3 | ...
// union (T1, union (T2, T3))

// Operation
// equality T * T -> bool
// Inequality T * T -> bool

(* ************** ****************** *)

// Composite (Record) Types
// similar to the record in ATS

// constructor

// pattern matching

// Operation
// Select   T * id -> T
// equality T * T -> bool
// Inequality T * T -> bool
// is_A     ID * T -> bool

(* ************** ****************** *)

// Optional Types
// constructor
fun {a: t@ype} option_make (x: a): option a
fun {a: t@ype} option_nil (): option a 

// Operation
fun {a: t@ype} option_isnil (x: option a): bool

// x is not null
fun {a: t@ype} option_getval (x: option a): a

// Optional Viewtypes
// constructor
fun {a: viewt@ype} option_vt_make (x: a): option_vt a
fun {a: viewt@ype} option_vt_nil (): option_vt a 

// Operation
fun {a: viewt@ype} option_vt_isnil (x: option_vt a): bool

// x is not null
fun {a: viewt@ype} option_vt_getval (x: option_vt a): a
(* ************** ****************** *)
/*
 * The type system of VDM is different from ATS. The former has certain
 * kind of auto type conversion. E.g.
 * values
 *     x: [int] = 3
 *     y: int = foo(x)
 * 
 * functions
 *     foo: int -> int
 *     foo(x) == if x > 0 then 1 else -1
 */

// It may be not necessary to imitate this in ATS.

(* ************** ****************** *)

// The Ojbect Reference Types (VDM++ and VDM-RT only)
// similar to class types
// no counterpart in ATS

(* ************** ****************** *)

// Function Types

(* ************** ****************** *)

// Type invariants

(* ************** ****************** *)

// expression

// Quantified Expressions
// set bind of a type bind
// forall a in set s &
// exist x: Nat &
// exist1 x: Nat &













