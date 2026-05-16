# Part 2: ファイル取り込みの実践

## このPartでできるようになること

CSV、Excel、JSON Lines、ParquetをDuckDBで読み、複数ファイルの統合やソースファイル追跡ができるようになります。

このPartの主題は、単に `read_csv` や `read_json` の使い方を覚えることではありません。実務のファイル取り込みで重要なのは、「入力を信じすぎず、しかし失わずに受ける」ことです。

メーカー、部署、外部システム、AI-OCRなどから届くファイルは、形式も品質も揃っていません。列名が違う、型が違う、空欄がある、JSONだけネストしている、Excelだけシート名が違う、といったことが普通に起きます。

DuckDBは、こうしたバラバラな入力をSQLで観察し、raw層へ受け、後続の正規化へ渡すための道具として非常に便利です。

## このPartの設計思想

ファイル取り込みの設計思想は、「入力を信用しない。しかし、証拠として失わない」です。

実務の入力ファイルは、必ず揺れます。列順が変わる、列名が変わる、価格表記が変わる、Excelのシート名が変わる、JSONのネストが変わる。これらをすべて取り込み時点で正しく直そうとすると、raw層が業務判断だらけになり、後で原因を追えなくなります。

raw層は、きれいなデータを作る場所ではありません。入力の事実を、後から説明できる形で保存する場所です。

## なぜこの考え方が必要なのか

データ品質問題が起きた時、必要になるのは「どの行が悪いか」だけではありません。「どのファイルから来たのか」「どのbatchで入ったのか」「元の値は何だったのか」「どの入力元へ確認すべきか」です。

`filename = true`、`batch_id`、`ingest_date` は、ただの便利な列ではありません。データの説明責任を支える列です。これらを残さないと、品質チェックは件数だけの報告になり、実務の改善に繋がりません。

## 初心者が誤解しやすいこと

初心者は、取り込み時にできるだけきれいなテーブルを作ろうとします。価格を数値にし、カテゴリを寄せ、不正行を落とし、重複を消す。これは短期的には気持ちよく見えますが、入力の証拠を壊す危険があります。

取り込み時点で直しすぎると、後で「なぜこの価格になったのか」「なぜこの行が消えたのか」を説明できません。raw層では、まず受ける。直すのはstaging、判断するのは品質チェックです。

## プロはどう判断するか

プロは、ファイル形式ごとの差を無理に隠しません。CSV、Excel、JSONをいったん別rawテーブルに受け、それぞれの壊れ方を観察できるようにします。そのうえで、共通スキーマへ寄せます。

また、DuckDBの機能で吸収する問題と、入力元との契約で解決する問題を分けます。列順の違いは `union_by_name` で吸収できます。しかし、1行の意味が変わった、列名が毎週変わる、Excelに小計行が混ざる、といった問題は、入力契約の見直しが必要です。

## 背景にある設計原則

ファイル取り込みの背景には、データ処理における証拠保全の考え方があります。入力ファイルは、後から「なぜこの出力になったのか」を説明するための証拠です。取り込み時点で勝手に直したり、落としたり、出どころを消したりすると、後で説明できません。

raw層は、データをきれいにする場所ではなく、入力の証拠を保持する場所です。この思想があるから、`all_varchar = true` でまず受ける、`filename` を残す、形式ごとにrawテーブルを分ける、`UNION ALL` で勝手に重複排除しない、という設計になります。

ここでのトレードオフは、raw層が一見汚く見えることです。NULLになる前の空文字、数値化される前の価格、マスタに合わないカテゴリが残ります。しかし、その汚さは失敗ではありません。後で検証するための材料です。rawをきれいに見せることより、後で説明できることを優先します。

## まず知るべき言葉

- glob: `**/*.csv` のように複数ファイルを指定する書き方
- union by name: 列名で合わせて結合する読み方
- filename: 入力ファイル名を列として残す設定
- lineage: データがどこから来たかの追跡情報
- schema drift: ファイルごとに列や型が少しずつ変わること
- JSON Lines: 1行に1つのJSONがある形式
- flattening: ネストしたJSONを表の列へ展開すること
- Parquet dataset: 複数Parquetファイルをディレクトリ単位で扱う構成

## ファイル取り込みで一番大事な考え方

ファイル取り込みでは、最初からきれいなデータを作ろうとしすぎないことが重要です。

初心者は、入力直後に次のことをやりがちです。

- 価格をすぐ数値にする
- 不正な行を読み込み時に捨てる
- カテゴリ名を勝手に修正する
- どのファイルから来たかを残さない
- 形式ごとの違いを無理に隠す

これは短期的には楽に見えますが、後で問題が起きたときに原因を追えなくなります。

実務では、raw層に次の3つの性質を持たせます。

1. 落とさない
2. 勝手に直さない
3. 出どころを残す

このPartのSQLは、すべてこの考え方に沿っています。

## 手順1: 複数CSVをまとめて読む

まず、複数のCSVをまとめて読みます。

```bash
cd product-data-duckdb
duckdb
```

```sql
SELECT *
FROM read_csv(
  'data/incoming/**/*.csv',
  header = true,
  union_by_name = true,
  filename = true,
  all_varchar = true
)
LIMIT 10;
```

ここで使っている設定には、それぞれ実務上の意味があります。

| 設定 | 意味 | なぜ重要か |
| --- | --- | --- |
| `data/incoming/**/*.csv` | サブディレクトリ配下のCSVをまとめて読む | メーカーごとにフォルダが分かれていても扱える |
| `header = true` | 先頭行を列名として読む | 列名で意味を扱える |
| `union_by_name = true` | 列名で合わせて結合する | 列順の違いでデータが壊れるのを防ぐ |
| `filename = true` | ファイル名を列として残す | 不正データの出どころを追える |
| `all_varchar = true` | すべて文字列として読む | 型崩れで読み込みが止まるのを防ぐ |

見るポイントは `filename` 列です。実務では「この不正データはどのファイルから来たか」を追えることが重要です。

たとえば、価格が不正な行を見つけても、ファイル名がなければ誰に差し戻すべきか分かりません。`filename` は単なる補助情報ではなく、データ品質改善のための証拠です。

## globとディレクトリ設計

`data/incoming/**/*.csv` の `**` は、配下のディレクトリを再帰的に見る指定です。

このチュートリアルでは、入力ファイルを次のように置いています。

```text
data/incoming/
  maker_a/products.csv
  maker_b/products.csv
  maker_c/catalog.xlsx
  ai_ocr/extractions.jsonl
```

メーカー別、入力元別にディレクトリを分けると、後から問題を調査しやすくなります。ファイル名だけでなく、パス自体がメタデータになります。

ただし、globで何でも読む設計には注意も必要です。意図しない一時ファイルや古いファイルが混ざると、結果が変わります。実務では、取り込み対象ディレクトリ、ファイル命名規則、処理済みファイルの移動ルールを決めます。

このチュートリアルでは単純化していますが、Part 9の運用設計では、再実行性やバッチ単位の考え方に進みます。

## union_by_nameの意味

複数CSVを読むとき、列順だけで結合すると危険です。

たとえば、あるファイルが次の順番だとします。

```text
jan_code,product_name,price,category_name
```

別のファイルが次の順番だった場合、列順で結合すると意味が壊れます。

```text
product_name,jan_code,category_name,price
```

`union_by_name = true` は、列の位置ではなく列名で合わせる指定です。これはschema driftへの基本的な防御です。

ただし、列名が完全に違う場合までは自動で解決できません。たとえば `jan_code` と `JAN` と `barcode` は、DuckDBから見ると別の列です。その場合は、取り込みSQLで標準列名へ寄せる必要があります。

このチュートリアルの完成実装では、CSV、Excel、JSONをそれぞれ読み、最終的に `raw.products` の共通列へ揃えています。

## 手順2: Excelを読む

Excelを読むには、Excel拡張を使います。

```sql
INSTALL excel;
LOAD excel;

SELECT *
FROM read_xlsx(
  'data/incoming/maker_c/catalog.xlsx',
  sheet = '商品一覧',
  header = true,
  all_varchar = true
)
LIMIT 5;
```

Excelは業務では非常によく使われますが、取り込み元としては壊れやすい形式です。

よくある問題は次の通りです。

- シート名が変わる
- 先頭に説明行が入る
- ヘッダーが2行になる
- セル結合がある
- 空行や小計行が混ざる
- 人間向けの見た目が優先され、機械処理しにくい

このチュートリアルのExcelは扱いやすいサンプルですが、実務では「取り込み用シート」を決める、ヘッダー行を固定する、セル結合を禁止する、などのルール化が必要です。

DuckDBでExcelを読めることは便利ですが、Excelを無制限に許容するという意味ではありません。読めるからこそ、どのような形式なら安定して読めるかを明文化できます。

## 手順3: JSON Linesを読む

AI-OCRや外部APIの出力では、JSON Linesがよく使われます。1行に1つのJSONが入っている形式です。

```sql
SELECT
  product->>'jan_code' AS jan_code,
  product->>'name' AS product_name,
  product->>'price_text' AS price,
  product->>'category' AS category_name,
  maker->>'name' AS maker_name,
  extraction->>'updated_at' AS updated_at,
  filename
FROM read_json(
  'data/incoming/ai_ocr/*.jsonl',
  format = 'newline_delimited',
  filename = true
)
LIMIT 5;
```

CSVやExcelは最初から表形式に近いですが、JSONはネストしていることがあります。このSQLでは、`product`、`maker`、`extraction` の中から必要な値を取り出し、表の列へ変換しています。

`product->>'jan_code'` は、JSONオブジェクトの `product` の中にある `jan_code` を文字列として取り出す、という意味です。

ここでも `filename` を残しています。AI-OCRの結果は、後から原画像や抽出ジョブに戻って確認したくなることがあります。出どころを失うと、OCRミスなのか、元画像が悪いのか、後続処理が悪いのかを切り分けられません。

## JSONを表に寄せるときの判断

JSONには、CSVより自由な構造を持てるという利点があります。一方で、分析や品質チェックでは、最終的に行と列の形へ寄せた方が扱いやすくなります。

このチュートリアルでは、商品1件を1行にします。

```text
jan_code | product_name | price | category_name | maker_name | updated_at | filename
```

この「1行が何を表すか」を決めることは、取り込み設計で非常に重要です。1行が商品なのか、商品画像なのか、OCR抽出結果なのかによって、後続の重複排除や品質チェックの意味が変わります。

ここでは、CSV、Excel、JSONのすべてを「商品候補1件」としてraw層へ寄せます。

## 手順4: raw層へ統合する

完成例では `sql/02_load_raw.sql` がこの処理を行います。

```bash
sed -n '1,180p' sql/02_load_raw.sql
```

CSV、Excel、JSONをそれぞれrawテーブルに読み、最後に `raw.products` へ `UNION ALL` しています。

`UNION ALL` を使うのは、入力行を勝手に重複排除しないためです。通常の `UNION` は重複行をまとめる可能性がありますが、raw層ではそれを避けます。

raw層では、同じ商品が複数ファイルに出てきても、その事実を残します。重複かどうか、どちらを優先するかは、Part 3のstaging層で明示的に決めます。

完成実装の `raw.products` には、次のような共通列があります。

| 列 | 意味 |
| --- | --- |
| `jan_code` | 商品の識別候補 |
| `product_name` | 商品名 |
| `price` | 価格文字列 |
| `category_name` | 入力元のカテゴリ名 |
| `maker_name` | メーカー名 |
| `updated_at` | 入力元での更新日 |
| `filename` | 元ファイル |
| `batch_id` | 取り込みバッチ |
| `ingest_date` | 取り込み日 |

`batch_id` と `ingest_date` は、運用で重要になります。いつ取り込んだデータなのかを残しておくと、後から「先週の取り込みと結果が違う」問題を調査できます。

## 手順5: マスタを読む

完成実装では、SQLiteに入ったカテゴリマスタも読みます。

```sql
ATTACH 'data/master/master.sqlite' AS master_db (TYPE sqlite, READ_ONLY);

CREATE OR REPLACE TABLE master.categories AS
SELECT
  category_id::INTEGER AS category_id,
  lower(trim(category_name)) AS category_name
FROM master_db.categories;
```

ここで重要なのは、入力ファイルだけでなく、基準データもDuckDBへ取り込んでいることです。カテゴリが正しいかどうかは、入力ファイルだけを見ても判断できません。マスタと照合して初めて、未知カテゴリを分類できます。

`READ_ONLY` でATTACHしているのは、DuckDB側の処理でマスタ元を不用意に変更しないためです。分析や検証の処理では、外部の正規データを読むだけにする方が安全です。

## 手順6: Parquetを読む

`make run` 後にParquetが出力されます。

```bash
make run
```

```sql
SELECT count(*) AS rows
FROM read_parquet('output/products.parquet');
```

Parquetは、分析向けの列指向ファイル形式です。CSVよりも型情報を持ちやすく、圧縮や列選択に向いています。

CSVは人間が見やすく、受け渡ししやすい形式です。一方で、大量データの分析や機械処理ではParquetが有利です。このチュートリアルでは、バラバラな入力をDuckDBで整え、最終的にParquetとして出力します。

partitioned datasetも読めます。

```sql
SELECT category_name, count(*) AS rows
FROM read_parquet('output/products_by_category/**/*.parquet', hive_partitioning = true)
GROUP BY category_name
ORDER BY category_name;
```

partitioned datasetは、1つの巨大ファイルではなく、ディレクトリ構造で分割したParquet群です。カテゴリや日付で分けておくと、後で必要な範囲だけを読みやすくなります。

## ファイル形式ごとの使い分け

このPartでは複数形式を扱います。それぞれ役割が違います。

| 形式 | 得意なこと | 注意点 |
| --- | --- | --- |
| CSV | 人間が見やすい、広く使える | 型が弱い、カンマや改行で壊れやすい |
| Excel | 業務ユーザーが編集しやすい | レイアウトが自由すぎて取り込みに弱い |
| JSON Lines | APIやAI出力を1件ずつ表現しやすい | ネストを表へ寄せる設計が必要 |
| Parquet | 分析・圧縮・列選択に強い | 人間が直接読む形式ではない |

DuckDBはこれらを同じSQLの世界へ持ち込めます。ただし、形式の違いが消えるわけではありません。違いを理解した上で、raw層に受け、staging層で標準化します。

## 入力契約をどう決めるか

ファイル取り込みで重要なのは、SQLを書く前に「入力契約」を決めることです。

入力契約とは、入力元に対して期待する最低限の約束です。

たとえば商品ファイルなら、次のような項目があります。

- 1行が商品候補1件を表す
- JANコード列が存在する
- 商品名列が存在する
- 価格列が存在する
- カテゴリ名列が存在する
- ファイル名やフォルダ名から入力元を追跡できる
- 文字コードやヘッダー行が決まっている
- 取り込み対象外のメモ行や小計行を入れない

実務では、入力契約が曖昧なままSQLだけで吸収しようとすると、取り込みSQLが複雑になり続けます。DuckDBは多くの形式を読めますが、壊れた業務プロセスまで自動で直してくれるわけではありません。

良い取り込み設計は、SQLの頑張りだけでなく、入力元とのルール作りも含みます。

```text
入力元のルール
  +
DuckDBの取り込みSQL
  +
品質チェック
```

この3つを組み合わせて、安定したパイプラインを作ります。

## schema driftへの向き合い方

schema driftとは、入力ファイルの列や型が少しずつ変わることです。

例:

```text
1週目: jan_code,product_name,price,category_name
2週目: jan_code,product_name,price,category_name,maker_comment
3週目: JAN,product_name,price_text,category_name
```

2週目のように列が追加されるだけなら、`union_by_name = true` や列明示で吸収しやすいです。3週目のように列名が変わると、別の対応が必要です。

schema driftへの対応には段階があります。

| 変化 | 対応 |
| --- | --- |
| 列順が変わる | `union_by_name = true` |
| 任意列が追加される | 必要列だけSELECTする |
| 列名が変わる | 入力元別にマッピングする |
| 型表記が変わる | rawでは文字列、stagingで変換する |
| 1行の意味が変わる | 入力契約を見直す |

DuckDBの機能で吸収できる変化と、業務ルールとして入力元へ確認すべき変化を分けます。

列名が `jan_code` から `JAN` に変わった場合、SQLで対応することはできます。しかし、なぜ変わったのかを確認しないと、来週また別の名前になるかもしれません。

## ファイル別rawテーブルを作る理由

完成実装では、CSV、Excel、JSONを一気に `raw.products` へ入れるのではなく、いったん次のテーブルに分けています。

```text
raw.products_csv
raw.products_excel
raw.products_json
```

これは冗長に見えるかもしれません。しかし、実務では有効です。

理由:

- 形式ごとの読み込みエラーを切り分けやすい
- JSON flatteningの結果を確認しやすい
- Excel特有の列やシート問題を調査しやすい
- CSVだけ行数が増えた場合に原因を追いやすい
- 統合前の状態を観察できる

いきなり1つのrawテーブルに入れると、問題が起きたときに、CSV由来なのかExcel由来なのかJSON由来なのかを切り分けにくくなります。

ファイル形式ごとにrawテーブルを持ち、最後に共通スキーマへ `UNION ALL` する構成は、少し手間ですが調査に強い設計です。

## 取り込みで「直しすぎない」こと

ファイル取り込み段階では、データを直しすぎないことが重要です。

たとえば、価格に `1,200円` と入っていたとします。取り込み時に正規表現で `1200` へ直すことはできます。しかし、そのルールが全入力に対して正しいとは限りません。

別の例では、カテゴリに `食品` と入っていたとします。これを取り込み時に `food` へ変換することもできます。しかし、カテゴリマスタのどの値へ対応させるかは業務ルールです。

raw層でやってよいこと:

- ファイルを読む
- 列を共通名へ寄せる
- ファイル名を残す
- batch情報を付ける
- 形式ごとの差を最小限吸収する

raw層で慎重に扱うこと:

- 価格を補正する
- カテゴリを推測で変換する
- 不正行を捨てる
- 重複を削除する
- 欠損値を埋める

修正はstaging層、判断は品質チェックへ回します。raw層は、入力の証拠保全に近い役割です。

## 取り込みレビューの観点

取り込みSQLをレビューするときは、次を確認します。

- 入力ファイルの範囲が明確か
- 意図しないファイルをglobで読まないか
- 列名で結合しているか
- ファイル名や入力元を残しているか
- rawで型変換しすぎていないか
- 形式ごとの失敗を切り分けられるか
- batch_idやingest_dateが付いているか
- 外部マスタを読み取り専用で扱っているか

このレビュー観点があると、「SQLが動くか」だけではなく、「後で調査できるか」を判断できます。

## よくあるつまずき

複数CSVを読むときに列順だけで合わせると壊れます。`union_by_name = true` を使うと、列名で合わせられます。

型推論は便利ですが、メーカーごとに価格の表記が違うと失敗します。まず `all_varchar = true` で読み、後で `try_cast` する方が原因調査しやすくなります。

`filename` を残さないと、品質チェックでエラー件数は分かっても、どのファイルを直すべきか分からなくなります。取り込み時点でlineageを残すことは、後工程の説明責任につながります。

Excelを読めるからといって、どんなExcelでも安定して読めるわけではありません。取り込み可能なシート構造を決めることも、パイプライン設計の一部です。

## auto readerは探索、本番寄り処理は明示する

DuckDBには `read_csv_auto` や `read_json_auto` のように、型や構造を自動推論して読む関数があります。これは初期調査では非常に便利です。

完成実装では、次で自動推論の行数確認を実行できます。

```bash
cd product-data-duckdb
make friendly-sql
```

`sql/13_friendly_sql.sql` の `mart.auto_reader_probe` は、CSVとJSON Linesをauto readerで読み、行数を確認します。

ただし、実務パイプライン本体では、読み込みオプションを明示する方が安全です。たとえばCSVでは `header`、`union_by_name`、`filename`、`all_varchar` を明示しています。

この使い分けが重要です。

| 場面 | 向いている読み方 |
| --- | --- |
| 中身をすばやく見る | `read_csv_auto` / `read_json_auto` |
| 再実行するパイプライン | 明示オプション付き `read_csv` / `read_json` |
| 汚い入力を原因調査したい | `all_varchar = true` で受け、後段で `try_cast` |

## Excel読み込みは `read_xlsx` を標準にする

DuckDBでは、Excelを読む方法として `excel` extensionの `read_xlsx` が使えます。地理空間データ向けの `spatial` extensionには `st_read` もありますが、このチュートリアルではExcel標準経路にしません。

理由は、商品情報パイプラインでは「Excelを表として読み、シート、ヘッダー、型推論を制御する」ことが中心だからです。地理空間データやGIS系ファイルを扱う場合は `spatial` を検討しますが、通常の商品カタログExcelでは `read_xlsx` の方が意図を説明しやすくなります。

## Parquet出力オプションを比較する

通常の出力では `zstd` 圧縮を使っています。発展演習では、`snappy` と `PER_THREAD_OUTPUT true` も確認できます。

```bash
make export-lab
```

`sql/16_export_options.sql` は、単一Parquetとスレッド別出力の例を作ります。重要なのは、オプションを暗記することではありません。後続が読みやすいファイル数、圧縮方式、出力先を選ぶことです。

## このPartに対応する実装ファイル

- `product-data-duckdb/sql/02_load_raw.sql`: CSV、Excel、JSON Lines、SQLiteマスタの読み込み
- `product-data-duckdb/sql/13_friendly_sql.sql`: auto readerとDuckDB便利SQLの例
- `product-data-duckdb/sql/16_export_options.sql`: Snappyとスレッド別Parquet出力の例
- `product-data-duckdb/data/incoming/`: 入力サンプル一式
- `product-data-duckdb/scripts/create_excel_sample.py`: Excelサンプル生成
- `product-data-duckdb/scripts/create_sqlite_master.py`: SQLiteマスタ生成

## 次のPartに進む条件

- CSV、Excel、JSONを読み分けられる
- `filename = true` の価値を説明できる
- `union_by_name = true` が防ぐ問題を説明できる
- raw層では入力の痕跡を残す理由を説明できる
- Parquetを最終出力形式として使う理由を説明できる
- auto readerを探索用、本番寄り読み込みを明示オプション付きにする理由を説明できる

## 公式docsで確認する箇所

- CSV Import: https://duckdb.org/docs/current/data/csv/overview.html
- JSON: https://duckdb.org/docs/current/data/json/overview.html
- Excel Extension: https://duckdb.org/docs/current/core_extensions/excel.html
- Parquet: https://duckdb.org/docs/current/data/parquet/overview.html
