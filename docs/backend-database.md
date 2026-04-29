# Backend + Database

Backend ใช้ Supabase Auth + Postgres โดย schema หลักอยู่ที่ `supabase/migrations/20260427150000_initial_accounting_schema.sql`

## Tables

| Table | Purpose |
| --- | --- |
| `users` | profile ของผู้ใช้ ผูกกับ `auth.users` |
| `entries` | บันทึกหนึ่งครั้งจากเสียงหรือข้อความดิบ |
| `entry_items` | รายการย่อยที่ AI parse ออกจาก entry |
| `daily_summary` | สรุปยอดแยกตามวัน |
| `monthly_summary` | สรุปยอดแยกตามเดือน |

## Data Model

`entries`

- `id`
- `user_id`
- `raw_text`
- `type`: `income`, `expense`, `mixed`
- `income_total`
- `expense_total`
- `created_at`

`entry_items`

- `id`
- `entry_id`
- `name`
- `amount`
- `type`: `income`, `expense`
- `created_at`

`daily_summary`

- `user_id`
- `date`
- `income_total`
- `expense_total`
- `net_total`

`monthly_summary`

- `user_id`
- `month`: วันแรกของเดือน เช่น `2026-04-01`
- `income_total`
- `expense_total`
- `net_total`

## Loading Strategy

ไม่โหลด entries ทั้งหมดในครั้งเดียว ใช้ cursor pagination:

```sql
select *
from public.get_entries_page(20, null, null);
```

หน้าถัดไปส่ง cursor จากรายการสุดท้ายของหน้าปัจจุบัน:

```sql
select *
from public.get_entries_page(
  20,
  '2026-04-27T10:00:00Z',
  '00000000-0000-0000-0000-000000000000'
);
```

โหลดรายการย่อยเฉพาะ entry ที่เปิดดู:

```sql
select entry_id, name, amount, type
from public.entry_items
where entry_id = :entry_id
order by created_at asc, id asc;
```

## Insert Strategy

AI Engine saves parsed results through:

```sql
select *
from public.create_entry_with_items(
  'ขายข้าว 50 น้ำ 20 ซื้อถุง 30',
  '[{"name":"ข้าว","amount":50,"type":"income"},{"name":"น้ำ","amount":20,"type":"income"},{"name":"ถุง","amount":30,"type":"expense"}]'::jsonb
);
```

The RPC inserts the parent `entries` row and all `entry_items` rows in one
database transaction. It runs as `security invoker`, so normal RLS policies still
apply and `auth.uid()` becomes the saved `entries.user_id`.

## Summary Queries

เมื่อเพิ่ม/แก้/ลบ `entry_items` ระบบจะคำนวณ `entries.income_total`, `entries.expense_total`, และ `entries.type` ใหม่อัตโนมัติ จากนั้น trigger ของ `entries` จะ rebuild summary ของวันและเดือนที่เกี่ยวข้อง

รายวัน:

```sql
select date, income_total, expense_total, net_total
from public.daily_summary
where date between :start_date and :end_date
order by date desc;
```

รายเดือน:

```sql
select month, income_total, expense_total, net_total
from public.monthly_summary
where month between :start_month and :end_month
order by month desc;
```

## Indexes

- `entries_user_created_id_idx` รองรับหน้า history แบบ cursor และ filter ตามผู้ใช้
- `entries_user_type_created_idx` รองรับ filter รายรับ/รายจ่าย/ผสม
- `entry_items_entry_id_idx` รองรับโหลด parsed items ตาม entry
- `daily_summary_user_date_desc_idx` รองรับรายงานตามวัน
- `monthly_summary_user_month_desc_idx` รองรับรายงานตามเดือน

## Security

- เปิด RLS ทุกตาราง
- ผู้ใช้เห็น/แก้ไขได้เฉพาะข้อมูลของตัวเอง
- `entry_items` ตรวจสิทธิ์ผ่าน parent `entries`
- summary tables เปิดให้ select เท่านั้น ฝั่ง client ไม่ควรเขียน summary เอง
