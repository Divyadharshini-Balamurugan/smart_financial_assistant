import 'user_financial_analyzer.dart';
import 'tip_decision_engine.dart';
import 'tip_repository.dart';

class TipsTriggerService {
  final _analyzer = UserFinancialAnalyzer();
  final _engine = TipDecisionEngine();
  final _repo = TipRepository();

  Future<void> onExpenseLogged(String uid) async {
    final analysis = await _analyzer.analyze(uid);

    final usedVariants = <String>[]; // fetch from tipHistory if needed

    final tips = _engine.decide(analysis, usedVariants);

    await _repo.saveTips(uid, tips);
  }
}
  