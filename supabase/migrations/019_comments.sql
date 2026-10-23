-- Migration 019: Comments, mentions, and reactions
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'comment_mention';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'comment_reply';

CREATE TABLE IF NOT EXISTS public.comments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type     TEXT NOT NULL CHECK (entity_type IN ('event','news','pool','claim','suggestion')),
  entity_id       UUID NOT NULL,
  user_id         UUID NOT NULL REFERENCES public.users(id),
  parent_id       UUID REFERENCES public.comments(id) ON DELETE CASCADE,
  body            TEXT NOT NULL CHECK (LENGTH(body) BETWEEN 1 AND 1000),
  mentions        UUID[] DEFAULT '{}'::uuid[],
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.comment_reactions (
  comment_id      UUID NOT NULL REFERENCES public.comments(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES public.users(id),
  reaction        TEXT NOT NULL CHECK (reaction IN ('thumbs_up','pray','heart','fire')),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (comment_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_comments_entity ON public.comments(entity_type, entity_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_parent ON public.comments(parent_id);

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comment_reactions ENABLE ROW LEVEL SECURITY;

-- Comments policies
DROP POLICY IF EXISTS "comments_select" ON public.comments;
CREATE POLICY "comments_select" ON public.comments
  FOR SELECT TO authenticated
  USING (deleted_at IS NULL);

DROP POLICY IF EXISTS "comments_insert" ON public.comments;
CREATE POLICY "comments_insert" ON public.comments
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "comments_update" ON public.comments;
CREATE POLICY "comments_update" ON public.comments
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() OR public.is_admin())
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "comments_delete" ON public.comments;
CREATE POLICY "comments_delete" ON public.comments
  FOR DELETE TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

-- Comment reactions policies
DROP POLICY IF EXISTS "reactions_select" ON public.comment_reactions;
CREATE POLICY "reactions_select" ON public.comment_reactions
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "reactions_insert" ON public.comment_reactions;
CREATE POLICY "reactions_insert" ON public.comment_reactions
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "reactions_update" ON public.comment_reactions;
CREATE POLICY "reactions_update" ON public.comment_reactions
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "reactions_delete" ON public.comment_reactions;
CREATE POLICY "reactions_delete" ON public.comment_reactions
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- Trigger for comment notifications
CREATE OR REPLACE FUNCTION public.handle_comment_notifications()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_author_name TEXT;
  v_mention_id UUID;
  v_parent_author_id UUID;
BEGIN
  -- Get author name
  SELECT full_name INTO v_author_name FROM public.users WHERE id = NEW.user_id;
  v_author_name := COALESCE(v_author_name, 'عضو');

  -- Mentions notifications
  IF NEW.mentions IS NOT NULL AND array_length(NEW.mentions, 1) > 0 THEN
    FOREACH v_mention_id IN ARRAY NEW.mentions LOOP
      IF v_mention_id IS NOT NULL AND v_mention_id <> NEW.user_id THEN
        INSERT INTO public.notifications (
          user_id,
          type,
          title,
          body,
          action_url,
          related_entity_type,
          related_entity_id
        ) VALUES (
          v_mention_id,
          'comment_mention',
          'إشارة جديدة',
          v_author_name || ' أشار إليك في تعليق',
          NEW.entity_type || '/' || NEW.entity_id::text,
          NEW.entity_type,
          NEW.entity_id
        );
      END IF;
    END LOOP;
  END IF;

  -- Reply notification
  IF NEW.parent_id IS NOT NULL THEN
    SELECT user_id INTO v_parent_author_id FROM public.comments WHERE id = NEW.parent_id;
    IF v_parent_author_id IS NOT NULL AND v_parent_author_id <> NEW.user_id THEN
      INSERT INTO public.notifications (
        user_id,
        type,
        title,
        body,
        action_url,
        related_entity_type,
        related_entity_id
      ) VALUES (
        v_parent_author_id,
        'comment_reply',
        'رد جديد',
        v_author_name || ' رد على تعليقك',
        NEW.entity_type || '/' || NEW.entity_id::text,
        NEW.entity_type,
        NEW.entity_id
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_comment_notifications ON public.comments;
CREATE TRIGGER trigger_comment_notifications
  AFTER INSERT ON public.comments
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_comment_notifications();
