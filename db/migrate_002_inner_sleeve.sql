-- Migration 002: add inner sleeve photo types
ALTER TYPE photo_type ADD VALUE IF NOT EXISTS 'inner_sleeve_front';
ALTER TYPE photo_type ADD VALUE IF NOT EXISTS 'inner_sleeve_back';
