import '../../core/result.dart';
import '../models/models.dart';
import 'parent_access_service.dart';

class DemoService {
  DemoService(this.parentAccess);
  final ParentAccessService parentAccess;
  Future<Result<void>> setEnabled(String pin, bool enabled) =>
      parentAccess.perform(pin, (r) async {
        await r.system.saveAppState(AppState(demoMode: enabled));
      });
  Future<Result<void>> changeDemoStage(String pin, Stage stage) =>
      parentAccess.perform(pin, (r) async {
        require((await r.system.appState()).demoMode, Failure.locked);
        await r.system.saveAppState(AppState(demoMode: true, demoStage: stage));
      });
}
