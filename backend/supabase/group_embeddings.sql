-- This file is autogenerated from regen-schema.ts
create table if not exists
  group_embeddings (
    created_time timestamp without time zone default now() not null,
    embedding vector (1536) not null,
    group_id text primary key not null
  );

-- Foreign Keys
alter table group_embeddings
add constraint public_group_embeddings_group_id_fkey foreign key (group_id) references groups (id) on update cascade on delete cascade;

-- Row Level Security
alter table group_embeddings enable row level security;

-- Policies
drop policy if exists "admin write access" on group_embeddings;

create policy "admin write access" on group_embeddings for all to service_role;

drop policy if exists "public read" on group_embeddings;

create policy "public read" on group_embeddings for
select
  using (true);

-- Indexes
drop index if exists group_embeddings_pkey;

create unique index group_embeddings_pkey on public.group_embeddings using btree (group_id);
