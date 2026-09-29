---
// src/env.d.ts — TypeScript declarations for environment variables.
/// <reference types="astro/client" />

interface ImportMetaEnv {
  readonly PUBLIC_SITE_URL: string;
  readonly PUBLIC_BUSINESS_NAME: string;
  readonly PUBLIC_SUPABASE_URL: string;
  readonly PUBLIC_SUPABASE_ANON_KEY: string;
  readonly PUBLIC_SUPABASE_BUCKET_PRODUCTS: string;
  readonly PUBLIC_SUPABASE_BUCKET_SPECIMENS: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
