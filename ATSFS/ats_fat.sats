

/* *************************
 * File name: ats_fat.sats
 * Author: Zhiqiang Ren
 * Date: Oct 11, 2011
 * Description: level 01 spec for FAT file system
 * *************************/

/* *************************
 * rule 1. trinity of a function foo
 *      foo_main
 *      foo_pre
 *      foo_post
 *   Questions to this rule:
 *      1. for pre, the type of input parameters such as &T? >> T, shall I omit them?
 *      2. for post, sometimes it's impossible to get the original value of the input arguments
 * 
 * rule 2. error code
 *      error: &error_code? >> error_code
 * 
 * rule 3. using viewtype
 * *************************/
 
/*
 * design 
 * no cache in memory
 * one operation one time, no multithreading
 * 
 */



staload "ats_spec.sats"
staload "error_handle.sats"
 
//absviewtype superblock
// this kind of inode is totally in the memory
absviewtype inode
//absviewtype dentry

abst@ype mode

abst@ype time
(* external function *)
fun get_cur_time (): time


// only 28 bits are valid
#define FAT_ENT_FREE 0
// #define FAT_ENT_BAD 0xFFFFFF7  // 0xFFFFFFFF
// #define FAT_ENT_EOF 0xFFFFFFF  // 0xFFFFFFF
// #define FAT_SZ 0xFFFFFF

// todo to change back
#define FAT_ENT_BAD 1000
#define FAT_ENT_EOF 100
#define FAT_SZ 10

#define BLK_SZ 512


typedef block_id = [i: nat] int i
typedef block = seq char
fun validate_block (b: block): bool (* =
  (seq_len b) == BLK_SZ
*)

#define BLKS_PER_CLS 4
typedef cluster_id = [i: pos | i <= FAT_SZ || i == FAT_ENT_FREE || i == FAT_ENT_EOF || i == FAT_ENT_BAD] int i
typedef cluster = seq block
fun validate_cluster (c: cluster): bool (* =
  (seq_len c) == BLKS_PER_CLS
*)

// #define CLS_SZ (BLK_SZ * BLKS_PER_CLS) todo
#define CLS_SZ 2048

absviewtype hd  // hard disk

viewtypedef rollback (n: int) = rollback_res0 (n)
viewtypedef rollback_hd (n: int) = rollback_res1 (hd, n)




#define MAX_NAME 8
// typedef name = [xs: seq] (seq_len (xs, MAX_NAME) | seq (char, xs))
typedef name = seq char
fun validate_name (n: name): bool (* =
  (seq_len n) == MAX_NAME
*)


// #define DIR_ENTRYS_PER_BLOCK (BLK_SZ / DIR_ENTRY_LEN)
// todo to change back
#define DIR_ENTRYS_PER_BLOCK 16

typedef dir_entry_id = [i: nat | i < DIR_ENTRYS_PER_BLOCK] int i

#define DIR_ENTRY_LEN 32
typedef dir_entry = seq char
fun validate_dir_entry (d: dir_entry): bool (* =
  (seq_len d) == DIR_ENTRY_LEN
*)

typedef file_sz = [i: nat] int i

#define FILE_TYPE_DIR 1
#define FILE_TYPE_FILE 2
typedef file_type = [n: int | n == FILE_TYPE_DIR || n == FILE_TYPE_FILE] int n
fun validate_file_type (t: file_type): bool


(* ************** ****************** *)
(* hd operation *)
// similar to superblock, from hd we can know anything

(* external function *)
fun hd_set_fat_entry (hd: !hd, ind: cluster_id, entry: cluster_id, error: &ecode? >> ecode (e)): #[e: int] void

(* external function *)
fun hd_get_fat_entry (hd: !hd, ind: cluster_id, error: &ecode? >> ecode (e)): #[e: int] option (cluster_id, e == 0)

(* external function *)
fun hd_get_fat_free_entry (hd: !hd, error: &ecode? >> ecode (e)): #[e: int] option (cluster_id, e == 0)

(* external function *)
fun hd_write_block (hd: !hd, ind: block_id, block: block, error: &ecode? >> ecode (e)): #[e: int] void

(* external function *)
fun hd_read_block (hd: !hd, ind: block_id, error: &ecode? >> ecode (e)): #[e: int] option (block, e == 0)


(* external function *)
fun hd_get_dir_entry (
    hd: !hd, blkid: block_id, entyrid: dir_entry_id, error: &ecode? >> ecode e
): #[e: int] option (dir_entry, e == 0)

(* external function *)
fun hd_set_dir_entry {n:nat} (pf: tag (n) |
    hd: !hd, 
    blkid: block_id, 
    entryid: dir_entry_id, 
    entry: dir_entry, 
    error: &ecode? >> ecode (e)
): #[e: int] (opt_tag (n, e) | option_vt (rollback_hd (n+1), e == 0))

fun hd_clear_dir_entry {n:nat} (pf: tag (n) |
    hd: !hd, 
    blkid: block_id, 
    entryid: dir_entry_id, 
    entry: dir_entry, 
    error: &ecode? >> ecode (e)
): #[e: int] (opt_tag (n, e) | option_vt (rollback_hd (n+1), e == 0))

(* external function *)
fun hd_write_inode {n: nat} (pf: tag (n) | 
	hd: !hd, 
	inode: !inode, 
	error: &ecode? >> ecode (e)
): #[e: int] (opt_tag (n, e) | 
  option_vt (rollback_hd (n+1), e == 0))

(* ************** ****************** *)


(* ************** ****************** *)

(* inode related operations *)
(* external function *)
(* What's in inode? first cluster, time, file size *)
(* todo shall I put the location of the dir_entry of the inode into the inode? *)
(* currently, I didn't do that. *)
fun inode_get_file_type (inode: !inode): file_type

(* external function *)
fun inode_get_fst_cluster (inode: !inode): cluster_id
fun inode_get_fst_cluster_main (inode: !inode): cluster_id
fun inode_get_fst_cluster_post (inode: !inode, ret: cluster_id): bool (* =
if ret = FAT_ENT_FREE || ret = FAT_ENT_BAD then false else
  let
    val t = inode_get_file_type (inode)
  in
    if t = FILE_TYPE_DIR then ret <> FAT_ENT_EOF
    else true
  end
*)

fun inode_set_first_cluster (inode: !inode, cid: cluster_id): void



(* external function *)
// todo: currently assume it won't fail
fun inode_create_from_dir_entry (e: dir_entry): inode

(* external function *)
// todo currently I don't need this function
// fun inode_get_dir_entry (inode: !inode): '(cluster_id, block_id, dir_entry_id)

(* external function *)
fun inode_get_file_size (inode: !inode): file_sz

(* external function *)
fun inode_set_file_size {n: nat} (pf: tag (n) | inode: !inode, sz: file_sz): (tag (n+1)| rollback (n+1))

(* external function *)
fun inode_set_time {n: nat} (pf: tag (n) | inode: !inode, time: time): (tag (n+1) | rollback (n+1))




(* ************** ****************** *)

(* dir_entry function *)


(* external function *)
fun dir_entry_create
  (name: name, t: file_type, start: cluster_id, sz: file_sz, time: time): dir_entry
fun dir_entry_create_main
  (name: name, t: file_type, start: cluster_id, sz: file_sz, time: time): dir_entry
fun dir_entry_create_precond
  (name: name, t: file_type, start: cluster_id, sz: file_sz, time: time): bool (* =
  start <> FAT_ENT_BAD && start <> FAT_ENT_EOF
*)

(* external function *)
fun dir_entry_update_size (entry: dir_entry, sz: file_sz): dir_entry

(* external function *)
fun dir_entry_get_size (entry: dir_entry): file_sz



(* ************** ****************** *)
(* auxiliary function *)

(* external function *)
fun fat_cluster_id_to_block_id (clsid: cluster_id): block_id
fun fat_cluster_id_to_block_id_main (clsid: cluster_id): block_id
fun fat_cluster_id_to_block_id_precond (clsid: cluster_id): block_id (* =
  clsid <> FAT_ENT_BAD && clsid <> FAT_ENT_EOF
*)

fun clusters_loopup_name
  (hd: !hd, name: name, start: cluster_id, error: &ecode? >> ecode (e)): #[e: int] 
  option ('(cluster_id, block_id, dir_entry_id), e == 0)

fun clusters_loopup_name_main
  (hd: !hd, name: name, start: cluster_id, error: &ecode? >> ecode (e)): #[e: int] 
  option ('(cluster_id, block_id, dir_entry_id), e == 0)

fun clusters_loopup_name_precond
  (hd: !hd, name: name, start: cluster_id, error: &ecode?): bool (* =
if (start >= 1 && start <= FAT_SZ) || start = FAT_ENT_EOF
then true else false
*)

fun clusters_release_norb {n: nat} (pf: tag (n), pfrb: norollback | 
  hd: !hd, start: cluster_id, error: &ecode? >> ecode (e)): #[e: int] (opt_tag (n, e) | void)

fun blocks_loopup_name {k: nat | k < BLKS_PER_CLS}(hd: !hd, name: name, cur: block_id, k: int k, error: &ecode? >> ecode (e)): #[e: int] 
  option ('(block_id, dir_entry_id), e == 0)
  
fun block_loopup_name (blk: block, name: name, error: &ecode? >> ecode (e)): #[e: int] 
  option (dir_entry_id, e == 0)


fun clusters_find_empty_entry {k: nat | k > 0 && k <= FAT_SZ} 
(hd: !hd, start: cluster_id, k: int k, error: &ecode? >> ecode (e)): #[e: int] 
  option ('(cluster_id, block_id, dir_entry_id), e == 0)


/* *************************
 * Function Name: clusters_find_empty_entry_new
 * Desc: locate the dir entry if possible, allocate new cluster to hold
 *   new dir entry if necessary
 * 
** *************************/
fun clusters_find_empty_entry_new {n: nat} (pf: tag n | 
	hd: !hd, 
	start: cluster_id, 
	error: &ecode? >> ecode (e)
): #[e: int] (
  opt_tag (n, e) | 
  option_vt (rollback_hd (n+1), e == 0), 
  option_vt ('(bool, cluster_id, block_id, dir_entry_id), e == 0)
)

fun clusters_find_empty_entry_new_precond (
	hd: !hd, 
	start: cluster_id, 
	error: &ecode?
): bool (* =
*)

/* *************************
 * Function Name: clusters_find_empty_entry_new
 * Desc: add one cluster to the chain if possible
 * 
** *************************/
fun clusters_add_one (hd: !hd, start: cluster_id, error: &ecode? >> ecode (e)): #[e: int] option (cluster_id, e == 0)

fun fs_allocate_cluster (hd: !hd, error: &ecode? >> ecode (e)): #[e: int] option (cluster_id, e == 0)

fun clusters_find_last (hd: !hd, start: cluster_id): cluster_id
fun clusters_find_last_main (hd: !hd, start: cluster_id): cluster_id
fun clusters_find_last_post (hd: !hd, start: cluster_id): bool (*=
  start <> 0 && start <> FAT_ENT_BAD && start <> FAT_ENT_EOF
*)




(* VFS function *)

#define ECODE_OK 0
#define ECODE_ 1




(* ************** ****************** *)


// The following operations are related to inode_operations, we need wrapper around these functions
// to handle dentry (d_instantiate, d_clear...). Also I assume that a global lock is held inside the wrapper.

// int inode_create(struct inode *dir, struct dentry *dentry, int mode, struct nameidata *nd)
// nd seems uselsss
// precond:
fun inode_dir_create (pfrb: norollback | dir: !inode, name: name, mode: mode, hd: !hd, error: &ecode? >> ecode (e)): #[e:int] option_vt (inode, e == 0)
fun inode_dir_create_main (pfrb: norollback | dir: !inode, name: name, mode: mode, hd: !hd, error: &ecode? >> ecode (e)): #[e:int] option_vt (inode, e == 0)
fun inode_dir_create_pre (pfrb: norollback | dir: !inode, name: name, mode: mode, hd: !hd, error: &ecode?): bool
(*
let
  val t = inode_get_file_type (inode)
in
  t = FILE_TYPE_DIR
end
*)


// struct dentry *inode_lookup(struct inode *dir, struct dentry *dentry, struct nameidata *nd)
// nd seems useless
fun inode_dir_lookup_main (pfrb: norollback | dir: !inode, name: name, hd: !hd, error: &ecode? >> ecode e): #[e: int] option_vt (inode, e == 0)
fun inode_dir_loopup_pre (pfrb: norollback | dir: !inode, name: name, hd: !hd, error: &ecode?): bool (* =
let
  val t = inode_get_file_type (inode)
in
  t = FILE_TYPE_DIR
end
*)

// int msdos_unlink(struct inode *dir, struct dentry *dentry)
fun msdos_dir_unlink (pfrb: norollback | dir: !inode, name: name, file: !inode, hd: !hd, error: &ecode? >> ecode e): #[e: int] void

// int (*mkdir) (struct inode *,struct dentry *,int);
// int (*rmdir) (struct inode *,struct dentry *);
// int (*rename) (struct inode *, struct dentry *, struct inode *, struct dentry *);



(* ************** ****************** *)
// The following operations are related to file_operations


(* ************** ****************** *)
// The following operations are related to super_operations


