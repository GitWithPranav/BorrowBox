# BorrowBox

BorrowBox is a React + Vite campus sharing app for borrowing and lending useful items.

## Run locally

1. Create a Supabase project.
2. Run [supabase/schema.sql](supabase/schema.sql) in the Supabase SQL editor.
3. Copy `.env.example` to `.env` and add your Supabase URL and anon key.
4. Run `npm run dev`.

The app shows a preview catalog until Supabase environment variables are configured. Once connected, authentication, listings, image uploads, requests, owner decisions, and activity are persisted in Supabase.

## Stack

- React 19 + Vite
- Supabase Auth, PostgreSQL, Storage, and Realtime-ready tables
- Lucide icons
