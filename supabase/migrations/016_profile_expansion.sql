-- Migration 016: Profile expansion & avatars storage
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS bio TEXT CHECK (bio IS NULL OR LENGTH(bio) <= 500);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS interests TEXT[];
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS birthday DATE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS region TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS profession TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS social JSONB DEFAULT '{}'::jsonb;

-- Storage bucket: avatars
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  2097152, -- 2MB max
  ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/svg+xml']
)
ON CONFLICT (id) DO UPDATE
SET public = true,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage policies for avatars
DROP POLICY IF EXISTS "Public avatars read" ON storage.objects;
CREATE POLICY "Public avatars read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars' AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR split_part(name, '/', 1) = auth.uid()::text
      OR split_part(name, '.', 1) = auth.uid()::text
      OR public.is_admin()
    )
  );

DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars' AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR split_part(name, '/', 1) = auth.uid()::text
      OR split_part(name, '.', 1) = auth.uid()::text
      OR public.is_admin()
    )
  );

DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
CREATE POLICY "Users can delete own avatar"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars' AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR split_part(name, '/', 1) = auth.uid()::text
      OR split_part(name, '.', 1) = auth.uid()::text
      OR public.is_admin()
    )
  );
