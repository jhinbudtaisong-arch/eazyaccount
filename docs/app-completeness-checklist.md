# EazyAccount App Completeness Checklist

ตรวจล่าสุด: 2026-05-06

## สรุปตรง ๆ

ระบบใกล้ความจริงในระดับ MVP/demo แล้ว และเริ่มแตะ closed beta ได้ถ้ารับข้อจำกัดได้ แต่ยังไม่ใช่ production ที่ปล่อยให้คนทั่วไปใช้เงินจริงจัง

ระดับความพร้อมโดยประมาณ:

- MVP demo: 80-85%
- ทดลองใช้จริงในกลุ่มเล็ก/ร้านเดียว: 60-65%
- Production/public launch: 40-45%

เหตุผลหลัก: flow สำคัญของแอปมีแล้วและ build/test ผ่านจริง แต่ persistence, report accuracy, edit/delete, payment, deploy/secret/CI และนโยบายข้อมูลยังต้องปิดก่อนใช้งานจริง

## ตรวจยืนยันแล้ววันนี้

- [x] `flutter analyze` ผ่าน: No issues found
- [x] `flutter test` ผ่าน: 8 tests passed
- [x] `flutter build web` ผ่าน และสร้าง `build/web` ได้
- [x] `git` และ `rg` ใช้งานได้ใน repo นี้
- [ ] ยังไม่ได้ยืนยัน run บน Android emulator/device
- [ ] ยังไม่ได้ยืนยัน run บน iOS device/simulator
- [ ] ยังไม่ได้ยืนยัน Supabase local reset/deploy migrations/functions จริงในเครื่องนี้
- [ ] Web build ยังมี warning เรื่อง `packages/cupertino_icons/CupertinoIcons` font แม้ build ไม่ fail และ `rg` ไม่พบการใช้งานใน `lib`

## ของที่เป็นของจริงแล้ว

- [x] มี Flutter app พร้อม platform runner สำหรับ Android, iOS, Web, Windows
- [x] มี Supabase Auth email/password จริง ไม่ใช่ mock
- [x] มี sign up, sign in, sign out และ restore session ผ่าน `shared_preferences`
- [x] มี Home screen สำหรับพูดหรือพิมพ์ภาษาไทย
- [x] มี Push mode และ Auto mode สำหรับ speech recognition
- [x] Speech ฟังหลายประโยค และหยุดเมื่อเงียบ 10 วินาที
- [x] เลือก locale ภาษาไทยให้ `speech_to_text`
- [x] มี preview tag ก่อนบันทึก และลบ tag ที่ผิดได้
- [x] มี shopping list mode สำหรับรายการซื้อที่ไม่มีราคา เช่น `มาม่า/แก้ว/ฝักชี`
- [x] มี parser ฝั่ง Dart สำหรับบาง pattern ที่ควรตอบเร็วโดยไม่เรียก Edge Function
- [x] มี Supabase Edge Function `ai-engine` สำหรับ parse ข้อความไทย
- [x] Edge Function รองรับ save ผ่าน RPC `create_entry_with_items`
- [x] มี Supabase migrations สำหรับ users, entries, entry_items, daily_summary, monthly_summary
- [x] เปิด RLS และ policy แยกข้อมูลตามผู้ใช้
- [x] มี trigger rebuild entry totals และ daily/monthly summary
- [x] มี RPC `get_entries_page` สำหรับ pagination ฝั่ง database
- [x] มีหน้า Home, รายละเอียด, รายงาน, ตั้งค่า
- [x] มีหน้า member profile และบันทึกชื่อสมาชิก/ร้าน/เบอร์โทรลง `users`
- [x] มี Free/Pro member plan และกดเปลี่ยน plan แล้ว update database ได้
- [x] มี Android permission สำหรับ internet/microphone
- [x] มี iOS usage description สำหรับ microphone/speech recognition
- [x] มี light/dark theme

## ทำแล้วบางส่วน แต่ยังไม่ควรเรียกว่าเสร็จจริง

- [ ] ปุ่ม `บันทึก` ในหน้า Home ตอนนี้บันทึกเป็น pending local ใน `shared_preferences` ก่อน ไม่ได้ส่ง Supabase ทันที
- [ ] ระบบจะ flush pending entries ที่เก่ากว่าวันนี้ไป Supabase ตอนโหลด/ข้ามวัน จึงเหมาะกับ concept "รอปิดวัน" แต่ต้องยืนยันว่า UX นี้ตั้งใจจริง
- [ ] ถ้าผู้ใช้ต้องการ backup cloud ทันทีหลังบันทึก ตอนนี้ยังไม่พอ
- [ ] รายการ pending แก้ได้แค่ลบ tag ก่อน save หรือขีดฆ่าก่อนปิดวัน ยังแก้ชื่อ/จำนวน/ประเภทรายการไม่ได้
- [ ] รายงานมีปุ่ม วันนี้/สัปดาห์/เดือน แต่ totals card ยังใช้ entries ทั้งหมดที่โหลดมา ไม่ได้ filter ตาม range จริง
- [ ] Calendar รายเดือนสรุปจาก entries ที่ client มีอยู่ ไม่ได้ query `daily_summary`/`monthly_summary`
- [ ] App มี `get_entries_page` ใน database แต่ Flutter ยัง fetch จาก `entry_items` ล่าสุด 100 rows โดยตรง
- [ ] History จึงเป็นระดับ item row ไม่ใช่ parent bill/entry ที่รวมหลาย item เป็นบิลเดียว
- [ ] Settings มีภาษาและสำรองข้อมูลเป็นข้อความ UI แต่ยังไม่มี action เปลี่ยนภาษา/ตั้งค่าสำรองข้อมูลจริง
- [ ] Subscription เปลี่ยน plan ใน database ได้ แต่ยังไม่มี payment, receipt, entitlement, billing provider หรือ server-side validation
- [ ] Flutter ใช้ device speech recognition แล้วส่ง text ไป parse ยังไม่ได้ใช้ audio upload/transcription path ของ Edge Function
- [ ] Edge Function รองรับ OpenAI transcription ถ้ามี `OPENAI_API_KEY` แต่ Google STT ยังเป็น placeholder
- [ ] Supabase config ใช้ `--dart-define` ได้ แต่ default ยังเป็น local/dev URL และ anon key
- [ ] Web manifest ยังเป็น Flutter template บางส่วน เช่น description ยังเป็น `A new Flutter project.`
- [ ] เอกสาร `docs/frontend-modules.md` ยังมีข้อความเก่าว่า auth/mock ทั้งที่โค้ดจริงเปลี่ยนไปแล้ว

## จุดเสี่ยงก่อน closed beta

- [ ] ต้องตัดสินใจเรื่อง "บันทึกทันที" vs "รอปิดวัน" ให้ชัด เพราะมีผลกับความคาดหวังเรื่องข้อมูลไม่หาย
- [ ] ต้องมี edit/delete รายการหลังบันทึก โดยเฉพาะจำนวนเงินและประเภทรายรับ/รายจ่าย
- [ ] ต้องแก้ report range ให้คำนวณตามวันนี้/สัปดาห์/เดือนจริง ไม่ใช่เปลี่ยนแค่ label
- [ ] ต้องเพิ่ม pagination หรือ infinite scroll สำหรับประวัติ
- [ ] ต้องให้ UI ดูรายการเป็นบิล/entry ได้ ไม่ใช่เห็นแต่ item rows
- [ ] ต้องเพิ่ม tests สำหรับ save/flush pending entries และ discard flow
- [ ] ต้องเพิ่ม tests สำหรับ parser ภาษาไทยจริงจากร้านค้า เช่น ลูกค้าจ่าย, ของหลายชิ้น, ราคาต่อหน่วย, รายการซื้อไม่มีราคา
- [ ] ต้องเพิ่ม SQL/RLS verification ว่าผู้ใช้ข้ามบัญชีอ่าน/เขียนข้อมูลกันไม่ได้
- [ ] ต้องทดสอบ flow จริงกับ Supabase local หรือ staging: sign up -> parse -> pending -> flush -> reload
- [ ] ต้องตรวจ offline/error state เมื่อ Supabase, Edge Function หรือ speech service ล่ม
- [ ] ต้องตรวจ timezone/date grouping ให้ตรงกับผู้ใช้ไทย โดยเฉพาะการปิดวัน

## ยังขาดก่อน production/public launch

- [ ] Production Supabase project, URL/key และ environment setup
- [ ] Secret management สำหรับ Edge Function เช่น `OPENAI_API_KEY`
- [ ] Deploy migrations และ Edge Function พร้อม checklist ย้อนกลับได้
- [ ] CI/CD สำหรับ analyze, test, build และ migration validation
- [ ] Payment/subscription จริง หรือซ่อน Pro จนกว่าจะพร้อม
- [ ] Password reset และ UX สำหรับ email confirmation
- [ ] Privacy policy/terms เพราะแอปใช้เสียงและข้อมูลการเงิน
- [ ] Data export CSV/Excel/PDF ถ้าจะใช้กับงานบัญชีจริง
- [ ] Backup/restore story ที่พูดกับผู้ใช้ได้ชัด
- [ ] App name/icon/description สำหรับ web/mobile store readiness
- [ ] Accessibility: text scaling, contrast, screen reader label, focus order
- [ ] Monitoring/logging/crash reporting สำหรับ production
- [ ] Security review เรื่อง session storage ใน `shared_preferences`

## ลำดับงานแนะนำ

1. ตัดสินใจและแก้ flow บันทึก: save Supabase ทันที หรือ pending รอปิดวันแบบตั้งใจ
2. แก้รายงานให้ filter range จริง หรือ query summary tables จาก Supabase
3. เพิ่ม edit/delete และแก้ tag ก่อน/หลังบันทึก
4. ใช้ `get_entries_page` ใน Flutter แทนการดึง `entry_items` 100 rows ตรง ๆ
5. เพิ่ม test สำหรับ pending flush, parser, repository, RLS และ integration flow
6. ทำ Settings/Subscription ให้เป็น flow จริง หรือซ่อนส่วนที่ยังไม่พร้อม
7. ตั้ง production config, deploy checklist, privacy policy และ CI/CD

## คำตอบเรื่อง "ใกล้ความจริงไหม"

ใกล้แล้วในแง่แอปใช้งานเป็นทรงจริง: login ได้, พูด/พิมพ์ได้, parse ได้, เห็นรายการและรายงานได้, profile/member มีแล้ว, build/test ผ่าน

แต่ยังไม่ถึง "ของจริงที่ไว้ใจให้ร้านใช้ทุกวัน" เพราะข้อมูลวันนี้ยังอยู่ pending local ก่อนปิดวัน, รายงาน range ยังคลาดเคลื่อน, ยังแก้รายการไม่ได้ครบ, และยังไม่มี production deploy/payment/privacy/CI
