

abst@ype MODE  // mkdir, mkdirat - make a directory relative to directory file descriptor
               // sys/stat.h - data returned by the stat() function
               
abstype NAME
typedef PATH = list0 NAME

abst@ype FILE

abst@ype ERROR

abst@ype string

//fun open (path: PATH, oflag: OFLAG, mode: MODE): [ret: bool](bool ret, option (FILE, ret), option (ERROR, ~ret))
fun open (path: PATH, oflag: OFLAG, mode: MODE): option0 FILE

// read out the whole content of the file, 
(* *** 
Input:
  $
	
	
*** *)
fun read (f: FILE): option0 string

fun write (f: FILE, s: string): bool




