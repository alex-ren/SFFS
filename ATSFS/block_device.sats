


abstype block_device

fun get_block_device (): block_device

fun read_block_device (dev: block_device, n: int): option0 (list0 char)
fun write_block_device (dev: block_device, n: int, blk: list0 char): bool