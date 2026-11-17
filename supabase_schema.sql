-- ==============================================================
-- PnumaDesk Manager - Core Database Schema
-- Run this in your PnumaDesk Manager Supabase database (both Dev and Live)
-- ==============================================================

-- 1. Users Table
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'unknown' CHECK (role IN ('super_admin', 'admin', 'unknown')),
    mobile TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Projects Table
CREATE TABLE IF NOT EXISTS public.projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Databases Table (One project can have many databases)
CREATE TABLE IF NOT EXISTS public.project_databases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    db_name TEXT NOT NULL,
    supabase_url TEXT,
    supabase_service_role_key TEXT,
    supabase_anon_key TEXT,
    db_password TEXT,
    db_host TEXT,
    sms_provider TEXT,
    notify_base_url TEXT,
    notify_api_key TEXT,
    notify_user_id TEXT,
    notify_sender_id TEXT,
    r2_access_key TEXT,
    r2_secret_key TEXT,
    r2_endpoint TEXT,
    r2_public_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Notifications Table (User-wise and Role-wise)
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'info', -- 'info', 'warning', 'success', 'error'
    target_role TEXT, -- e.g. 'super_admin', 'admin', or NULL for all
    target_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE, -- specific user or NULL
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Activity Logs Table
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    username TEXT,
    action TEXT NOT NULL, -- e.g. 'LOGIN', 'CREATE_PROJECT', 'CONNECT_DATABASE', etc.
    details TEXT,
    entity_type TEXT,
    entity_id TEXT,
    ip_address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
