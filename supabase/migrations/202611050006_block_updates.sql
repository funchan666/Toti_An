create trigger directory_block_changed after insert or delete on public.user_blocks
for each statement execute function private.mark_directory_changed();
