# Part 5: Python連携

## このPartでできるようになること

PythonからDuckDBを使い、SQL結果をDataFrameやNotebookで確認できるようになります。pandas/Polarsとの使い分けも説明します。

このPartの主題は、Python APIの呼び方を覚えることではありません。DuckDB、Python、Notebook、DataFrameの責務を分け、探索と本番処理を混ぜない設計を学ぶことです。

Part 4までで、DuckDB内にraw、staging、martの流れを作りました。Part 5では、その結果をPythonからどう観察し、どう自動化境界へ渡すかを扱います。

## このPartの設計思想

Python連携の思想は、「Pythonで何でも処理する」ことではなく、「DuckDBとPythonの責務を分ける」ことです。

DuckDBは、ファイル読み込み、JOIN、集計、品質チェック、Parquet出力に向いています。Pythonは、観察、可視化、外部連携、JSON整形、レポート生成に向いています。両者は競合ではなく、境界を決めて組み合わせる道具です。

## なぜこの考え方が必要なのか

Notebookやpandasは便利です。しかし便利さのために、処理本体、探索、可視化、出力、品質判断が1つのNotebookに混ざりやすくなります。そうなると、レビューしにくく、再実行しにくく、アプリやバッチから使いにくくなります。

このチュートリアルでは、SQLを処理本体、Notebookを観察、Python CLIをJSON契約の境界として扱います。これは、実務で処理を説明し、再実行し、他システムから使えるようにするためです。

## 初心者が誤解しやすいこと

初心者は、DataFrameに読み込んだ瞬間に自由になったと感じます。しかし、大きなデータを全部Pythonへ持ってくると、DuckDBの列選択、条件pushdown、SQLレビューの利点を捨てることがあります。

また、Notebookで作った分析がそのまま本番処理になると考えがちです。Notebookは思考の場です。本番処理の正本は、SQLファイルやCLIとして切り出すべきです。

## プロはどう判断するか

プロは、Pythonに渡す前に「本当に全行が必要か」を考えます。DuckDBで絞れるなら絞る。DuckDBで集計できるなら集計する。Pythonへ渡すのは、可視化や外部連携に必要な小さな結果にする。

また、Python CLIのJSON出力を契約として扱います。フィールド名、型、exit codeを安定させることで、アプリやバッチはDuckDB内部のSQLを知らずに品質判断できます。

## 背景にある設計原則

Python連携の背景にある原則は、探索と本番処理を分けることです。NotebookやDataFrameは探索に向いています。仮説を試し、可視化し、人に説明するには強力です。しかし、毎回同じ順番で動かす処理、レビューしたい処理、アプリから呼びたい処理をNotebookに閉じ込めると、運用が難しくなります。

DuckDBとPythonの関係は、上下関係ではありません。DuckDBは表データの読み取り、結合、集計、出力を担当し、Pythonは観察、整形、外部連携、レポート生成を担当します。この役割分担があるから、SQLファイル、Notebook、CLIがそれぞれ意味を持ちます。

ここでのトレードオフは、自由さと再現性です。Pythonだけで書けば自由です。しかし自由な処理は、レビューと再実行が難しくなります。DuckDBに寄せすぎると、Pythonライブラリの強みを使いにくくなります。境界を決めることで、両方の利点を使います。

## まず知るべき言葉

- connection: DuckDBへの接続
- relation: DuckDBが遅延評価できる表現
- DataFrame: Python上の表形式データ
- notebook: 対話的に分析する環境
- boundary: DuckDBとPythonの役割の境界
- materialize: 遅延評価の結果を実データとして取り出すこと
- reproducibility: 同じ入力から同じ結果を再現できること
- contract: 他の処理が依存してよい入出力の約束

## Python連携で大事な考え方

DuckDBとPythonは、どちらか一方を選ぶものではありません。役割を分けて使います。

DuckDBが得意なこと:

- CSV、JSON、Excel、Parquetを読む
- SQLでJOIN、集計、ウィンドウ関数を使う
- 大きなParquetから必要な列だけ読む
- raw/staging/martの変換を再実行可能にする
- 品質チェック結果をテーブルとして保持する

Pythonが得意なこと:

- 可視化ライブラリを使う
- APIや外部サービスと連携する
- JSONを整形して返す
- ファイルやコマンドの制御を書く
- Notebookで仮説検証する

初心者がやりがちな失敗は、Notebookにすべてを書いてしまうことです。最初は速く見えますが、レビューしにくく、再実行しにくく、バッチ化しにくくなります。

このチュートリアルでは、次の分担を基本にします。

```text
SQLファイル    変換・品質チェックの正本
DuckDB DB      実行結果と中間テーブル
Notebook       観察・仮説検証
Python CLI     自動化境界、JSON出力、レポート生成
```

## 手順1: Python APIの基本

Pythonパッケージがある環境では、次のように使えます。

```python
import duckdb

con = duckdb.connect("product_pipeline.duckdb")
rows = con.sql("""
    SELECT category_name, count(*) AS product_count
    FROM staging.normalized_products
    GROUP BY category_name
    ORDER BY product_count DESC
""").fetchall()

print(rows)
```

このコードは、DuckDBファイルをPythonから開き、SQLを実行し、結果をPythonのリストとして取り出しています。

ここで大事なのは、PythonがSQLの代わりをしているわけではないことです。集計の定義はSQLにあります。Pythonは、その結果を受け取り、表示したり、JSONへ変換したり、Notebookで観察したりする役目です。

小さい結果なら `fetchall()` で十分です。しかし、大きなテーブルをそのままPythonへ全部取り出すのは避けます。メモリ使用量が増え、DuckDBの列指向処理やpushdownの利点を失います。

基本方針は次の通りです。

1. DuckDB側で絞り込み、JOIN、集計を済ませる
2. Pythonへ渡すのは、観察や出力に必要な結果だけにする
3. 大きな成果物はDataFrameではなくParquetとして保存する

このリポジトリの検証環境ではDuckDB CLIを標準ルートにしています。Pythonパッケージがない場合でも、完成例のCLIベース処理は動きます。

## DuckDB Python APIとCLI境界

PythonからDuckDBを使う方法は、大きく2つあります。

| 方法 | 特徴 | 向いている場面 |
| --- | --- | --- |
| Python API | `duckdb.connect()` で直接実行する | Notebook、Python中心の分析 |
| CLI呼び出し | `duckdb -json ...` をsubprocessで呼ぶ | 依存を増やさないCLI、自動化境界 |

このチュートリアルの `scripts/check_quality.py` は、Python標準ライブラリからDuckDB CLIを呼びます。これは、PythonのDuckDBパッケージを必須にしないためです。

依存を増やさず、DuckDB CLIを唯一の実行エンジンとして扱うと、環境差分を減らせます。一方で、Notebook内で対話的に分析するならPython APIの方が書きやすいです。

どちらが正しいかではなく、どこを境界にしたいかで選びます。

## 手順2: Notebookを見る

完成例にはNotebookがあります。

```bash
cd product-data-duckdb
make run
jupyter notebook notebooks/quality_analysis.ipynb
```

Notebookでは、品質レポートとParquet出力を確認します。Notebookは探索に向いていますが、毎回実行する本番処理はSQLファイルやスクリプトに切り出します。

Notebookに置いてよいもの:

- 集計結果の観察
- グラフ化
- 仮説検証
- レポートの下書き
- SQL結果のサンプル確認

Notebookに置きっぱなしにしない方がよいもの:

- 本番の取り込み処理
- 品質チェックの正本
- Parquet出力の定義
- アプリが依存するJSON契約
- 毎日実行するバッチ処理

Notebookは思考の場です。パイプラインの正本ではありません。

## 手順3: pandasとの使い分け

pandasはPython内で細かいデータ加工をするのに便利です。DuckDBはSQLでファイルを直接読み、JOINや集計を行うのに向いています。

使い分けの目安:

- ファイルを読む、JOINする、集計する: DuckDB
- Pythonのライブラリで可視化する: pandas/Notebook
- 複雑なPython関数を行ごとに適用する: pandas
- 大きなParquetを必要な列だけ読む: DuckDB
- 小さな集計結果をグラフにする: pandas

たとえば、カテゴリ別商品数をグラフ化したい場合、全商品行をpandasへ持ってくる必要はありません。DuckDBでカテゴリ別に集計し、その小さな結果だけをpandasへ渡します。

```text
悪い例: 全商品行をDataFrameへ読み、Pythonでgroupbyする
良い例: DuckDBでGROUP BYし、集計結果だけDataFrameへ渡す
```

もちろん、pandasが悪いわけではありません。Pythonライブラリと密接に組み合わせる処理、可視化、細かい探索では非常に便利です。問題は、SQLで自然に表現できる処理までNotebook内のpandasに閉じ込めてしまうことです。

## 手順4: Polarsとの使い分け

Polarsも高速なDataFrameライブラリです。Pythonコード中心でパイプラインを書くならPolarsは強力です。一方、SQL資産やDB連携、複数形式のファイル読み込みを中心にするならDuckDBが読みやすくなります。

判断軸は速度だけではありません。

- チームがSQLを読めるか
- 既存のDWHやDBと同じSQL思考で保守したいか
- Pythonアプリとして組む方が自然か
- 外部DBやファイル形式を横断する必要があるか
- NotebookだけでなくCLIやMakefileから再実行できるか

DuckDB、pandas、Polarsは競合というより、境界を決めて組み合わせる道具です。

このチュートリアルでは、パイプラインの正本をSQLに置き、Pythonは観察と自動化境界に使います。これにより、SQLファイルをレビューしやすくなり、Makefileから同じ処理を再実行できます。

## 手順5: CLIスクリプトからJSONを返す

完成例の `scripts/check_quality.py` は、Python標準ライブラリからDuckDB CLIを呼び、品質チェック結果をJSONで返します。

```bash
cd product-data-duckdb
make run
python3 scripts/check_quality.py --db product_pipeline.duckdb
```

このスクリプトは、次の情報を返します。

- `ok`: チェック条件として成功か
- `totalErrors`: 品質エラー件数の合計
- `failingCheckCount`: エラーがあるチェック種類数
- `exportedRows`: `output/products.parquet` の行数
- `datasetRows`: カテゴリpartitioned datasetの行数
- `ingestDatasetRows`: 取り込み日partitioned datasetの行数
- `checks`: チェック名ごとの件数
- `failingChecks`: エラーがあるチェックだけ
- `failureReasons`: 失敗理由

このJSONは、画面に表示するためだけのものではありません。アプリやCI、バッチ、監視が判断するための契約です。

たとえば、`totalErrors` が一定数を超えたら失敗、`exportedRows` が0なら失敗、特定のチェックだけは許容しない、といった判断に使えます。

## exit codeと品質しきい値

`scripts/check_quality.py` には、品質チェックの失敗条件を指定するオプションがあります。

```bash
python3 scripts/check_quality.py --db product_pipeline.duckdb --fail-on-any-error
python3 scripts/check_quality.py --db product_pipeline.duckdb --max-errors 20
```

`--fail-on-any-error` は、品質エラーが1件でもあれば失敗します。厳密なパイプラインでは有効です。

`--max-errors` は、エラー件数が指定値を超えたら失敗します。現実の業務では、移行期や外部入力の品質が安定しない時期に、警告として許容する範囲を設けることがあります。

ここで重要なのは、品質判断を人間の目視だけにしないことです。JSONとexit codeにすることで、バッチやアプリから機械的に判断できます。

## Pythonに渡すデータ量を設計する

Python連携で最も多い失敗は、何でもDataFrameに読み込むことです。

小さいデータでは問題になりません。しかし、実務データが大きくなると、次の問題が出ます。

- メモリを使いすぎる
- Notebookが重くなる
- SQLで簡単にできる集計をPythonで再実装してしまう
- 同じ処理がSQL版とPython版で二重管理になる
- 結果の再現性がNotebookセル順に依存する

Pythonへ渡す前に、DuckDBでできるだけ絞ります。

悪い流れ:

```text
Parquet全体をDataFrameへ読む
  ↓
pandasでfilter
  ↓
pandasでgroupby
  ↓
小さな表を作る
```

良い流れ:

```text
DuckDBで必要列だけ読む
  ↓
DuckDBでfilter/group by
  ↓
小さな結果だけDataFrameへ渡す
```

境界を設計する時は、次の問いを使います。

- Python側で本当に全行が必要か
- グラフに必要なのは集計後の数十行ではないか
- JOINやfilterはSQLで済ませられないか
- Pythonでしかできない処理はどこか
- 結果をParquetとして残すべきか、DataFrameで十分か

DuckDBとPythonの境界は、性能だけでなく保守性の境界でもあります。

## Notebookをレビュー可能にする

Notebookは探索に強い一方、レビューが難しくなりがちです。

レビューしにくいNotebook:

- セルを上から順に実行しないと結果が変わる
- 途中の変数に依存している
- 本番処理がNotebook内にしかない
- 出力が大きすぎて差分が読めない
- データ取得、変換、可視化、判断が混ざっている

レビューしやすいNotebook:

- 冒頭で前提コマンドを書く
- 入力は生成済みParquetやDuckDBファイルに限定する
- 本体処理はSQLファイル側に置く
- Notebookは観察と説明に集中する
- 重要な集計は短いSQLとして明示する

このチュートリアルのNotebookは、パイプラインを作る場所ではなく、生成物を見る場所です。`make notebook-check` は、Notebookが最低限期待する構造を持っているか確認します。

Notebookを使うときは、次の役割分担を崩さないようにします。

```text
Makefile: 実行手順
SQL: データ処理の正本
Python CLI: JSON契約やレポート生成
Notebook: 観察、可視化、説明
```

## Python CLIを契約として扱う

`scripts/check_quality.py` は、単なる便利スクリプトではありません。品質チェック結果を外部に渡す契約です。

契約として見ると、次の点が重要になります。

- フィールド名を安定させる
- 数値は文字列ではなく数値として返す
- 成功/失敗を `ok` とexit codeで返す
- 失敗理由を機械が読める形にする
- DuckDBの内部テーブル構造を隠す

アプリやバッチが `mart.quality_report` のSQLを直接知っていると、内部構造を変えにくくなります。CLIがJSON契約を提供すれば、内部SQLを変更しても、外部インターフェースを保てます。

これは小さなプロジェクトでも重要です。最初から境界を作ると、後でWeb API化したり、Node.js版と揃えたりしやすくなります。

## pandas/Polarsへ逃がすべき処理

DuckDBで何でも書く必要はありません。Python側へ逃がした方が自然な処理もあります。

Pythonへ逃がしてよい処理:

- グラフ化
- HTMLレポート生成
- 外部API呼び出し
- 複雑な文字列処理
- 機械学習ライブラリとの接続
- 小さな集計結果の整形

DuckDBに残した方がよい処理:

- ファイル読み込み
- JOIN
- 集計
- 品質チェック
- Parquet出力
- 型変換やNULL処理

境界の目安は、「SQLとしてレビューしたいか」「Pythonライブラリの力が必要か」です。SQLで簡潔に書ける処理をPythonへ移すと、チームのレビュー負荷が上がることがあります。

## Python連携レビューの観点

Python連携をレビューするときは、次を確認します。

- DuckDBで絞ってからPythonへ渡しているか
- Notebookに本番処理が閉じていないか
- JSON契約のフィールド名が安定しているか
- exit codeで失敗を判断できるか
- Pythonパッケージ依存が必要最小限か
- SQLとPythonで同じロジックを二重実装していないか
- 大きなDataFrameを不用意に作っていないか

Pythonは便利ですが、便利さゆえに責務が膨らみやすい場所です。境界を明確にして使います。

## よくあるつまずき

Notebookにすべての処理を書くと、再実行やレビューが難しくなります。Notebookは観察、SQLファイルは処理本体、CLIは自動化の入口として分けます。

DataFrameに全部読み込むとメモリを使いすぎます。先にDuckDBで絞り込み・集計してからPythonへ渡します。

Python APIとCLI境界を混ぜすぎると、実行方法が散らばります。チーム内で「本番処理はMakefileとSQL」「観察はNotebook」「自動化出力はCLI」のように役割を決めます。

JSON出力に画面文言を入れすぎると、アプリが判断しにくくなります。機械が読むフィールドと、人間向けメッセージは分けます。

## このPartに対応する実装ファイル

- `product-data-duckdb/scripts/check_quality.py`: Pythonから品質結果をJSONで返すCLI
- `product-data-duckdb/scripts/create_quality_report.py`: HTML品質レポート生成
- `product-data-duckdb/scripts/check_notebook.py`: Notebook構造チェック
- `product-data-duckdb/notebooks/quality_analysis.ipynb`: 分析Notebook

## 次のPartに進む条件

- DuckDBとpandas/Polarsの役割分担を説明できる
- Notebookに置く処理とSQLファイルに置く処理を分けられる
- 品質チェック結果をPythonから取得できる
- JSON出力をアプリやバッチが依存する契約として説明できる
- DuckDBで集計してからPythonへ渡す理由を説明できる

## 公式docsで確認する箇所

- Python API: https://duckdb.org/docs/current/clients/python/overview
- Python Relational API: https://duckdb.org/docs/current/clients/python/relational_api
- Guides for Python: https://duckdb.org/docs/current/guides/python/overview
