/**
 * 住所に使う言葉。
 *
 * 住所は人が声に出して交換するものなので、意味のない乱数列にはしない。
 * 紙・光・水・季節・記憶といった、この手紙の世界に合う言葉だけを集めている。
 * どの組み合わせでも情景になるよう、負の意味を持つ語は入れていない。
 *
 * 表記はひらがな。ローマ字も持たせているのは入力を寛容にするためで、
 * 相手から聞いた住所をローマ字で打っても引けるようにしている。
 */
export interface AddressWord {
  kana: string;
  roman: string;
}

export const ADDRESS_WORDS: AddressWord[] = [
  // 光・天候
  { kana: 'こもれび', roman: 'komorebi' },
  { kana: 'あさひ', roman: 'asahi' },
  { kana: 'ゆうだち', roman: 'yudachi' },
  { kana: 'かすみ', roman: 'kasumi' },
  { kana: 'おぼろ', roman: 'oboro' },
  { kana: 'あかつき', roman: 'akatsuki' },
  { kana: 'たそがれ', roman: 'tasogare' },
  { kana: 'ゆうやけ', roman: 'yuyake' },
  { kana: 'ひなた', roman: 'hinata' },
  { kana: 'かげろう', roman: 'kagero' },
  { kana: 'つきよ', roman: 'tsukiyo' },
  { kana: 'ほしぞら', roman: 'hoshizora' },
  { kana: 'あまおと', roman: 'amaoto' },
  { kana: 'きりさめ', roman: 'kirisame' },
  { kana: 'はるさめ', roman: 'harusame' },
  { kana: 'しぐれ', roman: 'shigure' },
  { kana: 'ゆきあかり', roman: 'yukiakari' },
  { kana: 'つゆ', roman: 'tsuyu' },
  { kana: 'にじ', roman: 'niji' },
  { kana: 'かぜ', roman: 'kaze' },
  { kana: 'はやて', roman: 'hayate' },
  { kana: 'なぎ', roman: 'nagi' },
  { kana: 'ひかげ', roman: 'hikage' },
  { kana: 'つきかげ', roman: 'tsukikage' },

  // 水・場所
  { kana: 'なぎさ', roman: 'nagisa' },
  { kana: 'みなと', roman: 'minato' },
  { kana: 'いずみ', roman: 'izumi' },
  { kana: 'かわら', roman: 'kawara' },
  { kana: 'みずべ', roman: 'mizube' },
  { kana: 'しみず', roman: 'shimizu' },
  { kana: 'うみべ', roman: 'umibe' },
  { kana: 'さざなみ', roman: 'sazanami' },
  { kana: 'こみち', roman: 'komichi' },
  { kana: 'いしだたみ', roman: 'ishidatami' },
  { kana: 'のなか', roman: 'nonaka' },
  { kana: 'おくやま', roman: 'okuyama' },
  { kana: 'さとやま', roman: 'satoyama' },
  { kana: 'たにま', roman: 'tanima' },

  // 植物
  { kana: 'さくら', roman: 'sakura' },
  { kana: 'つばき', roman: 'tsubaki' },
  { kana: 'すみれ', roman: 'sumire' },
  { kana: 'ふじ', roman: 'fuji' },
  { kana: 'はす', roman: 'hasu' },
  { kana: 'すすき', roman: 'susuki' },
  { kana: 'もみじ', roman: 'momiji' },
  { kana: 'わかば', roman: 'wakaba' },
  { kana: 'こずえ', roman: 'kozue' },
  { kana: 'かえで', roman: 'kaede' },
  { kana: 'やなぎ', roman: 'yanagi' },
  { kana: 'つた', roman: 'tsuta' },
  { kana: 'こけ', roman: 'koke' },
  { kana: 'たけ', roman: 'take' },
  { kana: 'まつ', roman: 'matsu' },
  { kana: 'うめ', roman: 'ume' },
  { kana: 'きく', roman: 'kiku' },
  { kana: 'ゆり', roman: 'yuri' },
  { kana: 'あさがお', roman: 'asagao' },
  { kana: 'ひまわり', roman: 'himawari' },
  { kana: 'つくし', roman: 'tsukushi' },
  { kana: 'なのはな', roman: 'nanohana' },
  { kana: 'きんもくせい', roman: 'kinmokusei' },
  { kana: 'すずらん', roman: 'suzuran' },

  // 時間・季節
  { kana: 'はる', roman: 'haru' },
  { kana: 'なつ', roman: 'natsu' },
  { kana: 'あき', roman: 'aki' },
  { kana: 'ふゆ', roman: 'fuyu' },
  { kana: 'よい', roman: 'yoi' },
  { kana: 'よなか', roman: 'yonaka' },
  { kana: 'あけがた', roman: 'akegata' },
  { kana: 'ひので', roman: 'hinode' },
  { kana: 'こはる', roman: 'koharu' },
  { kana: 'まひる', roman: 'mahiru' },
  { kana: 'ゆうぐれ', roman: 'yugure' },
  { kana: 'わかつき', roman: 'wakatsuki' },
  { kana: 'ついたち', roman: 'tsuitachi' },
  { kana: 'ながつき', roman: 'nagatsuki' },

  // 紙・手紙
  { kana: 'てがみ', roman: 'tegami' },
  { kana: 'ふみ', roman: 'fumi' },
  { kana: 'すみ', roman: 'sumi' },
  { kana: 'ふで', roman: 'fude' },
  { kana: 'わし', roman: 'washi' },
  { kana: 'しおり', roman: 'shiori' },
  { kana: 'たんざく', roman: 'tanzaku' },
  { kana: 'はんし', roman: 'hanshi' },
  { kana: 'まきもの', roman: 'makimono' },
  { kana: 'すみばこ', roman: 'sumibako' },

  // 記憶・気配
  { kana: 'おもいで', roman: 'omoide' },
  { kana: 'きおく', roman: 'kioku' },
  { kana: 'なごり', roman: 'nagori' },
  { kana: 'けはい', roman: 'kehai' },
  { kana: 'ひびき', roman: 'hibiki' },
  { kana: 'かおり', roman: 'kaori' },
  { kana: 'ぬくもり', roman: 'nukumori' },
  { kana: 'せいじゃく', roman: 'seijaku' },
  { kana: 'よいん', roman: 'yoin' },
  { kana: 'おもかげ', roman: 'omokage' },
  { kana: 'きざし', roman: 'kizashi' },
  { kana: 'いにしえ', roman: 'inishie' },

  // 生きもの
  { kana: 'ほたる', roman: 'hotaru' },
  { kana: 'つばめ', roman: 'tsubame' },
  { kana: 'すずめ', roman: 'suzume' },
  { kana: 'せみ', roman: 'semi' },
  { kana: 'こい', roman: 'koi' },
  { kana: 'つる', roman: 'tsuru' },
  { kana: 'しか', roman: 'shika' },
  { kana: 'ひばり', roman: 'hibari' },
  { kana: 'かわせみ', roman: 'kawasemi' },
  { kana: 'めだか', roman: 'medaka' },
  { kana: 'とんぼ', roman: 'tonbo' },
  { kana: 'こおろぎ', roman: 'koorogi' },

  // 音
  { kana: 'すず', roman: 'suzu' },
  { kana: 'かね', roman: 'kane' },
  { kana: 'ふうりん', roman: 'furin' },
  { kana: 'あしおと', roman: 'ashioto' },
  { kana: 'ささやき', roman: 'sasayaki' },
  { kana: 'といき', roman: 'toiki' },
  { kana: 'こだま', roman: 'kodama' },
  { kana: 'しおさい', roman: 'shiosai' },

  // 住まい
  { kana: 'えんがわ', roman: 'engawa' },
  { kana: 'しょうじ', roman: 'shoji' },
  { kana: 'ふすま', roman: 'fusuma' },
  { kana: 'たたみ', roman: 'tatami' },
  { kana: 'のれん', roman: 'noren' },
  { kana: 'すだれ', roman: 'sudare' },
  { kana: 'つくばい', roman: 'tsukubai' },
  { kana: 'あんどん', roman: 'andon' },
  { kana: 'ろうそく', roman: 'rosoku' },
  { kana: 'どま', roman: 'doma' },
  { kana: 'なかにわ', roman: 'nakaniwa' },
  { kana: 'はしら', roman: 'hashira' },
];

/// 住所は3語つなぎ。語彙が130前後なので組み合わせは約200万通り
export const ADDRESS_WORD_COUNT = 3;
/// 区切りは中黒。日本語の並記として自然な記号
export const ADDRESS_SEPARATOR = '・';

/// ひらがな・ローマ字のどちらからでも正規表記(かな)を引ける表
const WORD_LOOKUP = new Map<string, string>();
for (const word of ADDRESS_WORDS) {
  WORD_LOOKUP.set(word.kana, word.kana);
  WORD_LOOKUP.set(word.roman, word.kana);
}

/// カタカナをひらがなに寄せる
function toHiragana(text: string): string {
  return text.replace(/[ァ-ヶ]/g, (char) =>
    String.fromCharCode(char.charCodeAt(0) - 0x60),
  );
}

/**
 * 入力された住所を正規表記に直す。引けなければ null。
 *
 * 相手から聞いて打つものなので、できるだけ寛容にする。
 * ひらがな・カタカナ・ローマ字を受け、区切りは中黒・ハイフン・空白・読点などを許す。
 */
export function normalizeAddress(input: string): string | null {
  const cleaned = toHiragana(input.trim().toLowerCase())
    // 全角英数を半角に寄せる
    .replace(/[Ａ-Ｚａ-ｚ]/g, (char) =>
      String.fromCharCode(char.charCodeAt(0) - 0xfee0).toLowerCase(),
    );

  const tokens = cleaned
    .split(/[・･、,.\-‐-―_/\s]+/)
    .filter((token) => token.length > 0);

  if (tokens.length !== ADDRESS_WORD_COUNT) return null;

  const words: string[] = [];
  for (const token of tokens) {
    const kana = WORD_LOOKUP.get(token);
    if (kana === undefined) return null;
    words.push(kana);
  }
  return words.join(ADDRESS_SEPARATOR);
}

/// 正規表記になっているか(既存の住所を作り直すかの判断に使う)
export function isNormalizedAddress(address: string): boolean {
  return normalizeAddress(address) === address;
}
