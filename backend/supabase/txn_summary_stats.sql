-- This file is autogenerated from regen-schema.ts
create table if not exists
  txn_summary_stats (
    category text not null,
    created_time timestamp with time zone default now() not null,
    end_time timestamp with time zone not null,
    from_type text not null,
    id bigint primary key generated always as identity not null,
    quest_type text,
    start_time timestamp with time zone not null,
    to_type text not null,
    token text not null,
    total_amount numeric not null
  );

-- Row Level Security
alter table txn_summary_stats enable row level security;

-- Policies
drop policy if exists "public read" on txn_summary_stats;

create policy "public read" on txn_summary_stats for
select
  using (true);

-- Indexes
drop index if exists txn_summary_stats_pkey;

create unique index txn_summary_stats_pkey on public.txn_summary_stats using btree (id);
