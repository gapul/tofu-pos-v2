import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/config/env.dart';

void main() {
  group('Env.warnIfMissing', () {
    test('Supabase 認証情報が無い場合（CI 等）に警告ログを1回出す', () {
      // テスト環境では .env も dart-define も無いはず。
      final List<String> messages = <String>[];

      Env.warnIfMissing(messages.add);

      expect(messages, hasLength(1));
      expect(messages.first, contains('Supabase'));
      expect(messages.first, contains('disabled'));
    });
  });

  group('Env.validate', () {
    test('認証情報が無い（=意図的な無効化）は Valid', () {
      // テスト環境では認証情報なし → Valid。
      expect(Env.validate(), isA<EnvValid>());
    });
  });

  group('Env.validateValues', () {
    const String validUrl = 'https://abcdefgh.supabase.co';
    // ダミー JWT（3 セグメントの base64url）。
    const String validJwt =
        'eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzYiJ9.signaturehere_AB-cd';

    test('URL も Key も空 → Valid（無効化と判定）', () {
      expect(
        Env.validateValues(url: '', anonKey: ''),
        isA<EnvValid>(),
      );
    });

    test('正しい URL と JWT → Valid', () {
      expect(
        Env.validateValues(url: validUrl, anonKey: validJwt),
        isA<EnvValid>(),
      );
    });

    test('Publishable Key 形式 → Valid', () {
      expect(
        Env.validateValues(url: validUrl, anonKey: 'sb_publishable_xyz123'),
        isA<EnvValid>(),
      );
    });

    test('URL が http (not https) → Invalid', () {
      final EnvValidation r = Env.validateValues(
        url: 'http://x.supabase.co',
        anonKey: validJwt,
      );
      expect(r, isA<EnvInvalid>());
      expect((r as EnvInvalid).reasons.join(), contains('SUPABASE_URL'));
    });

    test('URL が無関係なドメイン → Invalid', () {
      final EnvValidation r = Env.validateValues(
        url: 'https://example.com',
        anonKey: validJwt,
      );
      expect(r, isA<EnvInvalid>());
    });

    test('Key が壊れている（2 セグメントしか無い） → Invalid', () {
      final EnvValidation r = Env.validateValues(
        url: validUrl,
        anonKey: 'broken.key',
      );
      expect(r, isA<EnvInvalid>());
      expect((r as EnvInvalid).reasons.join(), contains('SUPABASE_ANON_KEY'));
    });

    test('URL は OK だが Key が空 → Invalid', () {
      final EnvValidation r = Env.validateValues(url: validUrl, anonKey: '');
      expect(r, isA<EnvInvalid>());
    });

    test('URL も Key も壊れている → 両方の理由を含む', () {
      final EnvValidation r = Env.validateValues(
        url: 'not a url',
        anonKey: 'no-good',
      );
      expect(r, isA<EnvInvalid>());
      expect((r as EnvInvalid).reasons, hasLength(2));
    });
  });
}
