-- This file is autogenerated from regen-schema.ts
create table if not exists
  group_groups (
    bottom_id text not null,
    top_id text not null,
    constraint primary key (top_id, bottom_id)
  );

-- Foreign Keys
alter table group_groups
add constraint group_groups_bottom_id_fkey foreign key (bottom_id) references groups (id) on update cascade on delete cascade;

alter table group_groups
add constraint group_groups_top_id_fkey foreign key (top_id) references groups (id) on update cascade on delete cascade;

-- Row Level Security
alter table group_groups enable row level security;

-- Policies
drop policy if exists "public read" on group_groups;

create policy "public read" on group_groups for
select
  using (true);

-- Indexes
drop index if exists group_groups_top_id_bottom_id_pkey;

create unique index group_groups_top_id_bottom_id_pkey on public.group_groups using btree (top_id, bottom_id);