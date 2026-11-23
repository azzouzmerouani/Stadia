import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stadia/app/routes.dart';
import 'package:stadia/data/favourite_team.dart';
import 'package:stadia/data/providers.dart';
import 'package:stadia/data/repositories/local_stadium_repository.dart';
import 'package:stadia/features/splash/splash_tasks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Plain tests: the splash also starts the real loopback asset server.
  Future<(SplashTasks, ProviderContainer)> run(String? saved) async {
    final container = ProviderContainer(
      overrides: [
        stadiumRepositoryProvider.overrideWithValue(
          LocalStadiumRepository(latency: Duration.zero),
        ),
        favouriteTeamStoreProvider.overrideWithValue(
          MemoryFavouriteTeamStore(saved),
        ),
      ],
    );
    addTearDown(container.dispose);
    final tasks = container.read(splashTasksProvider);
    await tasks.run();
    return (tasks, container);
  }

  test('first launch asks for a team', () async {
    final (tasks, container) = await run(null);
    expect(tasks.nextRoute, Routes.team);
    expect(container.read(favouriteTeamProvider), isNull);
    expect(container.read(currentStadiumIdProvider), 'miloud-hadefi');
  });

  test('a saved team goes straight to its stadium', () async {
    final (tasks, container) = await run('CSC');
    expect(tasks.nextRoute, Routes.intro);
    expect(container.read(favouriteTeamProvider), 'CSC');
    expect(container.read(currentStadiumIdProvider), '8-mai-1945');
  });

  test('a club that no longer exists asks again', () async {
    final (tasks, _) = await run('XYZ');
    expect(tasks.nextRoute, Routes.team);
  });
}
