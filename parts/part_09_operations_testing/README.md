# Part 9: 運用・設計・テスト

## このPartでできるようになること

DuckDB処理を再現可能なローカルパイプラインとして設計し、品質チェック、テスト、生成物管理を行えるようになります。

このPartの目的は、`make run` を覚えることではありません。データ処理を「手元でたまたま動いたSQL」から「誰が実行しても同じ順番で動き、期待値からのズレを検出できるパイプライン」へ引き上げることです。

DuckDBは軽く始められるため、最初はCLIでSQLを直接実行しがちです。しかし、実務では実行順、入力、生成物、品質条件、失敗時の対応を固定しないと、結果を信頼できません。

## このPartの設計思想

運用とテストの思想は、「動いた結果」ではなく「再現できる結果」を信頼することです。

データ処理は、1回動けば終わりではありません。入力が変わる、マスタが変わる、SQLが変わる、品質ルールが変わる。そのたびに、同じ手順で実行でき、期待値との差分を説明できる必要があります。

Makefile、`.gitignore`、SQLテスト、JSON CLIは、便利な補助物ではありません。人間の記憶や手順の揺れに依存しないための運用設計です。

## なぜこの考え方が必要なのか

実務で怖いのは、SQLが失敗することだけではありません。もっと怖いのは、間違った出力が成功したように見えることです。

`make run` が通っても、品質件数が変わっているかもしれません。Parquetに不正行が混ざっているかもしれません。partitioned datasetの行数がズレているかもしれません。だからテストと品質契約が必要です。

## 初心者が誤解しやすいこと

初心者は、READMEに手順を書けば運用できると考えがちです。しかし、人間が手で順番を守る運用はズレます。Makefileのように、手順を実行可能な形にする必要があります。

また、生成物をGitに入れれば安心だと考えることもあります。実際には、DBやParquetのような再生成可能なバイナリをGitに入れると、差分が読めず、レビューが難しくなります。管理すべきなのは生成物そのものではなく、生成方法と期待値です。

## プロはどう判断するか

プロは、パイプラインを「処理」ではなく「契約」として見ます。入力、実行順、品質条件、出力、テスト、生成物管理が揃って初めて、他者が使える成果物になります。

期待値が変わった時も、すぐにテストを書き換えません。入力変更か、仕様変更か、バグかを切り分けます。テストは障害物ではなく、変化を説明するための記録です。

## 背景にある設計原則

運用設計の背景にある原則は、人間の記憶に頼らないことです。データ処理は、手順、入力、環境、期待値のどれかが少し変わるだけで結果が変わります。READMEを読みながら人間が手で順番を守る運用は、学習にはよくても実務では不安定です。

Makefileは、手順を実行可能な契約にします。テストは、期待値を機械が確認できる契約にします。`.gitignore` は、何を正本として管理し、何を再生成物として扱うかの契約にします。これらは地味ですが、データパイプラインを他者が信頼するための土台です。

ここでのトレードオフは、柔軟性と再現性です。手でSQLを実行すれば柔軟ですが、再現しにくい。Makefileとテストで固定すれば少し窮屈ですが、他者が同じ結果を確認できます。実務では、再現性を優先する場面が多くなります。

## まず知るべき言葉

- reproducible: 同じ入力から同じ出力を作れる
- Makefile: 実行手順をターゲット化するファイル
- generated artifacts: DB、レポート、Parquetなどの生成物
- regression test: 期待結果が変わっていないか確認するテスト
- data contract: データ品質や件数の期待値
- idempotent: 同じ処理を再実行しても壊れない性質
- batch: ひとまとまりの取り込み単位
- operational runbook: 運用時に何をどう実行するかの手順

## 運用で一番大事なこと

データパイプラインの運用では、「SQLが正しいか」だけでは足りません。

次の問いに答えられる必要があります。

- どの順番で実行するのか
- 入力ファイルはどこに置くのか
- 生成物はどこに出るのか
- どの生成物をGit管理しないのか
- 品質チェックの期待値は何か
- 失敗したらどこを見ればよいのか
- 再実行してよいのか
- 出力を上書きしてよいのか

このチュートリアルでは、Makefile、`.gitignore`、SQLテスト、JSON CLI、HTMLレポートを使い、これらを小さく実装しています。

## 手順1: Makefileを読む

```bash
cd product-data-duckdb
sed -n '1,220p' Makefile
```

重要なターゲット:

| ターゲット | 役割 |
| --- | --- |
| `make samples` | ExcelサンプルとSQLiteマスタを生成 |
| `make run` | 標準パイプライン実行 |
| `make quality` | 品質レポート表示 |
| `make check-json` | Python CLIで品質結果をJSON表示 |
| `make check-node` | Node.js CLIで品質結果をJSON表示 |
| `make report` | HTML品質レポート生成 |
| `make profile` | Parquet読み取りのEXPLAIN結果を保存 |
| `make notebook-check` | Notebook構造を確認 |
| `make test` | SQLテスト実行 |
| `make clean` | 生成物削除 |

Makefileの価値は、コマンドを短くすることだけではありません。実行順をコードとして固定することです。

`make run` は、次の順番で動きます。

```text
samples
  -> sql/01_create_schemas.sql
  -> sql/02_load_raw.sql
  -> sql/03_normalize.sql
  -> sql/04_quality_checks.sql
  -> sql/05_export_parquet.sql
```

この順番をREADMEだけに書くと、人によって実行漏れが起きます。Makefileにすると、学習者も運用者も同じ入口を使えます。

## 手順2: 生成物をGit管理から外す

```bash
sed -n '1,80p' .gitignore
```

このプロジェクトでは、次の生成物をGit管理から外しています。

```text
product_pipeline.duckdb
product_pipeline.duckdb.wal
data/master/master.sqlite
reports/*.csv
reports/*.html
reports/*.txt
output/*.parquet
output/products_by_category/
output/products_by_ingest_date/
```

DBファイル、レポート、Parquet出力は再生成できるため、通常はGitに入れません。Gitに入れるのは入力サンプル、SQL、スクリプト、テストです。

判断基準は次の通りです。

| Gitに入れる | Gitに入れない |
| --- | --- |
| 入力サンプル | DuckDB DBファイル |
| SQLファイル | Parquet出力 |
| スクリプト | CSV/HTMLレポート |
| テスト | プロファイル結果 |
| README | SQLite生成物 |

生成物をGitに入れると、差分が読みにくくなります。特にParquetやDBファイルはバイナリであり、レビューに向きません。再生成可能なものはGitから外し、作り方をGitで管理します。

## 手順3: SQLテストを実行する

```bash
make run
make test
```

`tests/test_pipeline.sql` は、品質チェック件数と出力件数が期待通りか確認します。

テストで固定している主な期待値:

- `duplicate_jan_code` は1件
- `invalid_price` は4件
- `missing_jan_code` は2件
- `missing_product_name` は0件
- `unknown_category` は4件
- `output/products.parquet` は11行
- 出力Parquetに不正行が含まれない
- batch metadataが期待通りである
- partitioned datasetが11行である
- category partitionが期待カテゴリを持つ
- ingest date partitionが期待通りである

データパイプラインでは、行数やエラー件数の変化は仕様変更かバグかを判断する入口になります。

たとえば、`invalid_price` が4件から3件になった場合、良い変化かもしれません。入力データが改善されたのかもしれません。しかし、`try_cast` の条件を誤って変え、不正価格を見逃すようになった可能性もあります。

テストは「変化を禁止するもの」ではありません。変化に気づき、意図した変更かどうかを判断するためのものです。

## SQLテストの読み方

`tests/test_pipeline.sql` では、期待値をSQL内に書いています。

```sql
WITH expected(check_name, expected_count) AS (
  VALUES
    ('duplicate_jan_code', 1),
    ('invalid_price', 4),
    ('missing_jan_code', 2),
    ('missing_product_name', 0),
    ('unknown_category', 4)
)
```

この書き方により、品質チェックの契約が明示されます。

また、失敗時には `error(...)` を使って、期待値と実際値を表示します。

SQLテストでは、次のようなものを固定すると効果的です。

- 品質チェック件数
- 出力行数
- 出力に不正データが混ざっていないこと
- partitioned datasetの行数
- 必須メタデータの存在
- 代表的なカテゴリや日付の存在

逆に、毎回変わる値を不用意に固定するとテストが不安定になります。たとえば実行時刻や一時ファイル名をそのまま期待値にすると、再実行のたびに失敗します。

## 手順4: 品質チェックをCLI化する

```bash
make check-json
make check-node
```

品質チェックは人間が画面で見るだけではなく、コマンドとして失敗させられる形にします。このリポジトリではCI設定は追加しませんが、ローカルで同じチェックを実行できます。

CLI化の利点:

- Makefileから呼べる
- バッチに組み込める
- アプリから呼びやすい
- JSON契約として結果を渡せる
- exit codeで成功・失敗を判断できる

`make quality` は人間が表として見る入口です。`make check-json` と `make check-node` は、機械が判断しやすいJSONの入口です。

この2つを分けることで、人間向け表示とアプリ向け契約を混ぜずに済みます。

## 手順5: 生成物と成果物を分ける

このパイプラインでは、生成物にも種類があります。

| 種類 | 例 | 扱い |
| --- | --- | --- |
| 中間生成物 | `product_pipeline.duckdb` | 再生成可能、Git管理しない |
| 検査結果 | `reports/quality_report.csv` | 人間やCLIが確認、Git管理しない |
| エラー行 | `reports/product_errors.csv` | 入力元への差し戻しに使う |
| 配布成果物 | `output/products.parquet` | 後続分析やアプリが読む |
| partitioned dataset | `output/products_by_category/` | 分析・クラウド保存向け |

すべてを同じ「出力」と呼ぶと、扱いを間違えます。中間生成物は消して再実行してよいものです。配布成果物は、いつ作られたものか、どのbatchか、誰が使っているかを考える必要があります。

## 手順6: 運用設計を考える

実務では次を決めます。

- 入力ファイルをどこに置くか
- `batch_id` をどう決めるか
- 失敗時にどこから再実行するか
- エラー行を誰が確認するか
- Parquet出力をいつ上書きするか
- 古い出力をどう保管するか
- どの品質エラーを許容し、どれを失敗にするか
- 実行ログをどこに残すか

このチュートリアルでは、`batch_2026_05_10` と `ingest_date` を固定値として使っています。実務では、取り込み日、ファイル受領ID、ジョブIDなどからbatchを決めます。

batch設計で重要なのは、後から説明できることです。

```text
このParquetは、いつ、どの入力から、どの処理で作られたのか
```

この問いに答えられない出力は、分析や監査で使いにくくなります。

## 失敗時の見方

パイプラインが失敗したら、まず失敗箇所を切り分けます。

| 失敗箇所 | 見るもの |
| --- | --- |
| DuckDB CLIがない | `duckdb --version`、`make check-duckdb` |
| サンプル生成に失敗 | `scripts/create_excel_sample.py`、`scripts/create_sqlite_master.py` |
| raw取り込みに失敗 | 入力ファイル、`sql/02_load_raw.sql` |
| 正規化に失敗 | `sql/03_normalize.sql`、型変換、JOIN |
| 品質件数が変わった | `mart.quality_report`、`reports/product_errors.csv` |
| Parquet出力が変わった | `sql/05_export_parquet.sql`、`make test` |
| JSON CLIが失敗 | DB存在、DuckDBロック、exit code |

DuckDBファイルは同時書き込みやロックの影響を受けることがあります。検証を並列に走らせると、ファイルロックで失敗する場合があります。パイプライン確認は、基本的に順番に実行します。

## 運用手順をrunbookとして書く

実務では、Makefileがあるだけでは不十分なことがあります。誰が、いつ、何を見て、失敗時にどう判断するかをrunbookとして書きます。

runbookに書くべきこと:

- 通常実行のコマンド
- 事前条件
- 成功条件
- 生成物の場所
- 失敗時に見るログやレポート
- 再実行してよい条件
- 入力元へ差し戻す条件
- 出力を後続へ渡してよい条件

このチュートリアルなら、最小runbookは次のようになります。

```text
1. product-data-duckdb に移動する
2. make run を実行する
3. make quality で品質件数を見る
4. make test で期待値との差分を見る
5. reports/product_errors.csv を確認する
6. output/products.parquet を後続へ渡すか判断する
```

ここで重要なのは、`make run` の成功だけを完了条件にしないことです。品質チェックとテストを見て、出力を使ってよいか判断します。

## 再実行性と冪等性

データパイプラインでは、再実行できることが重要です。

再実行したい場面:

- SQLを修正した
- 入力ファイルを差し替えた
- マスタを更新した
- 品質チェックを追加した
- 出力を作り直したい

このリポジトリの `make run` は、`CREATE OR REPLACE TABLE` や `COPY ... OVERWRITE_OR_IGNORE` を使い、同じ入力から出力を作り直せる構成にしています。

ただし、実務では単純な上書きが常に正しいとは限りません。

上書きしてよいもの:

- ローカル検証用DB
- 一時レポート
- 開発用Parquet
- 再生成可能なプロファイル結果

上書きに注意するもの:

- 後続システムがすでに読んでいる成果物
- 監査対象の出力
- 過去batchの正式成果物
- 顧客や他部署に共有済みのレポート

再実行性とは、雑に上書きすることではありません。同じ入力から同じ出力を作れること、そして正式成果物をどう扱うかを決めることです。

## テスト期待値を変える時の手順

`tests/test_pipeline.sql` の期待値は、簡単に変えられます。しかし、簡単に変えてよいわけではありません。

期待値を変える前に確認すること:

- 入力サンプルを意図的に変えたか
- 品質チェックの仕様を変えたか
- 正規化ルールを変えたか
- 出力対象条件を変えたか
- バグで件数が変わった可能性はないか

たとえば `invalid_price` が4件から5件になった場合、次のどれかを判断します。

```text
入力データに不正価格を1件追加した
価格変換ルールを厳しくした
以前は不正価格を見逃していた
JOINや重複排除の変更で行数が増えた
```

期待値更新のコミットには、なぜ変わったかを書ける状態にします。データパイプラインのテストは、単に通せばよいものではなく、仕様変更の記録でもあります。

## データ契約の種類

データ契約には複数のレベルがあります。

構造の契約:

- 必須列が存在する
- 型が期待通りである
- Parquetに必要な列が入っている

件数の契約:

- 出力行数が期待値である
- 品質エラー件数が期待値である
- partitioned datasetの行数が一致する

品質の契約:

- 出力にNULL商品名がない
- 出力に不正価格がない
- 出力に未知カテゴリがない

運用の契約:

- batch_idが入っている
- ingest_dateが入っている
- source_fileが残っている

このチュートリアルの `tests/test_pipeline.sql` は、件数、品質、運用メタデータを固定しています。構造テストをさらに増やすなら、`information_schema.columns` を使って列存在や型を確認する方法があります。

## ローカル運用と本番運用の違い

このチュートリアルはローカルで完結します。しかし、実務に持ち込む場合は、本番運用との差を意識します。

ローカルで十分なもの:

- サンプルデータでの学習
- SQLロジックの検証
- 品質チェック設計
- Parquet出力の確認
- Notebookでの観察

本番で追加検討するもの:

- スケジューラ
- 実行ログ
- 監視
- アラート
- 秘密情報管理
- 入力ファイル受領管理
- 出力成果物の世代管理
- 権限管理
- 障害時の再実行手順

このチュートリアルではCIは不要という前提で進めています。ただし、CIを使わないことと、検証しないことは違います。ローカルで `make run`、`make test`、JSON CLIを実行できる状態を保ちます。

## dbt、Dagster、dltをどう位置づけるか

このチュートリアルの標準経路は、DuckDB CLI、SQLファイル、Makefile、SQLテストで完結します。これは、依存を増やさずにデータパイプラインの本質を学ぶためです。

実務では、次のようなツールを組み合わせることがあります。

| ツール | 役割 |
| --- | --- |
| dbt-duckdb | SQL変換をmodelとして管理し、schema testや依存関係を扱う |
| Dagster | パイプラインの依存関係、再実行、観察可能性を管理する |
| dlt | APIやJSONなどの取り込みを定義し、DuckDBなどへロードする |

これらは便利ですが、最初から入れると、DuckDBの責務、SQLの意味、品質チェックの設計が見えにくくなることがあります。

このチュートリアルでは、まずMakefileで実行順を固定します。そのうえで、チーム運用、スケジューリング、依存関係管理、外部API取り込みが必要になった時に、dbt、Dagster、dltを検討します。

判断の目安:

- SQL変換が増え、モデル間依存とテストを管理したいならdbt-duckdb
- ジョブの依存関係、再実行、資産管理を強くしたいならDagster
- APIやJSONの取り込みパターンを共通化したいならdlt
- 小さなローカル教材や単一パイプラインならMakefileで十分

## 運用レビューの観点

運用設計をレビューするときは、次を確認します。

- 実行入口が1つにまとまっているか
- 実行順がコードで固定されているか
- 生成物がGitに入っていないか
- 品質チェックが機械的に読めるか
- テスト期待値の意味を説明できるか
- エラー行を人間が確認できるか
- 再実行時に正式成果物を壊さないか
- batchやingest_dateで出力を追跡できるか
- 失敗時に見る場所が決まっているか

運用レビューは、SQLの正しさとは別の観点です。SQLが正しくても、誰も再実行できない、失敗時に原因を追えない、成果物の世代が分からないなら、実務パイプラインとしては不十分です。

## よくあるつまずき

手順をREADMEにだけ書くと、人によって実行順がずれます。Makefileのターゲットとして固定すると、学習者も運用者も同じ手順を使えます。

生成物をGitに入れると差分が読みにくくなります。再生成可能なものは `.gitignore` に入れ、入力と処理だけを管理します。

品質チェックを目視だけにすると、変化に気づきにくくなります。SQLテストとJSON CLIで、機械的に判断できる形にします。

テスト期待値が変わったとき、すぐに期待値を更新してはいけません。まず、入力変更、仕様変更、バグのどれなのかを確認します。

## このPartに対応する実装ファイル

- `product-data-duckdb/Makefile`: 再現可能な実行入口
- `product-data-duckdb/.gitignore`: 生成物の管理方針
- `product-data-duckdb/tests/test_pipeline.sql`: 品質件数と出力件数のSQLテスト
- `product-data-duckdb/tests/test_local_advanced_sql.sql`: 発展SQLの期待値テスト
- `product-data-duckdb/scripts/run_pipeline.sh`: シェルからの実行入口

## 次のPartに進む条件

- `make run` から `make test` まで再現できる
- 生成物とソースを分けて説明できる
- 品質チェックをデータ契約として説明できる
- SQLテストが何を固定しているか説明できる
- batch、生成物、再実行の設計ポイントを説明できる
- dbt、Dagster、dltを標準経路ではなく発展選択肢にする理由を説明できる

## 公式docsで確認する箇所

- Testing DuckDB: https://duckdb.org/docs/current/dev/sqllogictest/intro.html
- Configuration: https://duckdb.org/docs/current/configuration/overview.html
- Operations Manual: https://duckdb.org/docs/current/operations_manual/overview.html
- dbt-duckdb: https://github.com/duckdb/dbt-duckdb
- Dagster DuckDB: https://release-1-5-9.dagster.dagster-docs.io/integrations/duckdb
- dlt destinations: https://dlthub.com/docs/dlt-ecosystem/destinations
