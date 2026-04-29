# Frontend Modules

Flutter frontend ถูกแยกเป็น feature modules เพื่อให้ต่อ backend, speech service, database และ subscription ภายหลังได้ง่าย

## App Entry

- `lib/main.dart` เริ่มต้นแอป
- `lib/app.dart` จัดการ auth gate, app shell, bottom navigation และ mock transaction state

## Modules

| Module | Path | Responsibility |
| --- | --- | --- |
| auth | `lib/features/auth/` | หน้าเข้าสู่ระบบแบบ mock สำหรับ MVP |
| speech button | `lib/features/speech/` | ปุ่มไมค์ใหญ่, Push/Auto mode, listening state |
| history list | `lib/features/history/` | รายการล่าสุดบนหน้า Home |
| detail table | `lib/features/details/` | หน้ารายละเอียดและตาราง รายการ/รายจ่าย/รายรับ |
| summary dashboard | `lib/features/summary/` | สรุปยอดบน Home และหน้ารายงาน วันนี้/สัปดาห์/เดือน |
| settings | `lib/features/settings/` | ภาษา, สำรองข้อมูล, สมัครสมาชิก, ออกจากระบบ |
| subscription | `lib/features/subscription/` | หน้าแพ็กเกจ Free/Pro |

## Shared Layer

- `lib/shared/models/money_entry.dart` เก็บ enum และ model หลักของรายการบัญชี
- `lib/shared/theme/app_theme.dart` เก็บ color system, theme, font fallback
- `lib/shared/utils/formatters.dart` เก็บ formatter สำหรับเงิน เวลา และชื่อช่วงรายงาน

## Next Integration Points

- Auth: เปลี่ยน `AuthGate` จาก state mock เป็น Firebase/Auth API
- Speech: ต่อ `SpeechButton` เข้ากับ speech-to-text service
- Parsing: เมื่อ speech ได้ข้อความ ให้ parse เป็น `MoneyEntry`
- Database: ย้าย `_entries` ใน `AppShell` ไป repository/database layer
- Subscription: เปลี่ยนปุ่ม Pro ให้เรียก payment/subscription flow
