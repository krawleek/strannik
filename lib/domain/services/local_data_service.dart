import '../../core/result.dart';
import 'parent_access_service.dart';

class LocalDataService {
  LocalDataService(this.parentAccess);
  final ParentAccessService parentAccess;
  Future<Result<void>> resetProgress(String pin) =>
      parentAccess.perform(pin, (r) => r.system.resetProgress());
  Future<Result<void>> deleteAllData(String pin) =>
      parentAccess.perform(pin, (r) => r.system.deleteAllData());
  Future<Result<void>> resetDemoProgress(String pin) =>
      parentAccess.perform(pin, (r) async {
        require((await r.system.appState()).demoMode, Failure.locked);
        await r.system.resetProgress();
      });
}
