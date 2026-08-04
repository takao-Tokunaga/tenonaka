/**
 * 住所に使う言葉。
 *
 * 住所は人が声に出して交換するものなので、意味のない乱数列にはしない。
 * 紙・光・水・季節・記憶といった、この手紙の世界に合う言葉だけを集めている。
 * どの組み合わせでも情景になるよう、負の意味を持つ語は入れていない。
 *
 * ローマ字は曖昧さを避けて素直に綴る(長音記号は使わない)。
 */
export const ADDRESS_WORDS = [
  // 光・天候
  'komorebi', // 木漏れ日
  'asahi', // 朝日
  'yudachi', // 夕立
  'kasumi', // 霞
  'oboro', // 朧
  'akatsuki', // 暁
  'tasogare', // 黄昏
  'yuyake', // 夕焼け
  'hinata', // 日向
  'kagero', // 陽炎
  'tsukiyo', // 月夜
  'hoshizora', // 星空
  'amaoto', // 雨音
  'kirisame', // 霧雨
  'harusame', // 春雨
  'shigure', // 時雨
  'yukiakari', // 雪明かり
  'tsuyu', // 露
  'niji', // 虹
  'kaze', // 風
  'hayate', // 疾風
  'nagi', // 凪
  'hikage', // 日陰
  'tsukikage', // 月影

  // 水・場所
  'nagisa', // 渚
  'minato', // 港
  'izumi', // 泉
  'kawara', // 河原
  'mizube', // 水辺
  'shimizu', // 清水
  'umibe', // 海辺
  'sazanami', // 細波
  'komichi', // 小径
  'ishidatami', // 石畳
  'nonaka', // 野中
  'okuyama', // 奥山
  'satoyama', // 里山
  'tanima', // 谷間

  // 植物
  'sakura', // 桜
  'tsubaki', // 椿
  'sumire', // 菫
  'fuji', // 藤
  'hasu', // 蓮
  'susuki', // 芒
  'momiji', // 紅葉
  'wakaba', // 若葉
  'kozue', // 梢
  'kaede', // 楓
  'yanagi', // 柳
  'tsuta', // 蔦
  'koke', // 苔
  'take', // 竹
  'matsu', // 松
  'ume', // 梅
  'kiku', // 菊
  'yuri', // 百合
  'asagao', // 朝顔
  'himawari', // 向日葵
  'tsukushi', // 土筆
  'nanohana', // 菜の花
  'kinmokusei', // 金木犀
  'suzuran', // 鈴蘭

  // 時間・季節
  'haru', // 春
  'natsu', // 夏
  'aki', // 秋
  'fuyu', // 冬
  'yoi', // 宵
  'yonaka', // 夜半
  'akegata', // 明け方
  'hinode', // 日の出
  'koharu', // 小春
  'mahiru', // 真昼
  'yugure', // 夕暮れ
  'wakatsuki', // 若月
  'tsuitachi', // 朔日
  'nagatsuki', // 長月

  // 紙・手紙
  'tegami', // 手紙
  'fumi', // 文
  'sumi', // 墨
  'fude', // 筆
  'washi', // 和紙
  'shiori', // 栞
  'tanzaku', // 短冊
  'hanshi', // 半紙
  'makimono', // 巻物
  'sumibako', // 墨箱

  // 記憶・気配
  'omoide', // 思い出
  'kioku', // 記憶
  'nagori', // 名残
  'kehai', // 気配
  'hibiki', // 響き
  'kaori', // 香り
  'nukumori', // 温もり
  'seijaku', // 静寂
  'yoin', // 余韻
  'omokage', // 面影
  'kizashi', // 兆し
  'inishie', // 古

  // 生きもの
  'hotaru', // 蛍
  'tsubame', // 燕
  'suzume', // 雀
  'semi', // 蝉
  'koi', // 鯉
  'tsuru', // 鶴
  'shika', // 鹿
  'hibari', // 雲雀
  'kawasemi', // 翡翠
  'medaka', // 目高
  'tonbo', // 蜻蛉
  'kohrogi', // 蟋蟀

  // 音
  'suzu', // 鈴
  'kane', // 鐘
  'furin', // 風鈴
  'ashioto', // 足音
  'sasayaki', // 囁き
  'toiki', // 吐息
  'kodama', // 木霊
  'shiosai', // 潮騒

  // 住まい
  'engawa', // 縁側
  'shoji', // 障子
  'fusuma', // 襖
  'tatami', // 畳
  'noren', // 暖簾
  'sudare', // 簾
  'tsukubai', // 蹲
  'andon', // 行灯
  'rosoku', // 蝋燭
  'doma', // 土間
  'nakaniwa', // 中庭
  'hashira', // 柱
] as const;

/// 住所は3語つなぎ。語彙が120前後なので、組み合わせは約170万通り
export const ADDRESS_WORD_COUNT = 3;
export const ADDRESS_SEPARATOR = '-';

/// 住所として妥当な形か(受け取った文字列を検証する用)
export const ADDRESS_PATTERN = new RegExp(
  `^[a-z]{2,12}(${ADDRESS_SEPARATOR}[a-z]{2,12}){${ADDRESS_WORD_COUNT - 1}}$`,
);
