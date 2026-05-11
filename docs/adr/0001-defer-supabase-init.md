# 0001. Supabase 初期化を第1フレーム後に遅延する

- Status: Accepted
- Date: 2026-05-08（JST）
- Deciders: gapul

## Context

`Supabase.initialize()` を `runApp` 前で同期的に await すると、ネットワーク状況や DNS 解決の遅延次第で iOS のアプリ起動 watchdog（約 20 秒）に当たって SIGKILL される事象を再現確認した。学祭という現場では起動の決定論性が最優先で、ネット不調時に「アプリが立ち上がらない」状態は許容できない。

また `flutter_dotenv` の読み込み・SharedPreferences の初期化は速いが、Supabase は内部で複数 isolate を立ち上げるため、起動経路を太らせる主因になっていた。

## Decision

Supabase 初期化を `runApp` 前から **第1フレーム描画後の `addPostFrameCallback`** に移し、`StartupPipeline` の `supabase.init` ステップとして直列実行する。失敗してもアプリは起動済みで、`hasSupabaseCredentials` ガードによりクラウド機能だけが Noop に落ちる。

## Consequences

- 利点: 起動が即時。ネット不調や認証情報不正で「白画面のまま固まる」状態を解消。
- 利点: 各起動ステップが `Telemetry.instance.error(fatal=false)` で観測される。
- 失うもの: 起動直後の極短時間、`Supabase.instance` が未初期化。これは `telemetrySinkProvider` 等のレイジー初期化で吸収済み。
- 要観察: 認証エラーの可視化が「起動失敗」から「ダッシュボードのテレメトリ欠損」に移ったため、運用ダッシュボード側で `app.start` 欠損のアラートを設定すること。

## References

- ADR-0004: 起動シーケンスの構造化
- `lib/app.dart` の `_StartupInitializer`
- `lib/core/config/supabase_bootstrap.dart`
