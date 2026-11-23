-- BR-11: "settlement happens via WhatsApp after matching" and bengs01.pdf's
-- Friends screen has a literal "Text in Whatsapp" button on every followed
-- friend — but `profiles` never had anywhere to store a phone number to
-- deep-link into. Nullable: existing accounts (especially Google OAuth
-- ones, which never collected one) won't have it retroactively.

alter table profiles add column if not exists phone_number varchar(20);
