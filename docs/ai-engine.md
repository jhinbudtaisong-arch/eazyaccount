# AI Engine

AI Engine แยกเป็น 2 ขั้นตอน:

1. Speech to Text แปลงเสียงภาษาไทยเป็นข้อความ
2. Thai Intent Parser แปลงข้อความเป็นรายการบัญชี

Edge Function อยู่ที่ `supabase/functions/ai-engine/index.ts` เพื่อซ่อน API key จาก Flutter client

## A. Speech to Text

Provider ที่รองรับใน design:

- OpenAI Whisper ผ่าน Audio Transcriptions API
- Google STT เป็น adapter สำรองในอนาคต

ค่าเริ่มต้นของ function:

```text
OPENAI_TRANSCRIBE_MODEL=whisper-1
```

OpenAI docs ระบุว่า Audio API มี endpoint `audio/transcriptions` สำหรับ speech-to-text และรองรับ `whisper-1`, `gpt-4o-mini-transcribe`, `gpt-4o-transcribe`, และ `gpt-4o-transcribe-diarize` โดยไฟล์อัปโหลดจำกัด 25 MB และรองรับไฟล์เช่น `mp3`, `m4a`, `wav`, `webm`

แนะนำสำหรับ MVP:

- ใช้ `whisper-1` ถ้าต้องการตาม requirement เดิมและคุม behavior ง่าย
- เปลี่ยนเป็น `gpt-4o-mini-transcribe` ผ่าน env ได้ ถ้าต้องการความแม่นขึ้นโดยไม่แก้โค้ด

## B. Thai Intent Parser

### Core Logic

กฎตีความรายจ่าย:

- `ซื้อ`
- `ค่า`
- `จ่าย`
- `เติม`
- `ค่าของ`

กฎตีความรายรับ:

- `ขาย`
- `รับ`
- `ได้เงิน`

ถ้าประโยคมีทั้ง keyword รายรับและรายจ่าย ให้เป็น `mixed`

ตัวอย่าง input:

```text
ซื้อหมู 500 ผัก 200
```

ผลลัพธ์:

```json
{
  "raw_text": "ซื้อหมู 500 ผัก 200",
  "type": "expense",
  "items": [
    { "name": "หมู", "amount": 500, "type": "expense" },
    { "name": "ผัก", "amount": 200, "type": "expense" }
  ],
  "income_total": 0,
  "expense_total": 700,
  "total": 700
}
```

Mixed mode:

```text
ขายของ 300 ซื้อของเพิ่ม 100
```

ผลลัพธ์:

```json
{
  "raw_text": "ขายของ 300 ซื้อของเพิ่ม 100",
  "type": "mixed",
  "items": [
    { "name": "ของ", "amount": 300, "type": "income" },
    { "name": "ของเพิ่ม", "amount": 100, "type": "expense" }
  ],
  "income_total": 300,
  "expense_total": 100,
  "total": 400
}
```

## API

Parse text:

```http
POST /functions/v1/ai-engine
Content-Type: application/json

{
  "raw_text": "ซื้อหมู 500 ผัก 200"
}
```

Parse text and save to database:

```http
POST /functions/v1/ai-engine
Authorization: Bearer <user-access-token>
Content-Type: application/json

{
  "raw_text": "ขายข้าว 50 น้ำ 20 ซื้อถุง 30",
  "save": true
}
```

When `save` is `true`, the function inserts one row into `entries` and the
parsed rows into `entry_items` through `public.create_entry_with_items`. The
response includes `saved: true`, `entry_id`, and the saved `entry` snapshot.

Transcribe + parse audio:

```http
POST /functions/v1/ai-engine
Content-Type: application/json

{
  "stt_provider": "openai",
  "audio_base64": "...",
  "audio_mime": "audio/webm",
  "audio_filename": "speech.webm"
}
```

## Database Mapping

Response จาก AI Engine map ลง database แบบนี้:

`entries`

- `raw_text` จาก response
- `type` จาก response
- `income_total` จาก response
- `expense_total` จาก response

`entry_items`

- `entry_id` จาก entry ที่ insert แล้ว
- `name`
- `amount`
- `type`

Insert flow:

1. Edge Function parses `raw_text` or transcribed audio.
2. If `save` is not true, it returns the parsed result only.
3. If `save` is true, it calls `public.create_entry_with_items` using the
   caller's Supabase access token, so RLS still limits writes to that user.
4. Database triggers rebuild entry totals and daily/monthly summaries.

## Notes

- Parser MVP ใช้ deterministic parsing เหมาะกับประโยคสั้น เช่น `ซื้อหมู 500 ผัก 200`
- ถ้าประโยคซับซ้อน เช่น มีส่วนลด เครดิต หรือหลายบิลในประโยคเดียว ค่อยเพิ่ม LLM parser หลังจากมี test cases จริง
- ห้ามเรียก OpenAI/Google STT จาก Flutter โดยตรง เพราะ API key ต้องอยู่ฝั่ง Supabase Function เท่านั้น
