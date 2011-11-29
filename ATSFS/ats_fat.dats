/* *************************
 * File name: ats_fs.dats
 * Author: Zhiqiang Ren
 * Date: Nov 1, 2011
 * Description: level 01 spec for FAT file system
 * *************************/

staload "ats_fat.sats"
staload "ats_spec.sats"

(* ************** ****************** *)


/* *************************
 * fun inode_get_fst_cluster (inode: !inode): cluster_i
 * *************************/
implement inode_get_fst_cluster (inode) = let
   val ret = inode_get_fst_cluster_main (inode)
   val ()= assert (inode_get_fst_cluster_post (inode, ret))
in
  ret
end

/* *************************
 * fun inode_get_fst_cluster_post (inode: !inode, ret: cluster_id): bool
 * *************************/
implement inode_get_fst_cluster_post (inode, ret) =
if ret = FAT_ENT_FREE || ret = FAT_ENT_BAD then false else
  let
    val t = inode_get_file_type (inode)
  in
    if t = FILE_TYPE_DIR then ret <> FAT_ENT_EOF
    else true
  end

(* ************** ****************** *)


/* *************************
 * fun inode_create (
 * dir: !inode, 
 * name: name, 
 * mode: mode, 
 * hd: !hd, 
 * error: &ecode? >> ecode
 * ): option_vt inode
 * *************************/
implement inode_create (dir, name, mode, hd, error) = let
  val () = assert (inode_create_pre (dir, name, mode, hd, error))
in
  inode_create_main (dir, name, mode, hd, error)
end

(* ************** ****************** *)
(*
fun clusters_loopup_name_main (hd: !hd, name: name, start: cluster_id, error: &ecode? >> ecode (e)): #[e: int] 
  option_vt (@(cluster_id, block_id, dir_entry_id), e == 0)
fun clusters_loopup_name_precond (hd: !hd, name: name, start: cluster_id, error: &ecode?): bool
*)
implement clusters_loopup_name (hd, name, start, error) = let
  val () = assert (clusters_loopup_name_precond (hd, name, start, error))
  val ret = clusters_loopup_name (hd, name, start, error)
//  val () = assert (clusters_loopup_name_postcond (hd, name, start, error, ret))
in
  ret
end

implement clusters_loopup_name_precond (hd, name, start, error) = if
  start >= 1 && start <= FAT_SZ
then true else false

implement clusters_loopup_name_main (hd, name, start, error) = let
  fun clusters_loopup_name_loop {k: nat | k < FAT_SZ} .<k>.
    (hd: !hd, name: name, cur: cluster_id, k: int k, error: &ecode? >> ecode (e)):<> 
    #[e: int] option_vt (@(cluster_id, block_id, dir_entry_id), e == 0) = 

// implement clusters_loopup_name_postcond (hd, name, start, error, ret) = content_post

 
(* ************** ****************** *)



/* *************************
 * fun inode_create_main (
 * dir: !inode, 
 * name: name, 
 * mode: mode, 
 * hd: !hd, 
 * error: &ecode? >> ecode
 * ): option_vt inode
 * *************************/
implement inode_create_main (dir, name, mode, hd, error) = let
  val fst_cls = inode_get_fst_cluster (dir)
  val opt_entry = clusters_loopup_name (hd, name, fst_cls)
in
  if option_isnil (opt_entry) = false then let // file already exists
    val () = error := ECODE_
  in  option_vt_nil () end
  else let
    val opt_entry = 
      clusters_find_empty_entry_new (hd, fst_cls, error)
  in
    if option_isnil (opt_entry) = true then option_vt_nil ()
    else  let
      val time = get_cur_time ()
      val @(is_new, cls_id, blk_id, ent_id) = option_getval (opt_entry)
      val file_size = inode_get_file_size (dir)
      val () = if inode_set_file_size (dir, file_size + )
      
      
      val blk_no = fat_cluster_id_to_block_id (cls_id) + blk_id
      
      val dir_entry = dir_entry_create (name, FILE_TYPE_FILE, FAT_ENT_FREE, 0, time)
      val bret = hd_set_dir_entry (hd, blk_no, ent_id, dir_entry, error)
    in
      if bret = false then let
        val () = error := ECODE_FATAL
        // todo: didn't return the cluster back (if it's new)
      in
        option_vt_nil ()
      end else let
        // assume that it shall not fail
        val inode = inode_create_from_dir_entry (dir_entry)
        // todo set size
        val @(blk_no, ent_id) = inode_get_dir_entry (dir)
        val opt_entry = hd_get_dir_entry (hd, blk_no, ent_id, error)
      in
        if option_isnil (opt_entry) then option_vt_nil () // todo: didn't return the cluster back (if it's new)
        else if is_new = true then let
          val dir_entry = option_getval (opt_entry)
          val file_size = dir_entry_get_size ()
          val dir_entry = dir_entry_update_size (dir_entry, file_size + BLK_SZ)
          val bret = hd_set_dir_entry (hd, blk_no, ent_id, dir_entry, error)
        in
          if bret = false then let
            val () = error := ECODE_FATAL
            // todo: didn't return the cluster back (if it's new)
          in
            option_nil ()
          end else option_vt_make (inode)
        end else option_vt_make (inode)
      end
    end
  end
end

////
/*
 * fun dir_entry_create
  (name: name, t: file_type, start: cluster_id, sz: file_sz, t: time): dir_entry
**/
implement dir_entry_create (name, t, start, sz, time) = let
  val () = assert (dir_entry_create_precond (name, t, start, sz, time))
  val ret = dir_entry_create_main (name, t, start, sz, time)
  // val () = assert (dir_entry_create_postcond (name, t, start, sz, time, ret))
in
  ret
end

implement dir_entry_create_precond (name, t, start, sz, time) = 
  start <> FAT_ENT_BAD && start <> FAT_ENT_EOF


/*
 * fun fat_cluster_id_to_block_id (clsid: cluster_id): block_id
**/
implement fat_cluster_id_to_block_id (clsid) = let
  val () = assert (fat_cluster_id_to_block_id_precond (clsid))
  val ret = fat_cluster_id_to_block_id (clsid)
  // val () = assert (fat_cluster_id_to_block_id_post (clsid, ret))
in
  ret
end

fun fat_cluster_id_to_block_id_precond (clsid) =
  clsid <> FAT_ENT_BAD && clsid <> FAT_ENT_EOF

/*
 * fun inode_get_fst_cluster (inode: !inode): cluster_id
**/
implement inode_get_fst_cluster (inode) = let
  // val () = assert (inode_get_fst_cluster_precond (inode))
  val ret = inode_get_fst_cluster (inode)
  val () = assert (inode_get_fst_cluster_postcond (inode, ret))
in
  ret
end

implement inode_get_fst_cluster_postcond (inode, ret) = ret <> FAT_ENT_BAD               

/*
 * fun clusters_find_empty_entry_new (hd: !hd, start: cluster_id, error: &ecode? >> ecode):
  option @(cluster_id, block_id, dir_entry_id)
**/
implement clusters_find_empty_entry_new (hd, start, error) = let
  val () = assert (clusters_find_empty_entry_new_precond (hd, start, error))
  val ret = clusters_find_empty_entry_new (hd, start, error)
  val () = assert (clusters_find_empty_entry_new_postcond (hd, start, error, ret))
in
  ret
end

implement clusters_find_empty_entry_new_precond (hd, start, error) = 
  start <> FAT_ENT_BAD

implement clusters_find_empty_entry_new_postcond (hd, start, error, ret) = 
  if option_isnil (ret) = true then true
  else let
    val @(cls_id, _, _) = option_getval (ret)
  in
    cls_id <> FAT_ENT_BAD && cls_id <> FAT_ENT_FREE
  end



////

implement data_get_entry (blk, entry, data): dir_entry = let
  val block = seq_app (data, blk)
  val start = entry * DIR_ENTRY_LEN
in
  seq_sub (block, start, DIR_ENTRY_LEN)
end

implement data_set_entry (blkno, entryno, data, entry) = let
  val block = seq_app (data, blkno)
  val block = seq_merge (block, entryno * DIR_ENTRY_LEN, entry)
  val data = seq_update (data, blkno, block)
in
  data
end

implement clusters_find_empty_entry_new (start, fat) = let
  val opt_entry = clusters_find_empty_entry (start, fat)
in
  if option_isnil (opt_entry) = false then (ECODE_OK, opt_entry, fat)
  else let
    val (ecode, opt_cls, fat) = clusters_add_one (start, fat)
  in
    if ecode <> ECODE_OK then (ecode, option_nil (), fat)
    else let
      val cls = option_getval (opt_cls)
    in
      (ECODE_OK, 
       option_make<@(Nat, Nat, Nat)> (@(cls, 0, 0)), 
       fat)
    end
  end
end

(* add one cluster to the chain if possible*)
implement clusters_add_one (start, fat) = let
  val (ecode, opt_cls) = fs_allocate_cluster (fat)
in
  if (ecode <> ECODE_OK) then (ecode, opt_cls, fat)
  else let
    val last_cls = clusters_find_last (start, fat)
    val new_cls = option_getval (opt_cls)
    val fat = map_update (fat, last_cls, new_cls)
    val fat = map_update (fat, new_cls, FAT_ENT_EOF)
  in
    (ECODE_OK, option_make (new_cls), fat)
  end
end

implement clusters_find_last (start, fat) = let
  val next = map_apply (fat, start)
in
  if next = FAT_ENT_EOF then start
  else clusters_find_last (next, fat)
end

implement inode_lookup (dir, name, fs) = let
  val f_cls = inode_get_fst_cluster (dir)
  val fat = fs.fat
  val data = fs.data
  val opt_entry = clusters_lookup (name, f_cls, fat)
in
  if option_isnil (opt_entry) then (ECODE_, option_nil ())
  else let
    val (clsno, blkno, entryno) = option_getval (opt_entry)
    val blkno = fat_cluster_to_block (clsno) + blkno
    val entry = data_get_entry (blkno, entryno, data)
    val inode = inode_from_dir_entry (entry)
    val opt_inode = option_make (inode)
  in
    (ECODE_OK, opt_inode)
  end
end
  















