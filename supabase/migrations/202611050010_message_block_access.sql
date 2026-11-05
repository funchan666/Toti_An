create function private.message_is_visible(sender uuid, recipient uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) in (sender, recipient)
    and not exists (select 1 from public.user_blocks b where
      (b.blocker_id = sender and b.blocked_id = recipient) or
      (b.blocker_id = recipient and b.blocked_id = sender));
$$;
revoke all on function private.message_is_visible(uuid,uuid) from public, anon;
grant execute on function private.message_is_visible(uuid,uuid) to authenticated;
drop policy messages_participants_read on public.direct_messages;
create policy messages_participants_read on public.direct_messages for select to authenticated
  using ((select private.message_is_visible(sender_id, recipient_id)));
