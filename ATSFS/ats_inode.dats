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
 * fun fat_alloc_cluster_pre (
 * 	hd: !hd, 
 *  n: int, 
 *  error: &ecode?
 * ): bool
** *************************/
implement fat_alloc_cluster_pre (hd, n, err) = n > 0

/* *************************
 * fun fat_alloc_cluster_post {e: int} (
 * 	hd: !hd, 
 *  n: int, 
 *  error: ecode e, 
 *  ret: option (cluster_id, e)
 * ): bool
** *************************/
implement fat_alloc_cluster_post {e} (hd, n, error, ret) =
if is_succ (error) then let
  val '(start_cls) = option_getval {'(cluster_id)} (ret)
  val len = fat_clusters_length (hd, start_cls)
in
  start_cls <= FAT_SZ && len = n
end else true

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
 * clusters_loopup_name (
 * 	hd
 *  name
 *  start
 *  error
 * )
** *************************/
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
 * fun inode_create (
 * dir: !inode, 
 * name: name, 
 * mode: mode, 
 * hd: !hd, 
 * error: &ecode? >> ecode
 * ): option_vt inode
 * *************************/
implement inode_dir_create (dir, name, mode, hd, error) = let
  val () = assert (inode_dir_create_pre (dir, name, mode, hd, error))
in
  inode_dir_create_main (dir, name, mode, hd, error)
end

/* *************************
 * fun inode_dir_create_pre (
 * 	dir: !inode, 
 *  name: name, 
 *  mode: mode, 
 *  hd: !hd, 
 *  error: &ecode?
 * ): bool
** *************************/
implement inode_dir_create_pre (dir, name, mode, hd, error) =
if inode_mutex_islocked (dir) then let
  val t = inode_get_file_type (dir)
in
  if t = FILE_TYPE_DIR then let
    val opt_inode = inode_dir_lookup (dir, name, hd, error)
    val () = inode_opt_release (opt_inode)
  in
    if is_succ (error) then false else true
  end else false
end else false


/* *************************
 * fun inode_dir_create_main (
 * dir: !inode, 
 * name: name, 
 * mode: mode, 
 * hd: !hd, 
 * error: &ecode? >> ecode
 * ): option_vt inode
 * *************************/
implement inode_dir_create_main (dir, name, mode, hd, error) = let
  val fst_cid = inode_get_fst_cluster (dir)
  prval vtag = tag_create ()
  val (optt | o_rollback, o_entry) = 
    clusters_find_empty_entry_new (vtag | hd, fst_cid, error) 
in
  if is_succ (error) then let  // found empty dir entry
    prval vtag = optt_unsucc (optt)
    val rollback1 = option_vt_getval {rollback_hd (1)} (o_rollback)   // todo why must add type here
    val '(is_new, cid, bid, eid) = option_getval {'(bool, cluster_id, block_id, dir_entry_id)} (o_entry)   // todo why must add type here
    
    // update father inode
    val time = get_cur_time ()
    val (vtag | rollback2) = inode_set_time (vtag | dir, time)
    val file_size = inode_get_file_size (dir)

    val (vtag | rollback3) = (if is_new then inode_set_file_size (vtag | dir, file_size + CLS_SZ)
                             else inode_set_file_size (vtag | dir, file_size)): (tag 3 | rollback_inode 3)   // todo why must add type here
    val (optt | o_rollback) = hd_write_inode (vtag | hd, dir, error)  // update the inode for "dir"
  in
    if is_succ (error) then let
      prval vtag = optt_unsucc (optt)
      val rollback4 = option_vt_getval {rollback_ihd (4)} (o_rollback)   // todo why must add type here
      
      val blk_no = fat_cluster_id_to_block_id (cid) + bid
      val dentry = dir_entry_create (name, FILE_TYPE_FILE, FAT_ENT_EOF, 0, time)
      // update the dir entry
      val (optt | o_rollback) = hd_set_dir_entry (vtag | hd, blk_no, eid, dentry, error)  
    in
      if is_succ (error) then let
        prval vtag = optt_unsucc (optt)
        val rollback5 = option_vt_getval {rollback_hd (5)} (o_rollback)
        
        val inode = inode_create_from_dir_entry (dentry)
        // todo "hack here" release all the cloptr
        val (vtag | ret) = rollback5 (vtag | hd, error)
        val () = cloptr_free (rollback5)
        val (vtag | ret) = rollback4 (vtag | dir, hd, error)
        val () = cloptr_free (rollback4)
        val (vtag | ret) = rollback3 (vtag | dir, error)
        val () = cloptr_free (rollback3)
        val (vtag | ret) = rollback2 (vtag | dir, error)
        val () = cloptr_free (rollback2)
        val (vtag | ret) = rollback1 (vtag | hd, error)
        val () = cloptr_free (rollback1)
        prval () = tag_free (vtag)
      in
       option_vt_make (inode)
      end else let
        prval vtag = optt_unfail (optt)
        val () = option_vt_removenil (o_rollback)

        val (vtag | ret) = rollback4 (vtag | dir, hd, error)
        val () = cloptr_free (rollback4)
        val (vtag | ret) = rollback3 (vtag | dir, error)
        val () = cloptr_free (rollback3)
        val (vtag | ret) = rollback2 (vtag | dir, error)
        val () = cloptr_free (rollback2)
        val (vtag | ret) = rollback1 (vtag | hd, error)
        val () = cloptr_free (rollback1)
        prval () = tag_free (vtag)
      in
        option_vt_nil ()
      end
    end else let  // hd_write_inode failed
      prval vtag = optt_unfail (optt)
      val () = option_vt_removenil (o_rollback)

      val (vtag | ret) = rollback3 (vtag | dir, error)
      val () = cloptr_free (rollback3)
      val (vtag | ret) = rollback2 (vtag | dir, error)
      val () = cloptr_free (rollback2)
      val (vtag | ret) = rollback1 (vtag | hd, error)
      val () = cloptr_free (rollback1)
      prval () = tag_free (vtag)

    in
      option_vt_nil ()
    end
  end else let  // clusters_find_empty_entry_new failed
    prval vtag = optt_unfail (optt)
    val () = option_vt_removenil (o_rollback)
    
    prval () = tag_free (vtag)
  in
    option_vt_nil ()
  end
end


(* ************** ****************** *)

/* *************************
 * fun inode_dir_loopup_pre (
 * 	dir: !inode, 
 *  name: name, 
 *  hd: !hd, 
 *  error: &ecode?
 * ): bool
** *************************/
implement inode_dir_loopup_pre (dir, name, hd, error) =
if inode_mutex_islocked (dir) then let
  val t = inode_get_file_type (dir)
in
  if t = FILE_TYPE_DIR then true else false
end else false

/* *************************
 * fun inode_dir_lookup_main (
 * 	dir: !inode, 
 *  name: name, 
 *  hd: !hd, 
 *  error: &ecode? >> ecode e
 * ): #[e: int] option_vt (inode, e == 0)
** *************************/
implement inode_dir_lookup_main (dir, name, hd, error) = let
  val fst_cid = inode_get_fst_cluster (dir)
  val o_entry = clusters_loopup_name (hd, name, fst_cid, error)
in
  if is_succ (error) then let // file already exists
    val '(cid, bid, eid) = option_getval {'(cluster_id, block_id, dir_entry_id)} (o_entry)
    val blk_no = fat_cluster_id_to_block_id (cid) + bid
    // read dir entry
    val o_dentry = hd_get_dir_entry (hd, blk_no, eid, error)  
  in
    if is_succ (error) then let
      val dentry = option_getval (o_dentry)
      val inode = inode_create_from_dir_entry (dentry)
    in
      option_vt_make (inode)
    end else option_vt_nil ()      
  end 
  else option_vt_nil ()
end

(* ************** ****************** *)

/* *************************
 * fun msdos_dir_unlink_pre (
 * 	dir: !inode, 
 *  name: name, 
 *  file: !inode, 
 *  hd: !hd, 
 *  error: &ecode?
 * ): #[e: int] void
** *************************/
implement msdos_dir_unlink_pre (dir, inode, hd, error) = 
if inode_mutex_islocked (dir) && inode_mutex_islocked (inode) then let
  val t_dir = inode_get_file_type (dir)
  val t_file = inode_get_file_type (inode)
in
  if t_dir = FILE_TYPE_DIR && t_file = FILE_TYPE_FILE then let
    val o_entry = inode_get_entry_loc (inode, error)
  in
    if is_succ (error) then true else false
  end else false
end else false

/* *************************
 * fun msdos_dir_unlink_main (
 * 	dir: !inode, 
 *  name: name, 
 *  file: !inode, 
 *  hd: !hd, 
 *  error: &ecode? >> ecode e
 * ): #[e: int] void
** *************************/
implement msdos_dir_unlink_main (dir, inode, hd, error) = let
  val o_entry = inode_get_entry_loc (inode, error)
in
  if is_succ (error) then let
    val '(cid, bid, eid) = option_getval {'(cluster_id, block_id, dir_entry_id)} (o_entry)
    val blk_no = fat_cluster_id_to_block_id (cid) + bid
    
    prval vtag = tag_create ()
    // remove the dir_entry
    val (optt | o_rollback) = 
      hd_clear_dir_entry (vtag | hd, blk_no, eid, error) 
  in
    if is_succ (error) then let
      prval vtag = optt_unsucc (optt)
      val rollback1 = option_vt_getval {rollback_hd (1)} (o_rollback)
      // update father inode
      val time = get_cur_time ()
      val (vtag | rollback2) = inode_set_time (vtag | dir, time)
      // update the inode for the upper dir
      val (optt | o_rollback) = hd_write_inode (vtag | hd, dir, error)
    in
      if is_succ (error) then let
        prval vtag = optt_unsucc (optt)
        val rollback3 = option_vt_getval {rollback_ihd (3)} (o_rollback)

        // file still exists, but it cannot be lookuped anymore
        // because the dir_entry on the disk is removed. And corresponding
        // dentry in VFS will be deleted by by certain outer function.
        // Therefore we don't clear the content of the file here since
        // someone else may be using the file now.
        // But we neeed to clear the entry location stored inside the
        // inode, so that the read/write operation won't update the dir
        // entry for this inode any more.        
        val (vtag | rollback4) = inode_clear_entry_loc (vtag | inode)
        
        val (vtag | ret) = rollback4 (vtag | inode, error)
        val () = cloptr_free (rollback4)        
        val (vtag | ret) = rollback3 (vtag | dir, hd, error)
        val () = cloptr_free (rollback3)        
        val (vtag | ret) = rollback2 (vtag | dir, error)
        val () = cloptr_free (rollback2)        
        val (vtag | ret) = rollback1 (vtag | hd, error)
        val () = cloptr_free (rollback1)
        prval () = tag_free (vtag) 
      in 
      end else let  // hd_write_inode () failed
        prval vtag = optt_unfail (optt)
        val () = option_vt_removenil (o_rollback)
        val (vtag | ret) = rollback2 (vtag | dir, error)
        val () = cloptr_free (rollback2)
        val (vtag | ret) = rollback1 (vtag | hd, error)
        val () = cloptr_free (rollback1)
        prval () = tag_free (vtag)        
      in end
    end else let // hd_clear_dir_entry () failed
      prval vtag = optt_unfail (optt)
      val () = option_vt_removenil (o_rollback)
      prval () = tag_free (vtag)
    in
    end 
  end else let  // inode_get_entry_loc () failed  // todo this will not happen
  in abort (1) end
end

(* ************** ****************** *)

/* *************************
 * fun inode_dir_mkdir_pre (
 * 	dir: !inode, 
 *  name: name, 
 *  hd: !hd, 
 *  error: &ecode?
 * ): bool
** *************************/
implement inode_dir_mkdir_pre (dir, name, hd, error) =
if inode_mutex_islocked (dir) then let
  val t = inode_get_file_type (dir)
in
  if t = FILE_TYPE_DIR then let
    val opt_inode = inode_dir_lookup (dir, name, hd, error)
    val () = inode_opt_release (opt_inode)
  in
    if is_succ (error) then false else true
  end else false
end else false

/* *************************
 * fun inode_dir_mkdir_main (
 * 	dir: !inode, 
 *  name: name, 
 *  hd: !hd, 
 *  error: &ecode? >> ecode
 * ): #[e: int] option_vt (inode, e == 0)
** *************************/
implement inode_dir_mkdir_main (dir, name, hd, error) = let
  val fst_cid = inode_get_fst_cluster (dir)
  prval vtag = tag_create ()
  val (optt | o_rollback, o_entry) = 
    clusters_find_empty_entry_new (vtag | hd, fst_cid, error) 
in
  if is_succ (error) then let  // found empty dir entry
    prval vtag = optt_unsucc (optt)
    val rollback1 = option_vt_getval {rollback_hd (1)} (o_rollback)   // todo why must add type here
    val '(is_new, cid, bid, eid) = option_getval {'(bool, cluster_id, block_id, dir_entry_id)} (o_entry)   // todo why must add type here
    
    // update father inode
    val time = get_cur_time ()
    val (vtag | rollback2) = inode_set_time (vtag | dir, time)
    val file_size = inode_get_file_size (dir)

    val (vtag | rollback3) = (if is_new then inode_set_file_size (vtag | dir, file_size + CLS_SZ)
                             else inode_set_file_size (vtag | dir, file_size)): (tag 3 | rollback_inode 3)   // todo why must add type here
    val (optt | o_rollback) = hd_write_inode (vtag | hd, dir, error)  // update the inode for "dir"
  in
    if is_succ (error) then let
      prval vtag = optt_unsucc (optt)
      val rollback4 = option_vt_getval {rollback_ihd (4)} (o_rollback)   // todo why must add type here
      
      val (optt | o_cls, o_rollback) = fat_alloc_cluster (vtag | hd, CLS_PER_PAGE, error)
    in
      if is_succ (error) then let
        prval vtag = optt_unsucc (optt)
        val rollback5 = option_vt_getval {rollback_hd (5)} (o_rollback)   // todo why must add type here
        val '(fst_cls) = option_getval (o_cls)

        val blk_no = fat_cluster_id_to_block_id (cid) + bid
        val dentry = dir_entry_create (name, FILE_TYPE_DIR, fst_cls, PAGE_SIZE, time)
        // update the dir entry
        val (optt | o_rollback) = hd_set_dir_entry (vtag | hd, blk_no, eid, dentry, error)  
      in
        if is_succ (error) then let
          prval vtag = optt_unsucc (optt)
          val rollback6 = option_vt_getval {rollback_hd (6)} (o_rollback)
        
          val inode = inode_create_from_dir_entry (dentry)
          // todo "hack here" release all the cloptr
          val (vtag | ret) = rollback6 (vtag | hd, error)
          val () = cloptr_free (rollback6)
          val (vtag | ret) = rollback5 (vtag | hd, error)
          val () = cloptr_free (rollback5)
          val (vtag | ret) = rollback4 (vtag | dir, hd, error)
          val () = cloptr_free (rollback4)
          val (vtag | ret) = rollback3 (vtag | dir, error)
          val () = cloptr_free (rollback3)
          val (vtag | ret) = rollback2 (vtag | dir, error)
          val () = cloptr_free (rollback2)
          val (vtag | ret) = rollback1 (vtag | hd, error)
          val () = cloptr_free (rollback1)
          prval () = tag_free (vtag)
        in
          option_vt_make (inode)
        end else let
          prval vtag = optt_unfail (optt)
          val () = option_vt_removenil (o_rollback)                                          
          val (vtag | ret) = rollback5 (vtag | hd, error)
          val () = cloptr_free (rollback5)
          val (vtag | ret) = rollback4 (vtag | dir, hd, error)
          val () = cloptr_free (rollback4)
          val (vtag | ret) = rollback3 (vtag | dir, error)
          val () = cloptr_free (rollback3)
          val (vtag | ret) = rollback2 (vtag | dir, error)
          val () = cloptr_free (rollback2)
          val (vtag | ret) = rollback1 (vtag | hd, error)
          val () = cloptr_free (rollback1)
          prval () = tag_free (vtag)
        in
          option_vt_nil ()
        end
      end else let
        prval vtag = optt_unfail (optt)
        val () = option_vt_removenil (o_rollback)         
        val (vtag | ret) = rollback4 (vtag | dir, hd, error)
        val () = cloptr_free (rollback4)
        val (vtag | ret) = rollback3 (vtag | dir, error)
        val () = cloptr_free (rollback3)
        val (vtag | ret) = rollback2 (vtag | dir, error)
        val () = cloptr_free (rollback2)
        val (vtag | ret) = rollback1 (vtag | hd, error)
        val () = cloptr_free (rollback1)
        prval () = tag_free (vtag)
      in
        option_vt_nil ()
      end
    end else let
      prval vtag = optt_unfail (optt)
      val () = option_vt_removenil (o_rollback)         
      val (vtag | ret) = rollback3 (vtag | dir, error)
      val () = cloptr_free (rollback3)
      val (vtag | ret) = rollback2 (vtag | dir, error)
      val () = cloptr_free (rollback2)
      val (vtag | ret) = rollback1 (vtag | hd, error)
      val () = cloptr_free (rollback1)
      prval () = tag_free (vtag)
    in
      option_vt_nil ()
    end
  end else let
    prval vtag = optt_unfail (optt)
    val () = option_vt_removenil (o_rollback)  
    prval () = tag_free (vtag)
  in
    option_vt_nil ()
  end
end

/* *************************
 * fun inode_dir_rmdir_pre (
 * 	dir: !inode, 
 *  dirfile: !inode, 
 *  error: &ecode?
 * ): bool
** *************************/
implement inode_dir_rmdir_pre (dir, dirfile, hd, error) =
if inode_mutex_islocked (dir) && inode_mutex_islocked (dirfile) then let
  val t_dir = inode_get_file_type (dir)
  val t_dirfile = inode_get_file_type (dirfile)
in
  if t_dir = FILE_TYPE_DIR && t_dirfile = FILE_TYPE_DIR then let
    val o_entry = inode_get_entry_loc (dirfile, error)
  in
    if is_succ (error) then true else false
  end else false
end else false

/* *************************
 * fun inode_dir_rmdir_main (
 * 	dir: !inode, 
 *  dirfile: !inode, 
 *  error: &ecode? >> ecode e
 * ): #[e: int] void
** *************************/
implement inode_dir_rmdir_main (dir, dirfile, hd, error) = let
  val fst_cid = inode_get_fst_cluster (dirfile)
  val o_isempty = clusters_dir_empty (hd, fst_cid, error)
in
  if is_succ (error) then let
    val '(isempty) = option_getval (o_isempty)
  in
    if isempty then let
      val o_entry = inode_get_entry_loc (dirfile, error)
    in
      if is_succ (error) then let
        val '(cid, bid, eid) = option_getval {'(cluster_id, block_id, dir_entry_id)} (o_entry)
        val blk_no = fat_cluster_id_to_block_id (cid) + bid
    
        prval vtag = tag_create ()
        // remove the dir_entry
        val (optt | o_rollback) = 
          hd_clear_dir_entry (vtag | hd, blk_no, eid, error) 
      in
         if is_succ (error) then let
          prval vtag = optt_unsucc (optt)
          val rollback1 = option_vt_getval {rollback_hd (1)} (o_rollback)
          // update father inode
          val time = get_cur_time ()
          val (vtag | rollback2) = inode_set_time (vtag | dir, time)
          // update the inode for the upper dir
          val (optt | o_rollback) = hd_write_inode (vtag | hd, dir, error)
        in
          if is_succ (error) then let
            prval vtag = optt_unsucc (optt)
            val rollback3 = option_vt_getval {rollback_ihd (3)} (o_rollback)

            // file still exists, but it cannot be lookuped anymore
            // because the dir_entry on the disk is removed. And corresponding
            // dentry in VFS will be deleted by by certain outer function.
            // Therefore we don't clear the content of the file here since
            // someone else may be using the file now.
            // But we neeed to clear the entry location stored inside the
            // inode, so that the read/write operation won't update the dir
            // entry for this inode any more.        
            val (vtag | rollback4) = inode_clear_entry_loc (vtag | dirfile)
        
            val (vtag | ret) = rollback4 (vtag | dirfile, error)
            val () = cloptr_free (rollback4)   
            val (vtag | ret) = rollback3 (vtag | dir, hd, error)
            val () = cloptr_free (rollback3)        
            val (vtag | ret) = rollback2 (vtag | dir, error)
            val () = cloptr_free (rollback2)        
            val (vtag | ret) = rollback1 (vtag | hd, error)
            val () = cloptr_free (rollback1)
            prval () = tag_free (vtag) 
          in 
          end else let  // hd_write_inode () failed
            prval vtag = optt_unfail (optt)
            val () = option_vt_removenil (o_rollback)
            val (vtag | ret) = rollback2 (vtag | dir, error)
            val () = cloptr_free (rollback2)
            val (vtag | ret) = rollback1 (vtag | hd, error)
            val () = cloptr_free (rollback1)
            prval () = tag_free (vtag)        
          in end
        end else let // hd_clear_dir_entry () failed
          prval vtag = optt_unfail (optt)
          val () = option_vt_removenil (o_rollback)
          prval () = tag_free (vtag)
        in
        end
      end else let  // inode_get_entry_loc () failed  // todo this will not happen
      in 
        abort (1) 
      end
    end else let
      val () = ecode_set (error, ENOTEMPTY)
    in end
  end
end

extern fun inode_dir_rename_overwrite_pre (old_dir: !inode, old_ent: !inode, new_dir: !inode, new_ent: !inode, hd: !hd, error: &ecode?): bool
implement inode_dir_rename_overwrite_pre (old_dir, old_ent, new_dir, new_ent, hd, error) = let
  prval () = opt_some (new_ent)
  val check = inode_dir_rename_pre (old_dir, old_ent, new_dir, new_ent, option_nil (), true, hd, error)
  prval () = opt_unsome (new_ent)
in
  if check = false then false else let
    val new_ent_type = inode_get_file_type (new_ent)
  in
    if new_ent_type = FILE_TYPE_DIR then let
      val new_fst_cid = inode_get_fst_cluster (new_ent)
      val o_isempty = clusters_dir_empty (hd, new_fst_cid, error)
    in
      if ecode_is_succ (error) then let
        val '(isempty) = option_getval {'(bool)} (o_isempty)  
      in
        if isempty = false then false
        else true
      end else false
    end
    else true
  end
end

extern fun inode_dir_rename_overwrite (old_dir: !inode, old_ent: !inode, new_dir: !inode, new_ent: !inode, hd: !hd, error: &ecode? >> ecode e): #[e: int] void
extern fun inode_dir_rename_overwrite_main (old_dir: !inode, old_ent: !inode, new_dir: !inode, new_ent: !inode, hd: !hd, error: &ecode? >> ecode e): #[e: int] void

implement inode_dir_rename_overwrite_main (old_dir, old_ent, new_dir, new_ent, hd, error) = let
  val o_dentry = inode_get_entry (old_ent, hd, error)
in
  if is_succ (error) then let
    val old_dentry = option_getval (o_dentry)
  
    prval vtag = tag_create ()
    // clear the old entry
    val (optt | o_rollback) = inode_clear_entry (vtag | old_ent, hd, error)
  in
    if is_succ (error) then let
      prval vtag = optt_unsucc (optt)
      val rollback1_ihd = option_vt_getval {rollback_ihd (1)} (o_rollback)   // todo why must add type here
         
      val time = get_cur_time ()
      // update inode of old_dir
      val (vtag | rollback2_inode) = inode_set_time (vtag | old_dir, time)
      val (optt | o_rollback) = hd_write_inode (vtag | hd, old_dir, error)
    in
      if is_succ (error) then let
        prval vtag = optt_unsucc (optt)
        val rollback3_ihd = option_vt_getval {rollback_ihd (3)} (o_rollback)
        val o_dentry = inode_get_entry (new_ent, hd, error)
      in
        if is_succ (error) then let
          val new_dentry = option_getval (o_dentry)

          val name = dir_entry_get_name (old_dentry)
          val new_dentry = dir_entry_update_name (new_dentry, name)
          // todo update time
          
          // update the new entry
          val (optt | o_rollback) = inode_set_entry (vtag | new_ent, hd, new_dentry, error)
        in
          if is_succ (error) then let
            prval vtag = optt_unsucc (optt)
            val rollback4_ihd = option_vt_getval {rollback_ihd (4)} (o_rollback)
            
            // update inode of new_dir
            val (vtag | rollback5_inode) = inode_set_time (vtag | new_dir, time)
            val (optt | o_rollback) = hd_write_inode (vtag | hd, new_dir, error)
          in
            if is_succ (error) then let
              prval vtag = optt_unsucc (optt)
              val rollback6_ihd = option_vt_getval {rollback_ihd (6)} (o_rollback)
              
              val opt_loc = inode_get_entry_loc (new_ent, error)
            in
              if is_succ (error) then let
                val '(cid, bid, eid) = option_getval (opt_loc)
                
                // change the entry_loc
                val (vtag | rollback7_inode) = inode_set_entry_loc (vtag | old_ent, '(cid, bid, eid))
                val (vtag | rollback8_inode) = inode_clear_entry_loc (vtag | new_ent)
                
                val (vtag | ret) = rollback8_inode (vtag | new_ent, error)
                val () = cloptr_free (rollback8_inode)
                val (vtag | ret) = rollback7_inode (vtag | old_ent, error)
                val () = cloptr_free (rollback7_inode)
                val (vtag | ret) = rollback6_ihd (vtag | new_dir, hd, error)
                val () = cloptr_free (rollback6_ihd)
                val (vtag | ret) = rollback5_inode (vtag | new_dir, error)
                val () = cloptr_free (rollback5_inode)    
                val (vtag | ret) = rollback4_ihd (vtag | new_dir, hd, error)
                val () = cloptr_free (rollback4_ihd)                            
                val (vtag | ret) = rollback3_ihd (vtag | old_dir, hd, error)
                val () = cloptr_free (rollback3_ihd)                       
                val (vtag | ret) = rollback2_inode (vtag | old_dir, error)
                val () = cloptr_free (rollback2_inode)                
                val (vtag | ret) = rollback1_ihd (vtag | old_ent, hd, error)
                val () = cloptr_free (rollback1_ihd)
                prval () = tag_free (vtag)
              in end else let  // inode_get_entry_loc (new_ent, error) failed
                val (vtag | ret) = rollback6_ihd (vtag | new_dir, hd, error)
                val () = cloptr_free (rollback6_ihd)
                val (vtag | ret) = rollback5_inode (vtag | new_dir, error)
                val () = cloptr_free (rollback5_inode)    
                val (vtag | ret) = rollback4_ihd (vtag | new_dir, hd, error)
                val () = cloptr_free (rollback4_ihd)                            
                val (vtag | ret) = rollback3_ihd (vtag | old_dir, hd, error)
                val () = cloptr_free (rollback3_ihd)                       
                val (vtag | ret) = rollback2_inode (vtag | old_dir, error)
                val () = cloptr_free (rollback2_inode)                
                val (vtag | ret) = rollback1_ihd (vtag | old_ent, hd, error)
                val () = cloptr_free (rollback1_ihd)
                prval () = tag_free (vtag)
              in
                abort (1)
              end
            end else let  // hd_write_inode (vtag | hd, new_dir, error) failed
              prval vtag = optt_unfail (optt)
              val () = option_vt_removenil (o_rollback)

              val (vtag | ret) = rollback5_inode (vtag | new_dir, error)
              val () = cloptr_free (rollback5_inode)    
              val (vtag | ret) = rollback4_ihd (vtag | new_dir, hd, error)
              val () = cloptr_free (rollback4_ihd)                            
              val (vtag | ret) = rollback3_ihd (vtag | old_dir, hd, error)
              val () = cloptr_free (rollback3_ihd)                       
              val (vtag | ret) = rollback2_inode (vtag | old_dir, error)
              val () = cloptr_free (rollback2_inode)                
              val (vtag | ret) = rollback1_ihd (vtag | old_ent, hd, error)
              val () = cloptr_free (rollback1_ihd)
              prval () = tag_free (vtag)
            in end
          end else let // inode_set_entry (vtag | new_ent, hd, new_dentry, error) failed
            prval vtag = optt_unfail (optt)
            val () = option_vt_removenil (o_rollback)
 
            val (vtag | ret) = rollback3_ihd (vtag | old_dir, hd, error)
            val () = cloptr_free (rollback3_ihd)                       
            val (vtag | ret) = rollback2_inode (vtag | old_dir, error)
            val () = cloptr_free (rollback2_inode)                
            val (vtag | ret) = rollback1_ihd (vtag | old_ent, hd, error)
            val () = cloptr_free (rollback1_ihd)
            prval () = tag_free (vtag)   
          in end
        end else let // inode_get_entry (new_ent, hd, error) failed
            val (vtag | ret) = rollback3_ihd (vtag | old_dir, hd, error)
            val () = cloptr_free (rollback3_ihd)                       
            val (vtag | ret) = rollback2_inode (vtag | old_dir, error)
            val () = cloptr_free (rollback2_inode)                
            val (vtag | ret) = rollback1_ihd (vtag | old_ent, hd, error)
            val () = cloptr_free (rollback1_ihd)
            prval () = tag_free (vtag)    
        in end
      end else let // hd_write_inode (vtag | hd, old_dir, error) failed
        prval vtag = optt_unfail (optt)
        val () = option_vt_removenil (o_rollback)
        
        val (vtag | ret) = rollback2_inode (vtag | old_dir, error)
        val () = cloptr_free (rollback2_inode)                
        val (vtag | ret) = rollback1_ihd (vtag | old_ent, hd, error)
        val () = cloptr_free (rollback1_ihd)
        prval () = tag_free (vtag)
      in end            
    end else let  // inode_clear_entry (vtag | old_ent, hd, error) failed
      prval vtag = optt_unfail (optt)
      val () = option_vt_removenil (o_rollback)    
      prval () = tag_free (vtag)
    in end      
  end else () // inode_get_entry (old_ent, hd, error) failed
end
              
           
             
          

/* *************************
 * fun inode_dir_rename (
 * 	old_dir: !inode, 
 *  old_ent: !inode, 
 *  new_dir: !inode, 
 *  opt_new_ent: !opt (inode, b),
 *  opt_name: option (name, ~b),
 *  bexist: bool b,	
 *  hd: !hd,
 *  error: &ecode? >> ecode e
): #[e: int] void
** *************************/
// todo I didn't mention here that old_dir and new_dir are not the ancestor of each other.
implement inode_dir_rename_pre (old_dir, old_ent, new_dir, opt_new_ent, opt_name, bexist, hd, error) =
if  inode_mutex_islocked (old_dir) &&  inode_mutex_islocked (new_dir) then let
  val _ = inode_get_entry_loc (old_ent, error)
in
  if is_succ (error) then
    if bexist = false then let
      val name = option_getval (opt_name)
      val opt_inode = inode_dir_lookup (new_dir, name, hd, error)
      val () = inode_opt_release (opt_inode)
    in
      if is_succ (error) then false else true
    end else let
      prval () = opt_unsome {inode} (opt_new_ent)
      val is_locked = inode_mutex_islocked (opt_new_ent)
    in
      if is_locked = false then let
        val () = opt_some {inode} (opt_new_ent)
      in
        false 
      end else let
        val _ = inode_get_entry_loc (opt_new_ent, error)
      in
        if is_succ (error) then let
          val old_type = inode_get_file_type (old_ent)
          val new_type = inode_get_file_type (opt_new_ent)
          val cmp = inode_eq (old_ent, opt_new_ent)
       
          val () = opt_some {inode} (opt_new_ent)
        in
          if cmp then false else if old_type = new_type then true else false
        end else let
          prval () = opt_some {inode} (opt_new_ent)
        in false end
      end
    end
  else false
end else false
      

/* *************************
 * fun inode_dir_rename_main {b:bool}(
 * 	old_dir: !inode, 
 *  old_ent: !inode,	
 *  new_dir: !inode,	
 *  opt_new_ent: !opt (inode, b),
 *  opt_name: option (name, ~b),
 *  bexist: bool b,	
 *  hd: !hd,
 *  error: &ecode? >> ecode e
): #[e: int] void
** *************************/
implement inode_dir_rename_main {b} (old_dir, old_ent, new_dir, opt_new_ent, opt_name, bexist, hd, error) =
if  bexist = false then let  // target doesn't exist
  // dest doesn't exist
  val name = option_getval (opt_name)
  // get dir_entry location from inode
  val o_entry = inode_get_entry_loc (old_ent, error)
in
  if is_succ (error) then let
    val '(cid, bid, eid) = option_getval {'(cluster_id, block_id, dir_entry_id)} (o_entry)
    val blk_no = fat_cluster_id_to_block_id (cid) + bid
    // get the dir entry info
    val o_dentry = hd_get_dir_entry (hd, blk_no, eid, error)
  in
    if is_succ (error) then let
      val dentry = option_getval (o_dentry)
      // update the dir entry
      val dentry = dir_entry_update_name (dentry, name)        
      // val dentry = todo update time

      prval vtag = tag_create ()
      
      // clear the entry in the old directory
      val (optt | o_rollback) = hd_clear_dir_entry (vtag | hd, blk_no, eid, error)
    in
      if is_succ (error) then let
        prval vtag = optt_unsucc (optt)
        val rollback1_hd = option_vt_getval {rollback_hd (1)} (o_rollback)   // todo why must add type here
        
        val time = get_cur_time ()
        // update inode of old_dir
        val (vtag | rollback2_inode) = inode_set_time (vtag | old_dir, time)
        val (optt | o_rollback) = hd_write_inode (vtag | hd, old_dir, error)
      in
        if is_succ (error) then let
          prval vtag = optt_unsucc (optt)
          val rollback3_ihd = option_vt_getval {rollback_ihd (3)} (o_rollback)   // todo why must add type here
          
          val fst_cid = inode_get_fst_cluster (new_dir)
          // find slot in new directory
          val (optt | o_rollback, o_entry) = 
            clusters_find_empty_entry_new (vtag | hd, fst_cid, error) 
        in
          if is_succ (error) then let  // found empty dir entry
            prval vtag = optt_unsucc (optt)
            val rollback4_hd = option_vt_getval {rollback_hd (4)} (o_rollback)   // todo why must add type here
            val '(is_new, cid, bid, eid) = option_getval {'(bool, cluster_id, block_id, dir_entry_id)} (o_entry)   // todo why must add type here
          
            // write new entry into new dir
            val blk_no = fat_cluster_id_to_block_id (cid) + bid
            val (optt | o_rollback) = hd_set_dir_entry (vtag | hd, blk_no, eid, dentry, error)  
          in
            if is_succ (error) then let
              prval vtag = optt_unsucc (optt)
              val rollback5_hd = option_vt_getval {rollback_hd (5)} (o_rollback) // todo why must add type here
              
              // update inode of old_dir
              val (vtag | rollback6_inode) = inode_set_time (vtag | new_dir, time)
              val file_size = inode_get_file_size (new_dir)
              val (vtag | rollback7_inode) = (if is_new then inode_set_file_size (vtag | new_dir, file_size + CLS_SZ)
                                     else inode_set_file_size (vtag | new_dir, file_size)): (tag 7 | rollback_inode 7)   // todo why must add type here
              val (optt | o_rollback) = hd_write_inode (vtag | hd, new_dir, error)  // update the inode for "dir"
            in
              if is_succ (error) then let
                prval vtag = optt_unsucc (optt)
                val rollback8_ihd = option_vt_getval {rollback_ihd (8)} (o_rollback)   // todo why must add type here
  
                val (vtag | rollback9_inode) = inode_set_entry_loc (vtag | old_ent, '(cid, bid, eid))
                
                val (vtag | ret) = rollback9_inode (vtag | old_ent, error)
                val () = cloptr_free (rollback9_inode)   
                val (vtag | ret) = rollback8_ihd (vtag | new_dir, hd, error)
                val () = cloptr_free (rollback8_ihd)
                val (vtag | ret) = rollback7_inode (vtag | new_dir, error)
                val () = cloptr_free (rollback7_inode)                                             
                val (vtag | ret) = rollback6_inode (vtag | new_dir, error)
                val () = cloptr_free (rollback6_inode)
                val (vtag | ret) = rollback5_hd (vtag | hd, error)
                val () = cloptr_free (rollback5_hd)
                val (vtag | ret) = rollback4_hd (vtag | hd, error)
                val () = cloptr_free (rollback4_hd)
                val (vtag | ret) = rollback3_ihd (vtag | old_dir, hd, error)
                val () = cloptr_free (rollback3_ihd)
                val (vtag | ret) = rollback2_inode (vtag | old_dir, error)
                val () = cloptr_free (rollback2_inode)
                val (vtag | ret) = rollback1_hd (vtag | hd, error)
                val () = cloptr_free (rollback1_hd)
                prval () = tag_free (vtag)
              in end else let
                prval vtag = optt_unfail (optt)
                val () = option_vt_removenil (o_rollback)
                
                val (vtag | ret) = rollback7_inode (vtag | new_dir, error)
                val () = cloptr_free (rollback7_inode)                                             
                val (vtag | ret) = rollback6_inode (vtag | new_dir, error)
                val () = cloptr_free (rollback6_inode)
                val (vtag | ret) = rollback5_hd (vtag | hd, error)
                val () = cloptr_free (rollback5_hd)
                val (vtag | ret) = rollback4_hd (vtag | hd, error)
                val () = cloptr_free (rollback4_hd)
                val (vtag | ret) = rollback3_ihd (vtag | old_dir, hd, error)
                val () = cloptr_free (rollback3_ihd)
                val (vtag | ret) = rollback2_inode (vtag | old_dir, error)
                val () = cloptr_free (rollback2_inode)
                val (vtag | ret) = rollback1_hd (vtag | hd, error)
                val () = cloptr_free (rollback1_hd)
                prval () = tag_free (vtag)
              in end
            end else let
              prval vtag = optt_unfail (optt)
              val () = option_vt_removenil (o_rollback)

              val (vtag | ret) = rollback4_hd (vtag | hd, error)
              val () = cloptr_free (rollback4_hd)
              val (vtag | ret) = rollback3_ihd (vtag | old_dir, hd, error)
              val () = cloptr_free (rollback3_ihd)
              val (vtag | ret) = rollback2_inode (vtag | old_dir, error)
              val () = cloptr_free (rollback2_inode)
              val (vtag | ret) = rollback1_hd (vtag | hd, error)
              val () = cloptr_free (rollback1_hd)
              prval () = tag_free (vtag)
            in end
          end else let           
            prval vtag = optt_unfail (optt)
            val () = option_vt_removenil (o_rollback)

            val (vtag | ret) = rollback3_ihd (vtag | old_dir, hd, error)
            val () = cloptr_free (rollback3_ihd)
            val (vtag | ret) = rollback2_inode (vtag | old_dir, error)
            val () = cloptr_free (rollback2_inode)
            val (vtag | ret) = rollback1_hd (vtag | hd, error)
            val () = cloptr_free (rollback1_hd)
            prval () = tag_free (vtag)
          in end
        end else let  // hd_clear_dir_entry (vtag | hd, blk_no, eid, error) failed. 
          prval vtag = optt_unfail (optt)
          val () = option_vt_removenil (o_rollback)

          val (vtag | ret) = rollback2_inode (vtag | old_dir, error)
          val () = cloptr_free (rollback2_inode)
          val (vtag | ret) = rollback1_hd (vtag | hd, error)
          val () = cloptr_free (rollback1_hd)
          prval () = tag_free (vtag)
        in end
      end else let
        prval vtag = optt_unfail (optt)
        val () = option_vt_removenil (o_rollback)

        prval () = tag_free (vtag)
      in end
    end else ()  // hd_get_dir_entry (hd, blk_no, eid, error) failed.
  end else abort (1)  // inode_get_entry_loc (old_ent, error) ailed. this shall not happen
end else let  // bexist = true
  prval () = opt_unsome (opt_new_ent)
  val new_ent_type = inode_get_file_type (opt_new_ent)
in
  if new_ent_type = FILE_TYPE_DIR then let
    val new_fst_cid = inode_get_fst_cluster (opt_new_ent)
    val o_isempty = clusters_dir_empty (hd, new_fst_cid, error)
  in
    if is_succ (error) then let
      val '(isempty) = option_getval (o_isempty)  
    in
      if isempty = false then let
        val () = ecode_set (error, ENOTEMPTY)
        prval () = opt_some (opt_new_ent)
      in end
      else let
        val () = inode_dir_rename_overwrite (old_dir, old_ent, new_dir, opt_new_ent, hd, error)
        prval () = opt_some (opt_new_ent)
      in end
    end
    else let
      prval () = opt_some (opt_new_ent)
    in end
  end
  else let
    val () = inode_dir_rename_overwrite (old_dir, old_ent, new_dir, opt_new_ent, hd, error)
    prval () = opt_some (opt_new_ent)
  in end  
end
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
  
  
  
  
  
  
  
