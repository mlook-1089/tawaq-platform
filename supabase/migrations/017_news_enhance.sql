-- Migration 017: News enhance & news storage
ALTER TABLE public.news ADD COLUMN IF NOT EXISTS pinned BOOLEAN DEFAULT FALSE;
ALTER TABLE public.news ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE public.news ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.news ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.news ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.users(id);

CREATE INDEX IF NOT EXISTS idx_news_pinned_date ON public.news(pinned DESC, published_at DESC) WHERE deleted_at IS NULL;

-- Ensure RLS is active on news
ALTER TABLE public.news ENABLE ROW LEVEL SECURITY;

-- Ensure read and write policies
DROP POLICY IF EXISTS "news_read" ON public.news;
CREATE POLICY "news_read" ON public.news
  FOR SELECT TO authenticated
  USING (deleted_at IS NULL);

DROP POLICY IF EXISTS "news_write" ON public.news;
CREATE POLICY "news_write" ON public.news
  FOR ALL TO authenticated
  USING (public.is_admin() OR public.has_role('mod_media'::app_role))
  WITH CHECK (public.is_admin() OR public.has_role('mod_media'::app_role));

-- Storage bucket: news
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'news',
  'news',
  true,
  5242880, -- 5MB max
  ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/svg+xml']
)
ON CONFLICT (id) DO UPDATE
SET public = true,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage policies for news
DROP POLICY IF EXISTS "Public news read" ON storage.objects;
CREATE POLICY "Public news read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'news');

DROP POLICY IF EXISTS "Media and admin can upload news images" ON storage.objects;
CREATE POLICY "Media and admin can upload news images"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'news' AND (
      public.is_admin() OR public.has_role('mod_media'::app_role)
    )
  );

DROP POLICY IF EXISTS "Media and admin can update news images" ON storage.objects;
CREATE POLICY "Media and admin can update news images"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'news' AND (
      public.is_admin() OR public.has_role('mod_media'::app_role)
    )
  );

DROP POLICY IF EXISTS "Media and admin can delete news images" ON storage.objects;
CREATE POLICY "Media and admin can delete news images"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'news' AND (
      public.is_admin() OR public.has_role('mod_media'::app_role)
    )
  );
