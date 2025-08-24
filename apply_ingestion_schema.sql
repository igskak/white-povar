-- Ingestion system tables for Recipe Processing Pipeline
-- Apply these SQL commands to your Supabase database

-- Enable UUID extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table to track recipe ingestion jobs and their status
CREATE TABLE IF NOT EXISTS ingestion_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_path TEXT NOT NULL,
    original_filename TEXT,
    file_size_bytes BIGINT,
    mime_type TEXT,
    status TEXT NOT NULL CHECK (status IN ('PENDING', 'PROCESSING', 'NEEDS_REVIEW', 'COMPLETED', 'FAILED', 'DLQ', 'COMPLETED_DUPLICATE')),
    error_message TEXT,
    retries INTEGER DEFAULT 0,
    confidence_score NUMERIC(3,2), -- 0.00 to 1.00
    recipe_id UUID REFERENCES recipes(id),
    duplicate_of_recipe_id UUID REFERENCES recipes(id),
    meta JSONB, -- stores detected_lang, token_usage, costs, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    reviewer_notes TEXT
);

-- Table for recipe fingerprinting to detect duplicates
CREATE TABLE IF NOT EXISTS recipe_fingerprints (
    recipe_id UUID PRIMARY KEY REFERENCES recipes(id) ON DELETE CASCADE,
    title_normalized TEXT NOT NULL,
    cuisine_normalized TEXT,
    total_time_minutes INTEGER,
    fingerprint_hash TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table for manual review decisions (optional but useful for audit)
CREATE TABLE IF NOT EXISTS ingestion_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES ingestion_jobs(id) ON DELETE CASCADE,
    reviewer_id UUID, -- could reference users/admins table if you have one
    decision TEXT NOT NULL CHECK (decision IN ('APPROVED', 'REJECTED', 'NEEDS_REVISION')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_ingestion_jobs_status ON ingestion_jobs(status);
CREATE INDEX IF NOT EXISTS idx_ingestion_jobs_created_at ON ingestion_jobs(created_at);
CREATE INDEX IF NOT EXISTS idx_recipe_fingerprints_hash ON recipe_fingerprints(fingerprint_hash);
CREATE INDEX IF NOT EXISTS idx_recipe_fingerprints_normalized ON recipe_fingerprints(title_normalized, cuisine_normalized);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for ingestion_jobs updated_at
DROP TRIGGER IF EXISTS update_ingestion_jobs_updated_at ON ingestion_jobs;
CREATE TRIGGER update_ingestion_jobs_updated_at 
    BEFORE UPDATE ON ingestion_jobs 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
