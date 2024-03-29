/* *************************
 * File name: ats_fs.dats
 * Author: Zhiqiang Ren
 * Date: Nov 1, 2011
 * Description: level 01 spec for FAT file system
 * *************************/

staload "ats_fat.sats"
staload "ats_spec.sats"

staload "error_handle.sats"

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
implement clusters_loopup_name (hd, name, start, error) = let
  val () = assert (clusters_loopup_name_precond (hd, name, start, error))
  val ret = clusters_loopup_name (hd, name, start, error)
//  val () = assert (clusters_loopup_name_postcond (hd, name, start, error, ret))
in
  ret
end

implement clusters_loopup_name_precond (hd, name, start, error) = if
  (start >= 1 && start <= FAT_SZ) || start = FAT_ENT_EOF
then true else false

 
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
  val fst_cid = inode_get_fst_cluster (dir)
  val o_entry = clusters_loopup_name (hd, name, fst_cid, error)
in
  if is_succ (error) then let // file already exists
    val () = ecode_set (error, ECODE_)
  in  
    option_vt_nil () 
  end else let
    prval vtag = tag_create ()
    val (optt | o_rollback, o_entry) = 
      clusters_find_empty_entry_new (vtag, hd, fst_cid, error) 
  in
    if is_succ (error) then let  // found empty dir entry
      prval vtag = optt_unsucc (optt)
      val rollback1 = unsome (o_rollback)
      val (is_new, cid, bid, eid) = unsome (o_entry)
      
      // update father inode
      val time = get_cur_time ()
      val (vtag | rollback2) = inode_set_time (vtag | dir, time)
      val file_size = inode_get_file_size (dir)
      val (vtag | rollback3) = if is_new then inode_set_file_size (vtag | dir, file_size + CLS_SZ)
                      else inode_set_file_size (dir, file_size)
      val (optt | o_rollback) = hd_write_inode (vtag | hd, dir, error)
    in
      if is_succ (error) then let
        prval vtag = optt_unsucc (optt)
        val rollback4 = unsome (o_rollback)
        
        val blk_no = fat_cluster_id_to_block_id (cid) + bid
        val dentry = dir_entry_create (name, FILE_TYPE_FILE, FAT_ENT_EOF, 0, time)
        val (optt, o_rollback) = hd_set_dir_entry (vtag | hd, blk_no, eid, dentry, error)
      in
        if is_succ (error) then let
          prval vtag = optt_unsucc (optt)
          val rollback5 = unsome (o_rollback)
          
          val inode = inode_create_from_dir_entry (dir_entry)
          // todo release all the cloptr
          val () = rollback_res1_relase (rollback5)
          val () = rollback_res1_relase (rollback4)
          val () = rollback_res1_relase (rollback3)
          val () = rollback_res1_relase (rollback2)
          val () = rollback_res1_relase (rollback1)
          
          prval () = tag_clear (vtag)
        in
         option_vt_make (inode)
        end else let
          prval vtag = optt_unfail (optt)
          val () = unnone (o_rollback)

          val (vtag | ret) = rollback4 (vtag | hd)
          val () = cloptr_free (rollback4)
          val (vtag | ret) = rollback3 (vtag)
          val () = cloptr_free (rollback3)
          val (vtag | ret) = rollback2 (vtag)
          val () = cloptr_free (rollback2)
          val (vtag | ret) = rollback1 (vtag | hd)
          val () = cloptr_free (rollback1)
          prval () = tag_free (vtag)
        in
          option_vt_nil ()
        end
      end else let
        prval vtag = optt_unfail (optt)
        val () = unnone (o_rollback)
       
        val (vtag | ret) = rollback3 (vtag)
        val () = cloptr_free (rollback3)
        val (vtag | ret) = rollback2 (vtag)
        val () = cloptr_free (rollback2)
        val (vtag | ret) = rollback1 (vtag | hd)
        val () = cloptr_free (rollback1)
        prval () = tag_free (vtag)
      in
        option_vt_nil ()
      end
    end else let
      prval vtag = optt_unfail (optt)
      val () = unnone (o_rollback)
      
      prval () = tag_free (vtag)
    in
      option_vt_nil ()
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
  















