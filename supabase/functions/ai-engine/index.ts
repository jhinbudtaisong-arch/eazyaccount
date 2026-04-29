import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type EntryType = "income" | "expense" | "mixed";
type ItemType = "income" | "expense";

type ParsedItem = {
  name: string;
  amount: number;
  type: ItemType;
  source?: string;
};

type IntentSegment = {
  keyword: string;
  type: ItemType;
  start: number;
  end: number;
};

const expenseKeywords = ["ซื้อ", "ค่าของ", "ค่า", "จ่าย", "เติม"];
const incomeKeywords = [
  "ได้รับเงิน",
  "เงินเดือน",
  "รับเงิน",
  "ได้เงิน",
  "จ่ายมา",
  "โอนมา",
  "ให้เงิน",
  "ให้ค่า",
  "จ่ายค่า",
  "โอนค่า",
  "เช็คบิล",
  "คิดเงิน",
  "ชำระ",
  "โอน",
  "ขาย",
  "รับ",
];
const allIntentKeywords = [...expenseKeywords, ...incomeKeywords]
  .sort((a, b) => b.length - a.length);
const intentKeywordPattern = new RegExp(`(${allIntentKeywords.join("|")})`, "g");
const amountPattern = /(\d+(?:,\d{3})*(?:\.\d+)?)/g;
const moneyNumberPattern = String.raw`(\d+(?:,\d{3})*(?:\.\d+)?)`;
const unitWordPattern =
  String.raw`(?:จาน|ขวด|แก้ว|ถุง|กล่อง|ชิ้น|อัน|ลูก|กิโล|โล|กก\.?|แพ็ค|แผง|ชุด|ใบ|ตัว)`;
const customerPaymentWords = [
  "ให้ค่า",
  "จ่ายค่า",
  "โอนค่า",
  "จ่ายมา",
  "โอนมา",
  "ให้เงิน",
];
const ownerPronounPattern =
  /^(ผม|ฉัน|ชั้น|เรา|หนู|กู|ข้าพเจ้า|ดิฉัน|เจ้าของร้าน|แม่ค้า|พ่อค้า)/;

type AiEngineRequest = {
  raw_text?: string;
  audio_base64?: string;
  audio_mime?: string;
  audio_filename?: string;
  stt_provider?: "openai" | "google";
  save?: boolean;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const body = (await request.json()) as AiEngineRequest;
    const rawText =
      normalizeWhitespace(body.raw_text) ||
      (await transcribeAudio(body));

    if (!rawText) {
      return jsonResponse(
        { error: "Provide raw_text or audio_base64 for parsing." },
        400,
      );
    }

    const parsed = parseThaiMoneyIntent(rawText);
    const responseBody = {
      raw_text: rawText,
      ...parsed,
    };

    if (!body.save) {
      return jsonResponse(responseBody);
    }

    const savedEntry = await saveParsedEntry(request, rawText, parsed.items);

    return jsonResponse({
      ...responseBody,
      saved: true,
      entry_id: savedEntry.entry_id,
      entry: savedEntry,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return jsonResponse({ error: message }, 500);
  }
});

async function saveParsedEntry(
  request: Request,
  rawText: string,
  items: ParsedItem[],
): Promise<{
  entry_id: string;
  raw_text: string;
  type: EntryType;
  income_total: number;
  expense_total: number;
  created_at: string;
}> {
  if (items.length === 0) {
    throw new Error("No parsed items to save.");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error("Supabase environment is not configured.");
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization) {
    throw new Error("Authorization header is required when save is true.");
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: authorization },
    },
  });

  const { data, error } = await supabase
    .rpc("create_entry_with_items", {
      p_raw_text: rawText,
      p_items: items,
    })
    .single();

  if (error) {
    throw new Error(`Failed to save entry: ${error.message}`);
  }

  return data as {
    entry_id: string;
    raw_text: string;
    type: EntryType;
    income_total: number;
    expense_total: number;
    created_at: string;
  };
}

async function transcribeAudio(body: AiEngineRequest): Promise<string> {
  if (!body.audio_base64) return "";

  if (body.stt_provider === "google") {
    throw new Error("Google STT adapter is not configured yet.");
  }

  return transcribeWithOpenAI({
    audioBase64: body.audio_base64,
    mimeType: body.audio_mime ?? "audio/webm",
    filename: body.audio_filename ?? "speech.webm",
  });
}

async function transcribeWithOpenAI(params: {
  audioBase64: string;
  mimeType: string;
  filename: string;
}): Promise<string> {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY is not set.");
  }

  const binary = Uint8Array.from(atob(params.audioBase64), (char) =>
    char.charCodeAt(0)
  );
  const audioFile = new File([binary], params.filename, {
    type: params.mimeType,
  });

  const formData = new FormData();
  formData.append("file", audioFile);
  formData.append("model", Deno.env.get("OPENAI_TRANSCRIBE_MODEL") ?? "whisper-1");
  formData.append("language", "th");
  formData.append(
    "prompt",
    "เสียงภาษาไทยของร้านค้าเกี่ยวกับรายรับ รายจ่าย สินค้า และจำนวนเงิน",
  );

  const response = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
    },
    body: formData,
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI transcription failed: ${errorText}`);
  }

  const data = await response.json();
  return normalizeWhitespace(data.text ?? "");
}

function parseThaiMoneyIntent(rawText: string): {
  type: EntryType;
  items: ParsedItem[];
  income_total: number;
  expense_total: number;
  total: number;
} {
  const text = normalizeWhitespace(rawText);
  const items = parseMeasuredPriceItems(text);
  if (items.length === 0) {
    items.push(...parseUnitPriceQuantityItems(text));
  }
  if (items.length === 0) {
    items.push(...parseCustomerIncomeItems(text));
  }
  if (items.length === 0) {
    items.push(...parseShoppingListItems(text));
  }
  if (items.length === 0) {
    items.push(...parseKeywordAmountItems(text));
  }

  const incomeTotal = sumItems(items, "income");
  const expenseTotal = sumItems(items, "expense");
  const type = detectEntryType(items, text);

  return {
    type,
    items,
    income_total: incomeTotal,
    expense_total: expenseTotal,
    total: incomeTotal + expenseTotal,
  };
}

function parseUnitPriceQuantityItems(text: string): ParsedItem[] {
  return dedupeOverlappingItems([
    ...parsePriceThenQuantityItems(text),
    ...parseQuantityThenPriceItems(text),
  ]);
}

function parseMeasuredPriceItems(text: string): ParsedItem[] {
  const pattern = /^\s*(.+?\d+(?:\.\d+)?\s*(?:นิ้ว|เมตร|ซม\.?|เซน|มม\.?|หุน|กิโล|โล|กก\.?|ชิ้น|อัน|เส้น|แผ่น|ม้วน|แพ็ค|กล่อง|ถุง|ขวด))\s*(?:ราคา|รวม|ทั้งหมด)?\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*(?:บาท|บ\.|฿)\s*$/i;
  const match = text.match(pattern);
  if (!match) return [];

  const name = normalizeShoppingItemName(cleanItemName(match[1]));
  const amount = parseMoneyNumber(match[2]);
  if (!name || Number.isNaN(amount)) return [];

  return [{ name, amount, type: "expense" as const }];
}

function parsePriceThenQuantityItems(text: string): Array<ParsedItem & {
  start: number;
  end: number;
}> {
  const pattern = new RegExp(
    `([^\\d,;|]+?)\\s*${moneyNumberPattern}\\s*(?:บาท|บ\\.|฿)\\s*${moneyNumberPattern}\\s*${unitWordPattern}`,
    "gi",
  );

  return [...text.matchAll(pattern)]
    .map((match) => {
      const start = match.index ?? 0;
      const end = start + match[0].length;
      const name = cleanItemName(match[1]);
      const unitPrice = parseMoneyNumber(match[2]);
      const quantity = parseMoneyNumber(match[3]);
      const amount = unitPrice * quantity;

      if (!name || Number.isNaN(amount)) return null;

      return {
        name,
        amount,
        type: detectUnitPriceItemType(match[1], text),
        start,
        end,
      };
    })
    .filter((item): item is ParsedItem & { start: number; end: number } =>
      item !== null
    );
}

function parseQuantityThenPriceItems(text: string): Array<ParsedItem & {
  start: number;
  end: number;
}> {
  const pattern = new RegExp(
    `([^\\d,;|]+?)\\s*${moneyNumberPattern}\\s*${unitWordPattern}(?:\\s*(?:${unitWordPattern}ละ|ละ|ราคา))?\\s*${moneyNumberPattern}\\s*(?:บาท|บ\\.|฿)`,
    "gi",
  );

  return [...text.matchAll(pattern)]
    .map((match) => {
      const start = match.index ?? 0;
      const end = start + match[0].length;
      const name = cleanItemName(match[1]);
      const quantity = parseMoneyNumber(match[2]);
      const unitPrice = parseMoneyNumber(match[3]);
      const amount = unitPrice * quantity;

      if (!name || Number.isNaN(amount)) return null;

      return {
        name,
        amount,
        type: detectUnitPriceItemType(match[1], text),
        start,
        end,
      };
    })
    .filter((item): item is ParsedItem & { start: number; end: number } =>
      item !== null
    );
}

function dedupeOverlappingItems(
  items: Array<ParsedItem & { start: number; end: number }>,
): ParsedItem[] {
  const sorted = [...items].sort((a, b) => a.start - b.start || b.end - a.end);
  const accepted: Array<ParsedItem & { start: number; end: number }> = [];

  for (const item of sorted) {
    const overlaps = accepted.some((current) =>
      item.start < current.end && current.start < item.end
    );
    if (!overlaps) accepted.push(item);
  }

  return accepted.map(({ start: _start, end: _end, ...item }) => item);
}

function parseCustomerIncomeItems(text: string): ParsedItem[] {
  return [
    ...parseTablePaymentItems(text),
    ...parseNamedCustomerPaymentItems(text),
  ];
}

function parseTablePaymentItems(text: string): ParsedItem[] {
  if (!/โต๊ะ\s*\d+/.test(text) || !/(จ่าย|ชำระ|เช็คบิล|คิดเงิน)/.test(text)) {
    return [];
  }

  const matches = [
    ...text.matchAll(
      /(โต๊ะ\s*\d+)[^\d]*(?:จ่าย|ชำระ|เช็คบิล|คิดเงิน)\s*(\d+(?:,\d{3})*(?:\.\d+)?)(?:\s*(เบิ้ล|x\s*2|×\s*2))?/gi,
    ),
  ];

  return matches
    .map((match) => {
      const amount = Number(match[2].replace(/,/g, "")) *
        getQuantityMultiplier(match[0]);
      if (Number.isNaN(amount)) return null;

      return {
        name: normalizeWhitespace(match[1]),
        amount,
        type: "income" as const,
        source: normalizeWhitespace(match[1]),
      };
    })
    .filter((item): item is ParsedItem => item !== null);
}

function parseNamedCustomerPaymentItems(text: string): ParsedItem[] {
  const words = customerPaymentWords.join("|");
  const matches = [
    ...text.matchAll(
      new RegExp(
        `([^\\d,;|]+?)\\s*(?:${words})\\s*([^\\d,;|]+?)\\s*(\\d+(?:,\\d{3})*(?:\\.\\d+)?)(?:\\s*(เบิ้ล|x\\s*2|×\\s*2))?`,
        "gi",
      ),
    ),
  ];

  return matches
    .map((match) => {
      const source = cleanPersonName(match[1]);
      const itemName = cleanItemName(match[2]);
      const amount = Number(match[3].replace(/,/g, "")) *
        getQuantityMultiplier(match[0]);
      if (!source || !itemName || Number.isNaN(amount)) return null;

      return {
        name: itemName.startsWith("ค่า") ? itemName : `ค่า${itemName}`,
        amount,
        type: isOwnerSubject(source) || isOwnerPayer(source)
          ? ("expense" as const)
          : ("income" as const),
        source,
      };
    })
    .filter((item): item is ParsedItem => item !== null);
}

function parseKeywordAmountItems(text: string): ParsedItem[] {
  const intentSegments = getIntentSegments(text);
  if (intentSegments.length === 0) {
    return parseImplicitAmountItems(text);
  }

  const matches = [...text.matchAll(amountPattern)];

  return matches
    .map((match, index) => {
      const baseAmount = Number(match[1].replace(/,/g, ""));
      const amountIndex = match.index ?? 0;
      const amountEnd = amountIndex + match[0].length;
      const nextAmountIndex = matches[index + 1]?.index ?? text.length;
      const segmentStart = index === 0
        ? 0
        : (matches[index - 1].index ?? 0) + matches[index - 1][0].length;
      const segment = text.slice(segmentStart, amountIndex);
      const afterAmount = text.slice(amountEnd, nextAmountIndex);
      const intent = findActiveIntent(intentSegments, amountIndex);
      const name = cleanItemName(segment) ||
        defaultItemNameForIntent(intent?.keyword ?? "", segment);
      const amount = baseAmount * getQuantityMultiplier(`${segment} ${afterAmount}`);

      if (!intent || !name || Number.isNaN(amount)) return null;

      return { name, amount, type: detectItemType(segment, text, intent.type) };
    })
    .filter((item): item is ParsedItem => item !== null);
}

function getIntentSegments(text: string): IntentSegment[] {
  return [...text.matchAll(intentKeywordPattern)].map((match) => {
    const keyword = match[1];
    const start = match.index ?? 0;

    return {
      keyword,
      type: keywordToItemType(keyword),
      start,
      end: start + keyword.length,
    };
  });
}

function findActiveIntent(
  intentSegments: IntentSegment[],
  amountIndex: number,
): IntentSegment | null {
  let activeIntent: IntentSegment | null = null;

  for (const intent of intentSegments) {
    if (intent.start > amountIndex) break;
    activeIntent = intent;
  }

  return activeIntent;
}

function parseImplicitAmountItems(text: string): ParsedItem[] {
  const matches = [...text.matchAll(/(\d+(?:,\d{3})*(?:\.\d+)?)/g)];

  return matches
    .map((match, index) => {
      const baseAmount = Number(match[1].replace(/,/g, ""));
      const segmentStart = index === 0
        ? 0
        : (matches[index - 1].index ?? 0) + matches[index - 1][0].length;
      const segmentEnd = match.index ?? text.length;
      const amountEnd = segmentEnd + match[0].length;
      const nextAmountIndex = matches[index + 1]?.index ?? text.length;
      const segment = text.slice(segmentStart, segmentEnd);
      const afterAmount = text.slice(amountEnd, nextAmountIndex);
      const type = detectItemType(segment, text);
      const name = cleanItemName(segment);
      const amount = baseAmount * getQuantityMultiplier(`${segment} ${afterAmount}`);

      if (!name || Number.isNaN(amount)) return null;

      return { name, amount, type };
    })
    .filter((item): item is ParsedItem => item !== null);
}

function parseShoppingListItems(text: string): ParsedItem[] {
  const hasNumber = /\d/.test(text);
  const isMeasurementList = hasShoppingMeasurement(text) && !hasMoneyPriceText(text);
  if (hasNumber && !isMeasurementList) {
    return [];
  }

  const cleanedText = normalizeWhitespace(text)
    .replace(/^(ซื้อ|รายการ|เพิ่ม|ใส่|เอา|จด|ลิสต์|list)\s*/i, "")
    .replace(/\s*(ไว้ในลิสต์|ลงลิสต์|เข้าลิสต์|ในลิสต์)$/i, "")
    .replace(/[,:;|]+/g, " ")
    .replace(/\s+(และ|กับ)\s+/g, " ");

  if (isMeasurementList) {
    return [{
      name: normalizeShoppingItemName(cleanedText),
      amount: 0,
      type: "expense" as const,
    }];
  }

  return cleanedText
    .split(/\s+/)
    .map((name) => cleanItemName(name))
    .filter((name, index, names) =>
      name.length > 0 && names.indexOf(name) === index
    )
    .map((name) => ({
      name,
      amount: 0,
      type: "expense" as const,
    }));
}

function hasShoppingMeasurement(text: string): boolean {
  return /\d+(?:\.\d+)?\s*(นิ้ว|เมตร|ซม\.?|เซน|มม\.?|หุน|กิโล|โล|กก\.?|ชิ้น|อัน|เส้น|แผ่น|ม้วน|แพ็ค|กล่อง|ถุง|ขวด)/i.test(text);
}

function hasMoneyPriceText(text: string): boolean {
  return /(บาท|บ\.|฿|ราคา|รวม|ทั้งหมด)/i.test(text);
}

function normalizeShoppingItemName(text: string): string {
  return normalizeWhitespace(text)
    .replace(/([^\s\d])(\d)/g, "$1 $2")
    .replace(/(\d)([^\s\d])/g, "$1 $2");
}

function detectEntryType(items: ParsedItem[], text: string): EntryType {
  const hasIncome = items.some((item) => item.type === "income");
  const hasExpense = items.some((item) => item.type === "expense");

  if (hasIncome && hasExpense) return "mixed";
  if (hasIncome) return "income";
  if (hasExpense) return "expense";

  return containsIncomeKeyword(text) && !containsExpenseKeyword(text)
    ? "income"
    : "expense";
}

function detectItemType(
  segment: string,
  fullText: string,
  fallback?: ItemType,
): ItemType {
  if (isOwnerPayer(segment) || isOwnerPayer(fullText)) return "expense";
  if (isCustomerPayment(fullText)) return "income";
  if (isTablePayment(fullText)) return "income";
  if (containsIncomeKeyword(segment)) return "income";
  if (containsExpenseKeyword(segment)) return "expense";
  if (containsIncomeKeyword(fullText) && !containsExpenseKeyword(fullText)) {
    return "income";
  }
  if (fallback) return fallback;
  return "expense";
}

function detectUnitPriceItemType(segment: string, fullText: string): ItemType {
  if (isOwnerPayer(segment) || isOwnerPayer(fullText)) return "expense";
  if (containsExpenseKeyword(segment) || containsExpenseKeyword(fullText)) {
    return "expense";
  }
  return "income";
}

function keywordToItemType(keyword: string): ItemType {
  return incomeKeywords.includes(keyword) ? "income" : "expense";
}

function cleanItemName(segment: string): string {
  return normalizeWhitespace(segment)
    .replace(
      /^(ค่าของ|ได้รับเงิน|เงินเดือน|รับเงิน|ได้เงิน|ให้ค่า|จ่ายค่า|โอนค่า|จ่ายมา|โอนมา|ให้เงิน|เช็คบิล|คิดเงิน|ซื้อ|ค่า|จ่าย|ชำระ|โอน|เติม|ขาย|รับ|บันทึก|เพิ่ม|รายการ)/,
      "",
    )
    .replace(/(ได้รับเงิน|เงินเดือน|รับเงิน|ให้ค่า|จ่ายค่า|โอนค่า|จ่ายมา|โอนมา|ให้เงิน|เช็คบิล|คิดเงิน|จ่าย|ชำระ|โอน)$/g, "")
    .replace(/บาท|บ\.|฿/g, "")
    .replace(/[,:;|]+/g, " ")
    .trim();
}

function cleanPersonName(value: string): string {
  return normalizeWhitespace(value)
    .replace(/^(บันทึก|เพิ่ม|รายการ|รับ|ขาย)/, "")
    .replace(/[,:;|]+/g, " ")
    .trim();
}

function defaultItemNameForIntent(keyword: string, segment: string): string {
  if (/(โอน|โอนมา)/.test(keyword) || /โอน/.test(segment)) return "เงินโอน";
  if (/เงินเดือน/.test(keyword) || /เงินเดือน/.test(segment)) {
    return "เงินเดือน";
  }
  if (/(ได้รับเงิน|รับเงิน|ให้เงิน|ได้เงิน|รับ|จ่ายมา|ชำระ|เช็คบิล|คิดเงิน)/.test(keyword)) {
    return "รับเงิน";
  }
  return "";
}

function isTablePayment(text: string): boolean {
  return /โต๊ะ\s*\d+/.test(text) && /(จ่าย|ชำระ|เช็คบิล|คิดเงิน)/.test(text);
}

function isCustomerPayment(text: string): boolean {
  return /(ลูกค้า|โต๊ะ\s*\d+)\s*(จ่ายเงิน|จ่ายมา|จ่าย|ชำระ|โอนมา|โอน|ให้เงิน)/.test(
    normalizeWhitespace(text),
  );
}

function isOwnerPayer(text: string): boolean {
  const value = normalizeWhitespace(text);
  return ownerPronounPattern.test(value) &&
    /(ให้ค่า|จ่ายค่า|โอนค่า|จ่าย|ชำระ|โอน|ให้เงิน)/.test(value);
}

function isOwnerSubject(text: string): boolean {
  return ownerPronounPattern.test(normalizeWhitespace(text));
}

function getQuantityMultiplier(text: string): number {
  return /(เบิ้ล|เบิ้ลอีก|x\s*2|×\s*2)/i.test(text) ? 2 : 1;
}

function parseMoneyNumber(value: string): number {
  return Number(value.replace(/,/g, ""));
}

function containsIncomeKeyword(text: string): boolean {
  return incomeKeywords.some((keyword) => text.includes(keyword));
}

function containsExpenseKeyword(text: string): boolean {
  return expenseKeywords.some((keyword) => text.includes(keyword));
}

function sumItems(items: ParsedItem[], type: ItemType): number {
  return items
    .filter((item) => item.type === type)
    .reduce((sum, item) => sum + item.amount, 0);
}

function normalizeWhitespace(value?: string): string {
  return (value ?? "").replace(/\s+/g, " ").trim();
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}
