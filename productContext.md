# Product Context

## Problem
Chefs need a white-label app to publish recipes, manage branding, and engage users across mobile and web.

## Solution
- Flutter app connected to Supabase (DB, storage, real-time) and Firebase (auth/hosting)
- FastAPI backend integrates with Supabase and verifies Firebase tokens

## Users & Objectives
- Chefs: manage recipes, images, and app theme
- End users: authenticate, browse, search, and save favorites

## Current Status (2025-08-11)
- Backend configured with real Supabase and Firebase credentials
- Frontend connected to Supabase via `supabase_flutter`; Firebase initialized
- App builds; runtime config supplied via `--dart-define`
