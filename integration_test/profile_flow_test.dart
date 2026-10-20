import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' show getDatabasesPath, deleteDatabase;
import 'package:strannik/app/bootstrap.dart';
import 'package:strannik/app/profile_playtime.dart';
import 'package:strannik/content/local_content_repository.dart';
import 'package:strannik/core/result.dart';
import 'package:strannik/data/local/database.dart';
import 'package:strannik/data/security/pbkdf2_pin_hasher.dart';
import 'package:strannik/presentation/app/strannik_app.dart';
import 'package:strannik/presentation/home/home_controller.dart';
import 'package:strannik/presentation/profile/profile_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android profile, parent access, rewards and recovery', (
    tester,
  ) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final filename = path.join(
      await getDatabasesPath(),
      'profile_qa_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final db = await LocalDatabase.open(filename);
    final catalog = LocalContentRepository.fromJson(
      await rootBundle.loadString('lib/content/seed/development.json'),
    );
    final game = GameServices(
      unitOfWork: db,
      content: catalog,
      pinHasher: Pbkdf2PinHasher(iterations: 1000),
    );
    void ok(Result<void> result) => expect(result, isA<Success<void>>());
    ok(
      await game.onboarding.saveDraft(
        nickname: 'Карина',
        avatarId: 'girl',
        petName: 'Веня',
        alienName: 'Зор',
        skinId: 'gray',
      ),
    );
    ok(await game.parentAccess.setPin('1234'));
    ok(await game.onboarding.complete());
    final home = HomeController(
      unitOfWork: db,
      allowDevelopmentPreview: false,
      content: catalog,
      interactions: game.pet,
    );
    final profile = ProfileController(
      game,
      createFeedbackServices(db, platformOutputs: true),
      PlaytimeService(db.database),
    );
    await profile.load();
    await home.load();
    await tester.pumpWidget(StrannikApp(controller: home, profile: profile));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    Future<void> tap(String text) async {
      final target = find.text(text);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.bySemanticsLabel('Профиль ребёнка'));
    await tester.pumpAndSettle();
    expect(find.text('Профиль'), findsOneWidget);
    await capture('child-profile');
    await tester.tap(find.bySemanticsLabel('Изменить аватарку'));
    await tester.pumpAndSettle();
    await capture('avatar-picker');
    await tester.drag(find.byType(PageView), const Offset(165, 0));
    await tester.pumpAndSettle();
    await tap('Сохранить');
    expect(profile.overview!.profile!.avatarId, 'boy');
    await tester.tap(find.byTooltip('Изменить имя'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Карина');
    await tester.pump();
    await capture('name-keyboard');
    await tap('Сохранить');
    await tap('Войти как родитель');
    await tester.enterText(find.byKey(const ValueKey('pin-input')), '0000');
    await tap('Отправить');
    expect(find.text('Неверный код! Попробуйте снова'), findsOneWidget);
    await capture('pin-error');
    await tester.enterText(find.byKey(const ValueKey('pin-input')), '1234');
    await tap('Отправить');
    expect(find.text('Мамам и папам'), findsOneWidget);
    await capture('parent-dashboard');
    await tap('Прогресс ›');
    await capture('learning-progress');
    await tap(catalog.themes.first.title);
    await capture('topic-detail');
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    await tap('Отправить игровую валюту');
    await tap('100');
    await capture('reward');
    await tap('Отправить 100 ₣');
    expect(find.text('Подарок отправлен!'), findsOneWidget);
    await capture('reward-success');
    final wallet = await db.run((r) => r.economy.wallet());
    expect((wallet as Success).value.firaAmount, 200);
    await tap('Назад к темам');
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    await tap('Удалить аккаунт');
    await capture('delete-confirmation');
    await tap('Отмена');
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(profile.parent, false);
    await tap('Войти как родитель');
    for (var i = 0; i < 3; i++) {
      await tester.enterText(find.byKey(const ValueKey('pin-input')), '0000');
      await tap('Отправить');
    }
    await capture('adult-verification');
    await tap('Повышение курса валют');
    await tap('Выбрать');
    expect(find.text('Не получилось войти'), findsOneWidget);
    expect(profile.parent, false);
    await capture('support-recovery');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    profile.dispose();
    home.dispose();
    await db.close();
    await deleteDatabase(filename);
  });
}
