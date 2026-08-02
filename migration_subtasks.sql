-- ترحيل بسيط: إضافة عمود «خطوات الإنجاز» لجدول المهام
-- شغّله مرة واحدة في Supabase → SQL Editor → Run
-- (آمن ولا يؤثر على بياناتك الحالية)

alter table public.tasks
  add column if not exists subtasks jsonb default '[]'::jsonb;
