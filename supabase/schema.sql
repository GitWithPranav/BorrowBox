create extension if not exists "uuid-ossp";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  course text default '',
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.items (
  id uuid primary key default uuid_generate_v4(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text not null default '',
  category text not null,
  condition text not null default 'Good',
  location text not null default '',
  image_url text,
  is_available boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.borrow_requests (
  id uuid primary key default uuid_generate_v4(),
  item_id uuid not null references public.items(id) on delete cascade,
  borrower_id uuid not null references public.profiles(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  message text default '',
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'returned')),
  due_date date,
  created_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id uuid primary key default uuid_generate_v4(),
  request_id uuid not null unique references public.borrow_requests(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  reviewee_id uuid not null references public.profiles(id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  comment text default '',
  created_at timestamptz not null default now()
);

create or replace function public.set_request_owner()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  select owner_id into new.owner_id from public.items where id = new.item_id;
  return new;
end;
$$;

drop trigger if exists set_borrow_request_owner on public.borrow_requests;
create trigger set_borrow_request_owner before insert on public.borrow_requests for each row execute procedure public.set_request_owner();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name) values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.items enable row level security;
alter table public.borrow_requests enable row level security;
alter table public.reviews enable row level security;

drop policy if exists "Profiles are public" on public.profiles;
create policy "Profiles are public" on public.profiles for select using (true);
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile" on public.profiles for update using (auth.uid() = id);

drop policy if exists "Anyone can browse items" on public.items;
create policy "Anyone can browse items" on public.items for select using (true);
drop policy if exists "Users create own items" on public.items;
create policy "Users create own items" on public.items for insert with check (auth.uid() = owner_id);
drop policy if exists "Users update own items" on public.items;
create policy "Users update own items" on public.items for update using (auth.uid() = owner_id);
drop policy if exists "Users delete own items" on public.items;
create policy "Users delete own items" on public.items for delete using (auth.uid() = owner_id);

drop policy if exists "Users view relevant requests" on public.borrow_requests;
create policy "Users view relevant requests" on public.borrow_requests for select using (auth.uid() = borrower_id or auth.uid() = owner_id);
drop policy if exists "Borrowers create requests" on public.borrow_requests;
create policy "Borrowers create requests" on public.borrow_requests for insert with check (auth.uid() = borrower_id and owner_id = (select owner_id from public.items where id = item_id));
drop policy if exists "Owners update requests" on public.borrow_requests;
create policy "Owners update requests" on public.borrow_requests for update using (auth.uid() = owner_id);

drop policy if exists "Reviews are public" on public.reviews;
create policy "Reviews are public" on public.reviews for select using (true);
drop policy if exists "Users create reviews" on public.reviews;
create policy "Users create reviews" on public.reviews for insert with check (auth.uid() = reviewer_id);

insert into storage.buckets (id, name, public) values ('item-images', 'item-images', true) on conflict (id) do nothing;
create policy "Public item images" on storage.objects for select using (bucket_id = 'item-images');
create policy "Users upload item images" on storage.objects for insert with check (bucket_id = 'item-images' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "Users delete item images" on storage.objects for delete using (bucket_id = 'item-images' and auth.uid()::text = (storage.foldername(name))[1]);
