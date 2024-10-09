-- This file is autogenerated from regen-schema.ts
create table if not exists
  manachan_tweets (
    cost numeric,
    created_time numeric,
    id text primary key default uuid_generate_v4 () not null,
    tweet text,
    tweet_id text,
    user_id text,
    username text
  );

-- Row Level Security
alter table manachan_tweets enable row level security;

-- Policies
drop policy if exists "Enable read access for all users" on manachan_tweets;

create policy "Enable read access for all users" on manachan_tweets for
select
  using (true);

-- Indexes
drop index if exists manachan_tweets_pkey;

create unique index manachan_tweets_pkey on public.manachan_tweets using btree (id);
