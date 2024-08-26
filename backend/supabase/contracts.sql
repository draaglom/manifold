-- This file is autogenerated from regen-schema.ts
create table if not exists
  contracts (
    id text not null,
    data jsonb not null,
    slug text,
    question text,
    creator_id text,
    visibility text,
    mechanism text,
    outcome_type text,
    created_time timestamp with time zone,
    close_time timestamp with time zone,
    resolution_time timestamp with time zone,
    resolution_probability numeric,
    resolution text,
    popularity_score numeric default 0 not null,
    question_fts tsvector generated always as (to_tsvector('english'::regconfig, question)) stored,
    description_fts tsvector generated always as (
      to_tsvector(
        'english'::regconfig,
        add_creator_name_to_description (data)
      )
    ) stored,
    question_nostop_fts tsvector generated always as (
      to_tsvector('english_nostop_with_prefix'::regconfig, question)
    ) stored,
    importance_score numeric default 0 not null,
    deleted boolean default false,
    group_slugs text[],
    last_updated_time timestamp with time zone,
    last_bet_time timestamp with time zone,
    last_comment_time timestamp with time zone,
    freshness_score numeric default 0 not null,
    conversion_score numeric default 0 not null,
    view_count bigint default 0 not null,
    is_spice_payout boolean default false,
    unique_bettor_count bigint default 0 not null,
    tier text,
    daily_score numeric default 0 not null,
    token text default 'MANA'::character varying not null,
    constraint contracts_token_check check (
      (
        token = any (
          array[
            ('MANA'::character varying)::text,
            ('CASH'::character varying)::text
          ]
        )
      )
    )
  );

-- Triggers
create trigger contract_populate before insert
or
update on public.contracts for each row
execute function contract_populate_cols ();

create trigger sync_sibling_contract_trigger
after
update on public.contracts for each row
execute function sync_sibling_contract ();

-- Functions
create
or replace function public.contract_populate_cols () returns trigger language plpgsql as $function$
begin
  if new.data is not null then
  new.slug := (new.data) ->> 'slug';
  new.question := (new.data) ->> 'question';
  new.creator_id := (new.data) ->> 'creatorId';
  new.visibility := (new.data) ->> 'visibility';
  new.mechanism := (new.data) ->> 'mechanism';
  new.outcome_type := (new.data) ->> 'outcomeType';
  new.unique_bettor_count := ((new.data) -> 'uniqueBettorCount')::bigint;
  new.tier := (new.data) ->> 'marketTier';
  new.created_time := case
      when new.data ? 'createdTime' then millis_to_ts(((new.data) ->> 'createdTime')::bigint)
      else null
    end;
  new.close_time := case
      when new.data ? 'closeTime' then millis_to_ts(((new.data) ->> 'closeTime')::bigint)
      else null
    end;
  new.resolution_time := case
      when new.data ? 'resolutionTime' then millis_to_ts(((new.data) ->> 'resolutionTime')::bigint)
      else null
    end;
  new.resolution_probability := ((new.data) ->> 'resolutionProbability')::numeric;
  new.resolution := (new.data) ->> 'resolution';
  new.is_spice_payout := coalesce(((new.data) ->> 'isSpicePayout')::boolean, false);
  new.popularity_score := coalesce(((new.data) ->> 'popularityScore')::numeric, 0);
  new.deleted := coalesce(((new.data) ->> 'deleted')::boolean, false);
  new.group_slugs := case
      when new.data ? 'groupSlugs' then jsonb_array_to_text_array((new.data) -> 'groupSlugs')
      else null
    end;
  new.last_updated_time := case
      when new.data ? 'lastUpdatedTime' then millis_to_ts(((new.data) ->> 'lastUpdatedTime')::bigint)
      else null
    end;
  new.last_bet_time := case
      when new.data ? 'lastBetTime' then millis_to_ts(((new.data) ->> 'lastBetTime')::bigint)
      else null
    end;
  new.last_comment_time := case
      when new.data ? 'lastCommentTime' then millis_to_ts(((new.data) ->> 'lastCommentTime')::bigint)
      else null
    end;
  end if;
  return new;
end
$function$;

create
or replace function public.sync_sibling_contract () returns trigger language plpgsql as $function$
begin
  if new.token = 'MANA' and (new.data->>'siblingContractId') is not null
    and (old.data->>'closeTime' != new.data->>'closeTime' or old.data->>'deleted' != new.data->>'deleted') then
  update contracts
  set data = data || jsonb_build_object(
    'closeTime', new.data->'closeTime',
    'deleted', new.data->'deleted'
  )
  where id = (new.data->>'siblingContractId')::text;
  end if;
  return new;
end;
$function$;

-- Policies
alter table contracts enable row level security;

drop policy if exists "public read" on contracts;

create policy "public read" on contracts for
select
  using (true);

-- Indexes
drop index if exists contracts_pkey;

create unique index contracts_pkey on public.contracts using btree (id);

drop index if exists contracts_close_time;

create index contracts_close_time on public.contracts using btree (close_time desc);

drop index if exists contracts_created_time;

create index contracts_created_time on public.contracts using btree (created_time desc);

drop index if exists contracts_creator_id;

create index contracts_creator_id on public.contracts using btree (creator_id, created_time);

drop index if exists contracts_elasticity;

create index contracts_elasticity on public.contracts using btree ((((data ->> 'elasticity'::text))::numeric) desc);

drop index if exists contracts_freshness_score;

create index contracts_freshness_score on public.contracts using btree (freshness_score desc);

drop index if exists contracts_group_slugs_importance;

create index contracts_group_slugs_importance on public.contracts using gin (group_slugs, importance_score);

drop index if exists contracts_importance_score;

create index contracts_importance_score on public.contracts using btree (importance_score desc);

drop index if exists contracts_last_bet_time;

create index contracts_last_bet_time on public.contracts using btree (last_bet_time desc nulls last);

drop index if exists contracts_last_comment_time;

create index contracts_last_comment_time on public.contracts using btree (last_comment_time desc nulls last);

drop index if exists contracts_last_updated_time;

create index contracts_last_updated_time on public.contracts using btree (last_updated_time desc nulls last);

drop index if exists contracts_outcome_type_binary;

create index contracts_outcome_type_binary on public.contracts using btree (outcome_type)
where
  (outcome_type = 'BINARY'::text);

drop index if exists contracts_outcome_type_not_binary;

create index contracts_outcome_type_not_binary on public.contracts using btree (outcome_type)
where
  (outcome_type <> 'BINARY'::text);

drop index if exists contracts_resolution_time;

create index contracts_resolution_time on public.contracts using btree (resolution_time desc);

drop index if exists contracts_slug;

create index contracts_slug on public.contracts using btree (slug);

drop index if exists contracts_visibility_public;

create index contracts_visibility_public on public.contracts using btree (id)
where
  (visibility = 'public'::text);

drop index if exists contracts_volume_24_hours;

create index contracts_volume_24_hours on public.contracts using btree (
  (((data ->> 'volume24Hours'::text))::numeric) desc
);

drop index if exists description_fts;

create index description_fts on public.contracts using gin (description_fts);

drop index if exists question_fts;

create index question_fts on public.contracts using gin (question_fts);

drop index if exists question_nostop_fts;

create index question_nostop_fts on public.contracts using gin (question_nostop_fts);

drop index if exists market_tier_idx;

create index market_tier_idx on public.contracts using btree (tier);

drop index if exists contracts_daily_score;

create index contracts_daily_score on public.contracts using btree (daily_score desc);
