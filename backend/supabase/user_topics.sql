-- This file is autogenerated from regen-schema.ts
create table if not exists
  user_topics (
    created_at timestamp without time zone default now() not null,
    topic_embedding vector (1536) not null,
    topics text[] not null,
    user_id text primary key not null
  );

-- Row Level Security
alter table user_topics enable row level security;

-- Policies
drop policy if exists "public read" on user_topics;

create policy "public read" on user_topics for
select
  using (true);

drop policy if exists "public write access" on user_topics;

create policy "public write access" on user_topics for insert
with
  check (true);

-- Indexes
drop index if exists user_topics_pkey;

create unique index user_topics_pkey on public.user_topics using btree (user_id);
