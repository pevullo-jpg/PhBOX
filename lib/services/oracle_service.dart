import 'dart:math';

import 'package:family_boxes_2/engine/budget_engine.dart';
import 'package:family_boxes_2/models/transaction.dart';

class OracleReading {
  final String verdict;
  final String observation;
  final String prophecy;
  final String title;

  const OracleReading({
    required this.verdict,
    required this.observation,
    required this.prophecy,
    required this.title,
  });
}

enum _OracleLevel {
  gravelyInsufficient,
  insufficient,
  sufficient,
  good,
  exceptional,
}

enum _OracleSeason {
  winter,
  spring,
  summer,
  autumn,
}

class OracleService {
  static final Random _random = Random();

  static OracleReading generate(BudgetEngine engine) {
    final now = DateTime.now();
    final monthTransactions = engine.transactions.where(
      (t) => t.date.year == now.year && t.date.month == now.month,
    ).toList();

    final savingsBoxId = _findBoxId(engine, 'risparmi');
    final subscriptionsBoxId = _findBoxId(engine, 'abbonamenti');

    final savingsRecurringIds = engine.recurring
        .where((r) => _normalizeLabel(engine.groupName(r.groupId)) == 'risparmi')
        .map((r) => r.id)
        .toSet();

    final externalMonthTransactions = monthTransactions
        .where(_isPlannedExternalTransaction)
        .toList();

    final plannedIncomeTransactions = engine.transactions.where(
      (t) =>
          t.amount > 0 &&
          _isPlannedExternalTransaction(t) &&
          _isInIncomePlanningWindow(t.date, now),
    );

    final plannedIncome = plannedIncomeTransactions.fold<double>(
      0.0,
      (sum, t) => sum + t.amount,
    );

    final savingsBoxContribution = savingsBoxId == null
        ? 0.0
        : monthTransactions
              .where((t) => _isSavingsBoxContribution(t, savingsBoxId))
              .fold<double>(0.0, (sum, t) => sum + t.amount);

    final savingsRecurringAmount = monthTransactions
        .where((t) => _isSavingsRecurringContribution(t, savingsRecurringIds))
        .fold<double>(0.0, (sum, t) => sum + t.amount.abs());

    final savingsEffort = savingsBoxContribution + savingsRecurringAmount;
    final savingsRate = plannedIncome > 0.01 ? savingsEffort / plannedIncome : null;

    final subscriptionsNow = subscriptionsBoxId == null
        ? 0.0
        : engine.boxCurrentBalance(subscriptionsBoxId);
    final subscriptionsEnd = subscriptionsBoxId == null
        ? 0.0
        : engine.boxEndMonthBalance(subscriptionsBoxId);
    final subscriptionsMonthNet = subscriptionsBoxId == null
        ? 0.0
        : externalMonthTransactions
              .where((t) => _isSubscriptionExternalTransaction(t, subscriptionsBoxId))
              .fold<double>(0.0, (sum, t) => sum + t.amount);

    final nonSavingsNonSubscriptionsExpense = externalMonthTransactions
        .where(
          (t) =>
              t.amount < 0 &&
              !_isSavingsRecurringContribution(t, savingsRecurringIds) &&
              !_isSubscriptionExternalTransaction(t, subscriptionsBoxId),
        )
        .fold<double>(0.0, (sum, t) => sum + t.amount.abs());

    final planningBreath = plannedIncome - nonSavingsNonSubscriptionsExpense;

    final season = _seasonForDate(now);

    final savingsLevel = _savingsLevel(savingsRate);
    final subscriptionsLevel = _subscriptionsLevel(
      subscriptionsBoxId: subscriptionsBoxId,
      subscriptionsNow: subscriptionsNow,
      subscriptionsEnd: subscriptionsEnd,
      subscriptionsMonthNet: subscriptionsMonthNet,
    );
    final balanceLevel = _balanceLevel(
      plannedIncome: plannedIncome,
      planningBreath: planningBreath,
    );
    final overallLevel = _overallLevel(
      savingsLevel: savingsLevel,
      subscriptionsLevel: subscriptionsLevel,
      balanceLevel: balanceLevel,
    );

    return OracleReading(
      verdict: _buildVerdict(
        overallLevel: overallLevel,
        savingsLevel: savingsLevel,
        subscriptionsLevel: subscriptionsLevel,
        balanceLevel: balanceLevel,
        season: season,
      ),
      observation: _buildObservation(
        overallLevel: overallLevel,
        savingsLevel: savingsLevel,
        subscriptionsLevel: subscriptionsLevel,
        balanceLevel: balanceLevel,
        season: season,
      ),
      prophecy: _buildProphecy(
        overallLevel: overallLevel,
        savingsLevel: savingsLevel,
        subscriptionsLevel: subscriptionsLevel,
        balanceLevel: balanceLevel,
        season: season,
      ),
      title: _pick(_titlesForLevel(overallLevel, season)),
    );
  }

  static String? _findBoxId(BudgetEngine engine, String label) {
    final normalized = _normalizeLabel(label);
    for (final box in engine.boxes) {
      if (_normalizeLabel(box.name) == normalized) {
        return box.id;
      }
    }
    return null;
  }

  static bool _isSavingsRecurringContribution(
    TransactionModel tx,
    Set<String> savingsRecurringIds,
  ) {
    return tx.amount < 0 &&
        tx.recurringId != null &&
        savingsRecurringIds.contains(tx.recurringId) &&
        !_isTechnicalAdjustment(tx) &&
        !_isInternalFlowTransaction(tx);
  }

  static bool _isSavingsBoxContribution(
    TransactionModel tx,
    String savingsBoxId,
  ) {
    final hasFund = tx.fundId != null && tx.fundId!.trim().isNotEmpty;
    return tx.boxId == savingsBoxId &&
        tx.amount > 0 &&
        !hasFund &&
        !_isTechnicalAdjustment(tx);
  }

  static bool _isInIncomePlanningWindow(DateTime txDate, DateTime reference) {
    final monthStart = DateTime(reference.year, reference.month, 1);
    final planningWindowStart = monthStart.subtract(const Duration(days: 3));
    final nextMonthStart = DateTime(reference.year, reference.month + 1, 1);
    return !txDate.isBefore(planningWindowStart) && txDate.isBefore(nextMonthStart);
  }

  static bool _isSubscriptionExternalTransaction(
    TransactionModel tx,
    String? subscriptionsBoxId,
  ) {
    return subscriptionsBoxId != null &&
        tx.boxId == subscriptionsBoxId &&
        _isPlannedExternalTransaction(tx);
  }

  static bool _isPlannedExternalTransaction(TransactionModel tx) {
    if (_isTechnicalAdjustment(tx) || _isInternalFlowTransaction(tx)) {
      return false;
    }

    final hasBox = tx.boxId != null && tx.boxId!.trim().isNotEmpty;
    final hasFund = tx.fundId != null && tx.fundId!.trim().isNotEmpty;

    if (hasBox && !hasFund) {
      return false;
    }

    return true;
  }

  static bool _isInternalFlowTransaction(TransactionModel tx) {
    final category = _normalizeLabel(tx.category);
    final note = _normalizeLabel(tx.note);
    return category.contains('flusso ricorrente') ||
        category.contains('flusso singolo') ||
        note.contains('flusso ricorrente') ||
        note.contains('flusso singolo');
  }

  static bool _isTechnicalAdjustment(TransactionModel tx) {
    final category = _normalizeLabel(tx.category);
    final note = _normalizeLabel(tx.note);
    return category.contains('allineamento') || note.contains('allineamento');
  }

  static _OracleSeason _seasonForDate(DateTime date) {
    switch (date.month) {
      case 12:
      case 1:
      case 2:
        return _OracleSeason.winter;
      case 3:
      case 4:
      case 5:
        return _OracleSeason.spring;
      case 6:
      case 7:
      case 8:
        return _OracleSeason.summer;
      default:
        return _OracleSeason.autumn;
    }
  }

  static _OracleLevel _savingsLevel(double? savingsRate) {
    if (savingsRate == null || savingsRate <= 0.0) {
      return _OracleLevel.gravelyInsufficient;
    }
    if (savingsRate < 0.10) {
      return _OracleLevel.insufficient;
    }
    if (savingsRate < 0.15) {
      return _OracleLevel.sufficient;
    }
    if (savingsRate < 0.20) {
      return _OracleLevel.good;
    }
    return _OracleLevel.exceptional;
  }

  static _OracleLevel _subscriptionsLevel({
    required String? subscriptionsBoxId,
    required double subscriptionsNow,
    required double subscriptionsEnd,
    required double subscriptionsMonthNet,
  }) {
    if (subscriptionsBoxId == null) {
      return _OracleLevel.sufficient;
    }
    if (subscriptionsNow < -0.01 && subscriptionsEnd < -0.01) {
      return _OracleLevel.gravelyInsufficient;
    }
    if (subscriptionsEnd < -0.01 || subscriptionsNow < -0.01) {
      return _OracleLevel.insufficient;
    }
    if (subscriptionsEnd <= 0.01) {
      return _OracleLevel.sufficient;
    }
    if (subscriptionsMonthNet < -0.01) {
      return _OracleLevel.sufficient;
    }
    if (subscriptionsMonthNet <= 0.01) {
      return _OracleLevel.good;
    }
    return _OracleLevel.exceptional;
  }

  static _OracleLevel _balanceLevel({
    required double plannedIncome,
    required double planningBreath,
  }) {
    if (plannedIncome <= 0.01) {
      return _OracleLevel.gravelyInsufficient;
    }
    final ratio = planningBreath / plannedIncome;
    if (ratio <= -0.05) {
      return _OracleLevel.gravelyInsufficient;
    }
    if (ratio < 0.0) {
      return _OracleLevel.insufficient;
    }
    if (ratio <= 0.10) {
      return _OracleLevel.sufficient;
    }
    if (ratio <= 0.25) {
      return _OracleLevel.good;
    }
    return _OracleLevel.exceptional;
  }

  static _OracleLevel _overallLevel({
    required _OracleLevel savingsLevel,
    required _OracleLevel subscriptionsLevel,
    required _OracleLevel balanceLevel,
  }) {
    final weighted = (savingsLevel.index * 0.80) +
        (subscriptionsLevel.index * 0.15) +
        (balanceLevel.index * 0.05);

    _OracleLevel mapped;
    if (weighted < 0.50) {
      mapped = _OracleLevel.gravelyInsufficient;
    } else if (weighted < 1.50) {
      mapped = _OracleLevel.insufficient;
    } else if (weighted < 2.50) {
      mapped = _OracleLevel.sufficient;
    } else if (weighted < 3.50) {
      mapped = _OracleLevel.good;
    } else {
      mapped = _OracleLevel.exceptional;
    }

    return mapped.index <= savingsLevel.index ? mapped : savingsLevel;
  }

  static String _buildVerdict({
    required _OracleLevel overallLevel,
    required _OracleLevel savingsLevel,
    required _OracleLevel subscriptionsLevel,
    required _OracleLevel balanceLevel,
    required _OracleSeason season,
  }) {
    return _pick(_conciseVerdictsForLevel(overallLevel, season));
  }

  static String _buildObservation({
    required _OracleLevel overallLevel,
    required _OracleLevel savingsLevel,
    required _OracleLevel subscriptionsLevel,
    required _OracleLevel balanceLevel,
    required _OracleSeason season,
  }) {
    final opening = _pick(_conciseOpeningsForLevel(overallLevel, season));
    final focus = <String>[_pick(_conciseSavingsFocusForLevel(savingsLevel))];

    if (subscriptionsLevel != _OracleLevel.sufficient) {
      focus.add(_pick(_conciseSubscriptionsFocusForLevel(subscriptionsLevel)));
    }
    if (balanceLevel != _OracleLevel.sufficient) {
      focus.add(_pick(_conciseBalanceFocusForLevel(balanceLevel)));
    }

    return _joinOracleLines([opening, _pick(focus)]);
  }

  static String _buildProphecy({
    required _OracleLevel overallLevel,
    required _OracleLevel savingsLevel,
    required _OracleLevel subscriptionsLevel,
    required _OracleLevel balanceLevel,
    required _OracleSeason season,
  }) {
    final pool = <String>[..._concisePropheciesForLevel(overallLevel, season)];

    if (savingsLevel.index < _OracleLevel.sufficient.index) {
      pool.addAll(const [
        'Più stretta la mano fare devi.',
        'Alla quiete, più raccolto condurre ti toccherà.',
      ]);
    } else if (savingsLevel.index >= _OracleLevel.good.index) {
      pool.addAll(const [
        'Buona la via: saldo restare devi.',
        'Custodito il passo se resterà, più docile il domani sarà.',
      ]);
    }

    if (subscriptionsLevel.index < _OracleLevel.sufficient.index) {
      pool.add('Nei legami che tornano, una crepa ancora veglia.');
    }
    if (balanceLevel.index < _OracleLevel.sufficient.index) {
      pool.add('Corto il respiro del ciclo, ancora rimane.');
    }

    return _pick(pool);
  }

  static List<String> _conciseVerdictsForLevel(
    _OracleLevel level,
    _OracleSeason season,
  ) {
    return [
      ..._baseConciseVerdictsForLevel(level),
      ..._seasonalConciseVerdictsForLevel(level, season),
    ];
  }

  static List<String> _baseConciseVerdictsForLevel(_OracleLevel level) {
    switch (level) {
      case _OracleLevel.gravelyInsufficient:
        return const [
          'Grave la ferita del ciclo è.',
          'Oscura la misura del mese appare.',
          'Molto del raccolto smarrito è.',
          'Scosso e povero il sigillo del ciclo si mostra.',
          'Dispersa la mano del custodire è.',
        ];
      case _OracleLevel.insufficient:
        return const [
          'Incerta la presa sul ciclo è.',
          'Fragile la rotta del mese resta.',
          'Poco saldo il passo del raccolto è.',
          'Appena contenuta la corrente appare.',
          'Alla soglia, ma senza piena forza, ancora sei.',
        ];
      case _OracleLevel.sufficient:
        return const [
          'Sufficiente la disciplina del ciclo è.',
          'Saldo abbastanza il sentiero appare.',
          'Alla prova del mese, non cadi.',
          'Sorretto il raccolto cammina.',
          'Base vera sotto il ciclo ora dimora.',
        ];
      case _OracleLevel.good:
        return const [
          'Buona la padronanza del flusso è.',
          'Ordinato e saldo il ciclo si mostra.',
          'Con mano ferma il mese guidato hai.',
          'Matura la disciplina del raccolto appare.',
          'Ben piegata alla misura la corrente è.',
        ];
      case _OracleLevel.exceptional:
        return const [
          'Eccezionale il dominio sul flusso è.',
          'Maestosa la tenuta del ciclo appare.',
          'Con sapienza rara il raccolto governi.',
          'Quieta e potente la disciplina si leva.',
          'Sovrana la tua misura si mostra.',
        ];
    }
  }

  static List<String> _seasonalConciseVerdictsForLevel(
    _OracleLevel level,
    _OracleSeason season,
  ) {
    switch (season) {
      case _OracleSeason.winter:
        switch (level) {
          case _OracleLevel.gravelyInsufficient:
            return const [
              'Nel gelo del ciclo, nuda la riserva resta.',
              'Inverno duro il raccolto attraversa.',
            ];
          case _OracleLevel.insufficient:
            return const [
              'Nel freddo del mese, corta la coperta appare.',
              'Rigido il ciclo è, e piena difesa ancora non hai.',
            ];
          case _OracleLevel.sufficient:
            return const [
              'Nel gelo, regge il focolare del ciclo.',
              'Freddo il vento è, ma il mese in piedi resta.',
            ];
          case _OracleLevel.good:
            return const [
              'Nel gelo del ciclo, saldo il fuoco tieni.',
              "L'inverno piega molti; tu la misura tieni.",
            ];
          case _OracleLevel.exceptional:
            return const [
              'Nel pieno del gelo, regale la brace custodisci.',
              'Inverno viene, ma sovrano sul focolare resti.',
            ];
        }
      case _OracleSeason.spring:
        switch (level) {
          case _OracleLevel.gravelyInsufficient:
            return const [
              'Dove germoglio doveva levarsi, terra spoglia vedo.',
              'Primavera chiama, ma il seme ancora risponde non.',
            ];
          case _OracleLevel.insufficient:
            return const [
              'Pochi germogli il ciclo mostra.',
              'Muoversi tenta il seme, ma forza piena ancora non ha.',
            ];
          case _OracleLevel.sufficient:
            return const [
              'Primo germoglio nel ciclo vedo.',
              'La stagione si apre, e il seme regge.',
            ];
          case _OracleLevel.good:
            return const [
              'Buona fioritura il ciclo prepara.',
              'Con mano giusta il germoglio del mese custodisci.',
            ];
          case _OracleLevel.exceptional:
            return const [
              'Rigogliosa la fioritura del raccolto appare.',
              'Primavera piena sotto il tuo sigillo si apre.',
            ];
        }
      case _OracleSeason.summer:
        switch (level) {
          case _OracleLevel.gravelyInsufficient:
            return const [
              'Sotto sole duro, troppo evapora il raccolto.',
              'Estate larga si apre, ma il flusso si disperde.',
            ];
          case _OracleLevel.insufficient:
            return const [
              'Calda la stagione è, e troppo sfugge ancora.',
              'Sotto il sole del ciclo, piena ombra alla riserva non dai.',
            ];
          case _OracleLevel.sufficient:
            return const [
              'Al sole del mese, misura abbastanza mantieni.',
              'Estate larga è, ma il raccolto regge.',
            ];
          case _OracleLevel.good:
            return const [
              'Sotto sole alto, bene la corrente governi.',
              'Nella stagione larga, saldo il raccolto custodisci.',
            ];
          case _OracleLevel.exceptional:
            return const [
              'Nel pieno della luce, sovrana la misura appare.',
              'Estate piena, e nulla disperdi quasi.',
            ];
        }
      case _OracleSeason.autumn:
        switch (level) {
          case _OracleLevel.gravelyInsufficient:
            return const [
              "Povero il raccolto d'autunno appare.",
              'Tempo di mietere è, ma vuote le mani tornano.',
            ];
          case _OracleLevel.insufficient:
            return const [
              'Scarso il raccolto che alla soglia porti è.',
              'Tra foglie che cadono, poco il mese trattiene.',
            ];
          case _OracleLevel.sufficient:
            return const [
              "Dignitoso il raccolto d'autunno resta.",
              'Alla soglia del granaio, quanto basta porti.',
            ];
          case _OracleLevel.good:
            return const [
              'Buona la mietitura che al granaio conduci è.',
              'Tempo di raccolto, e buona misura tra le mani hai.',
            ];
          case _OracleLevel.exceptional:
            return const [
              "Pieno il granaio d'autunno si mostra.",
              'Ricco e composto il raccolto alla soglia conduci.',
            ];
        }
    }
  }

  static List<String> _conciseOpeningsForLevel(
    _OracleLevel level,
    _OracleSeason season,
  ) {
    return [
      ..._baseConciseOpeningsForLevel(level),
      ..._seasonalConciseOpeningsForLevel(level, season),
    ];
  }

  static List<String> _baseConciseOpeningsForLevel(_OracleLevel level) {
    switch (level) {
      case _OracleLevel.gravelyInsufficient:
        return const [
          'Torbido il velo del mese si apre.',
          'Scossa la trama del ciclo appare.',
          'Pesante l’ombra sul raccolto cade.',
          'Ferito il bordo del mese vedo.',
          'Aspra la corrente davanti giunge.',
        ];
      case _OracleLevel.insufficient:
        return const [
          'Incerta la luce sul ciclo cade.',
          'Sul bordo della misura il passo indugia.',
          'Mista a crepe la forma del mese è.',
          'Non pulita ancora la trama appare.',
          'Tra ordine e deriva il mese resta.',
        ];
      case _OracleLevel.sufficient:
        return const [
          'Più ordine che caos, nel velo leggo.',
          'Alla soglia buona il ciclo si posa.',
          'Sorretto il mese, davanti a me appare.',
          'Né rovina né trionfo il quadro reca.',
          'Tenuta presente nel ciclo vedo.',
        ];
      case _OracleLevel.good:
        return const [
          'Con nitidezza favorevole il velo si apre.',
          'Buona armonia nella trama risuona.',
          'Obbediente alla misura il ciclo si piega.',
          'Fermata bene la corrente appare.',
          'Ordine vivo nel raccolto sento.',
        ];
      case _OracleLevel.exceptional:
        return const [
          'Luminoso il disegno del ciclo si mostra.',
          'Quasi regale la quiete del raccolto appare.',
          'Piena la trama del mese risplende.',
          'Nobile la disciplina che il velo rivela è.',
          'Sotto saldo sigillo il ciclo quasi canta.',
        ];
    }
  }

  static List<String> _seasonalConciseOpeningsForLevel(
    _OracleLevel level,
    _OracleSeason season,
  ) {
    switch (season) {
      case _OracleSeason.winter:
        return const [
          'Nel vetro del gelo il velo si apre.',
          'Sul campo freddo del mese il responso cade.',
        ];
      case _OracleSeason.spring:
        return const [
          'Tra semi e vento leggero il velo si apre.',
          'Nel primo verde del ciclo il responso si leva.',
        ];
      case _OracleSeason.summer:
        return const [
          'Sotto luce alta il velo del mese si apre.',
          'Nel caldo del ciclo il responso risuona.',
        ];
      case _OracleSeason.autumn:
        return const [
          'Tra foglie e grano il velo si apre.',
          'Nel tempo del raccolto il responso cade.',
        ];
    }
  }

  static List<String> _conciseSavingsFocusForLevel(_OracleLevel level) {
    switch (level) {
      case _OracleLevel.gravelyInsufficient:
        return const [
          'Alla riserva, quasi nulla approda.',
          'Tutto scivola: poco al riparo cade.',
          'Debole troppo la mano del custodire è.',
          'Alla quiete, il raccolto non obbedisce.',
        ];
      case _OracleLevel.insufficient:
        return const [
          'Qualcosa trattieni, ma troppo ancora fugge.',
          'Timida la stretta sul raccolto resta.',
          'Un poco salvi, ma poco ancora è.',
          'La riserva riceve, ma piano troppo.',
        ];
      case _OracleLevel.sufficient:
        return const [
          'Alla riserva, parte giusta del flusso giunge.',
          'Vera, seppur sobria, la mano del custodire è.',
          'La soglia buona del trattenere raggiunta è.',
          'Non tutto disperdi: questo il segno è.',
        ];
      case _OracleLevel.good:
        return const [
          'Buona la mano del custodire è.',
          'Alla quiete, quota forte del raccolto conduci.',
          'Più del minimo salvi, e il segno si vede.',
          'Con decisione la riserva nutri.',
        ];
      case _OracleLevel.exceptional:
        return const [
          'Ampia la parte che alla riserva obbedisce è.',
          'Raro il livello del custodire che vedo.',
          'Non briciole, ma parte nobile al riparo cade.',
          'Con forza alta il raccolto sottrai al consumo.',
        ];
    }
  }

  static List<String> _conciseSubscriptionsFocusForLevel(_OracleLevel level) {
    switch (level) {
      case _OracleLevel.gravelyInsufficient:
        return const [
          'I patti che tornano, troppo mordono.',
          'Peso netto dai legami ricorrenti giunge.',
          'Ciò che dovrebbe reggersi, il ciclo consuma.',
        ];
      case _OracleLevel.insufficient:
        return const [
          'Vacilla la tenuta dei patti che tornano.',
          'Da sé reggersi, ancora non sanno.',
          'Una fessura nei legami ricorrenti rimane.',
        ];
      case _OracleLevel.sufficient:
        return const [
          'Sul ciglio, ma in piedi, i patti restano.',
          'Tenuta minima nei legami che tornano vedo.',
          'Appena saldo il loro cerchio appare.',
        ];
      case _OracleLevel.good:
        return const [
          'Da sé reggersi sanno i legami che tornano.',
          'Più quiete che attrito nei patti dimora.',
          'Peso sul ciclo, i ritorni non sono.',
        ];
      case _OracleLevel.exceptional:
        return const [
          'Dai ritorni del mese, sostegno ricevi.',
          'Non solo reggono: qualcosa rendono.',
          'Fertile il cerchio dei patti ricorrenti appare.',
        ];
    }
  }

  static List<String> _conciseBalanceFocusForLevel(_OracleLevel level) {
    switch (level) {
      case _OracleLevel.gravelyInsufficient:
        return const [
          'Corto e ferito il respiro del mese è.',
          'Più attrito che spazio il ciclo reca.',
          'Quasi nessuna aria nel varco rimane.',
        ];
      case _OracleLevel.insufficient:
        return const [
          'Teso il respiro del mese si mostra.',
          'Stretto il margine che resta è.',
          'Contratto il ciclo, davanti procede.',
        ];
      case _OracleLevel.sufficient:
        return const [
          'Regge il mese, ma largo non è.',
          'Tenuta sì, ampiezza no.',
          'Senza crollo procede il ciclo.',
        ];
      case _OracleLevel.good:
        return const [
          'Buono il respiro del ciclo è.',
          'Margine vero il mese ancora conserva.',
          'Con una certa ampiezza il ciclo procede.',
        ];
      case _OracleLevel.exceptional:
        return const [
          'Ampio il respiro del mese diventa.',
          'Grande spazio tra vincolo e scelta vedo.',
          'Più spinta che peso il ciclo reca.',
        ];
    }
  }

  static List<String> _concisePropheciesForLevel(
    _OracleLevel level,
    _OracleSeason season,
  ) {
    return [
      ..._baseConcisePropheciesForLevel(level),
      ..._seasonalConcisePropheciesForLevel(level, season),
    ];
  }

  static List<String> _baseConcisePropheciesForLevel(_OracleLevel level) {
    switch (level) {
      case _OracleLevel.gravelyInsufficient:
        return const [
          'Duro il prossimo ciclo verrà, se nulla muti.',
          'Più severo il domani si farà.',
          'Senza correzione, pace non vedo.',
          'Così lasciato il varco, torbida la corrente verrà.',
        ];
      case _OracleLevel.insufficient:
        return const [
          'Un varco c’è ancora, ma ferma la mano dovrà farsi.',
          'Alla soglia stai: scelta più netta servirà.',
          'Poco basta per salire, poco per cadere.',
          'Risposta alla tua disciplina il ciclo chiederà.',
        ];
      case _OracleLevel.sufficient:
        return const [
          'Buona la base è: più forza ancora può venire.',
          'Tenuta c’è, ma più ambizione il domani chiede.',
          'Regge la rotta: alzarla ancora puoi.',
          'Con poco rigore in più, migliore il sigillo cadrà.',
        ];
      case _OracleLevel.good:
        return const [
          'Buona la rotta: costanza serbare devi.',
          'Saldo il ciclo è; così restare ti conviene.',
          'Vicino alla pienezza il passo già cammina.',
          'Più docile il futuro, se fermo resterai, sarà.',
        ];
      case _OracleLevel.exceptional:
        return const [
          'Obbediente il prossimo ciclo verrà.',
          'Raro il sentiero che apri è: saldo serbalo.',
          'Molto ancora il domani concedere potrà.',
          'Scelta sovrana, il ciclo che viene promette.',
        ];
    }
  }

  static List<String> _seasonalConcisePropheciesForLevel(
    _OracleLevel level,
    _OracleSeason season,
  ) {
    switch (season) {
      case _OracleSeason.winter:
        switch (level) {
          case _OracleLevel.gravelyInsufficient:
          case _OracleLevel.insufficient:
            return const [
              'Nel gelo che viene, più chiusa la mano dovrà farsi.',
              'Freddo il prossimo passo sarà, se brace nuova non custodirai.',
            ];
          case _OracleLevel.sufficient:
          case _OracleLevel.good:
          case _OracleLevel.exceptional:
            return const [
              'Nel gelo che resta, il focolare non lasciare.',
              "D'inverno, costanza più di slancio ti servirà.",
            ];
        }
      case _OracleSeason.spring:
        switch (level) {
          case _OracleLevel.gravelyInsufficient:
          case _OracleLevel.insufficient:
            return const [
              'Se al seme disciplina non darai, debole il germoglio resterà.',
              'Alla stagione nuova, mano più attenta dovrai portare.',
            ];
          case _OracleLevel.sufficient:
          case _OracleLevel.good:
          case _OracleLevel.exceptional:
            return const [
              'Buon seme nel ciclo hai: con cura, fioritura verrà.',
              'Nel verde che cresce, misura e pazienza serbare devi.',
            ];
        }
      case _OracleSeason.summer:
        switch (level) {
          case _OracleLevel.gravelyInsufficient:
          case _OracleLevel.insufficient:
            return const [
              'Sotto sole forte, ombra migliore alla riserva dare dovrai.',
              'Nella stagione larga, più del solito trattenere servirà.',
            ];
          case _OracleLevel.sufficient:
          case _OracleLevel.good:
          case _OracleLevel.exceptional:
            return const [
              'Sotto sole alto, non disperdere il raccolto.',
              'Estate ampia è: misura ferma, e pace verrà.',
            ];
        }
      case _OracleSeason.autumn:
        switch (level) {
          case _OracleLevel.gravelyInsufficient:
          case _OracleLevel.insufficient:
            return const [
              'Magro il raccolto sarà, se il granaio ora non curerai.',
              'Nel tempo che serra, più raccolta la mano dovrà farsi.',
            ];
          case _OracleLevel.sufficient:
          case _OracleLevel.good:
          case _OracleLevel.exceptional:
            return const [
              'Ciò che mieti, bene riponi: lungo il raccolto ti servirà.',
              'Tempo di serbare è: pieno il granaio, saldo il domani farà.',
            ];
        }
    }
  }

  static List<String> _titlesForLevel(
    _OracleLevel level,
    _OracleSeason season,
  ) {
    return [
      ..._baseTitlesForLevel(level),
      ..._seasonalTitlesForLevel(level, season),
    ];
  }

  static List<String> _baseTitlesForLevel(_OracleLevel level) {
    switch (level) {
      case _OracleLevel.gravelyInsufficient:
        return const [
          '✦ PROFANATORE DELLE RISERVE ✦',
          '✦ DIVORATORE DEL RACCOLTO ✦',
          '✦ SPEZZATORE DEL SIGILLO ✦',
          '✦ DISPERSO NELLA CORRENTE ✦',
          '✦ NEMICO DELLA RISERVA ✦',
          '✦ CUSTODE CADUTO ✦',
          '✦ ARALDO DELLO SPRECO ✦',
          '✦ FRANTUMATORE DEL FLUSSO ✦',
          '✦ ESULE DELLA MISURA ✦',
          '✦ OMBRA SUL TESORO ✦',
        ];
      case _OracleLevel.insufficient:
        return const [
          '✦ SMARRITO TRA I FLUSSI ✦',
          '✦ CERCATORE SENZA BUSSOLA ✦',
          '✦ VIANDANTE DEL MARGINE ✦',
          '✦ GUARDIANO INCERTO ✦',
          '✦ NAVIGANTE DELLE CREPE ✦',
          '✦ TENITORE VACILLANTE ✦',
          '✦ OSSERVATORE DEL BORDO ✦',
          '✦ PORTATORE DI TENSIONE ✦',
          '✦ CUSTODE IMPERFETTO ✦',
          '✦ PELLEGRINO DELLA STRETTA ✦',
        ];
      case _OracleLevel.sufficient:
        return const [
          '✦ CUSTODE DELLA CRESCITA ✦',
          '✦ GUARDIANO DELLA SOGLIA ✦',
          '✦ TENITORE DELLA MISURA ✦',
          '✦ VEGLIANTE DEL RACCOLTO ✦',
          '✦ CUSTODE DEL VARCO ✦',
          '✦ MEDITATORE DEI FLUSSI ✦',
          '✦ SORVEGLIANTE DEL MARGINE ✦',
          '✦ ARBITRO DELLA TENUTA ✦',
          '✦ ORDINATORE DEL RESPIRO ✦',
          '✦ REGGENTE DELLA SOGLIA ✦',
        ];
      case _OracleLevel.good:
        return const [
          '✦ DOMATORE DEI FLUSSI ✦',
          '✦ SIGNORE DELLA TENUTA ✦',
          '✦ ARTEFICE DELLA MISURA ✦',
          '✦ TESSITORE DEL RACCOLTO ✦',
          '✦ MAESTRO DEL MARGINE ✦',
          '✦ CUSTODE DELLA CALMA ✦',
          '✦ REGGITORE DEL CICLO ✦',
          '✦ DOMATORE DELLA CORRENTE ✦',
          '✦ ARCHITETTO DEL RESPIRO ✦',
          '✦ GOVERNATORE DEL VARCO ✦',
        ];
      case _OracleLevel.exceptional:
        return const [
          '✦ SOVRANO DELLA PECUNIA ✦',
          '✦ IMPERATORE DEL RACCOLTO ✦',
          '✦ ARCHONTE DELLA RISERVA ✦',
          '✦ MAESTRO DEL SIGILLO ✦',
          '✦ SIGNORE DEL TESORO QUIETO ✦',
          '✦ RE DELLA MISURA PIENA ✦',
          '✦ CUSTODE SUPREMO DEL FLUSSO ✦',
          '✦ DOMINATORE DELLA CALMA AUREA ✦',
          '✦ ORACOLO DELLA TENUTA PERFETTA ✦',
          '✦ SOVRINTENDENTE DEL RACCOLTO PIENO ✦',
        ];
    }
  }

  static List<String> _seasonalTitlesForLevel(
    _OracleLevel level,
    _OracleSeason season,
  ) {
    switch (season) {
      case _OracleSeason.winter:
        switch (level) {
          case _OracleLevel.gravelyInsufficient:
            return const ['✦ DISPERSO NEL GELO ✦', "✦ NUDO AL VENTO D'INVERNO ✦"];
          case _OracleLevel.insufficient:
            return const ['✦ CUSTODE DEL FOCOLARE VACILLANTE ✦', '✦ VIANDANTE DEL GELO ✦'];
          case _OracleLevel.sufficient:
            return const ['✦ GUARDIANO DEL FOCOLARE ✦', '✦ CUSTODE DELLA BRACE ✦'];
          case _OracleLevel.good:
            return const ['✦ SIGNORE DEL FOCOLARE ✦', '✦ DOMATORE DEL GELO ✦'];
          case _OracleLevel.exceptional:
            return const ['✦ SOVRANO DELLA BRACE QUIETA ✦', '✦ IMPERATORE DEL FOCOLARE ✦'];
        }
      case _OracleSeason.spring:
        switch (level) {
          case _OracleLevel.gravelyInsufficient:
            return const ['✦ STERMINATORE DEL GERMOGLIO ✦', '✦ CUSTODE DEL CAMPO SPOGLIO ✦'];
          case _OracleLevel.insufficient:
            return const ['✦ VIANDANTE DEL SEME DEBOLE ✦', '✦ GUARDIANO DEL GERMOGLIO INCERTO ✦'];
          case _OracleLevel.sufficient:
            return const ['✦ CUSTODE DEL PRIMO GERMOGLIO ✦', '✦ VEGLIANTE DEL SEME ✦'];
          case _OracleLevel.good:
            return const ['✦ TESSITORE DELLA FIORITURA ✦', '✦ GUARDIANO DEL VERDE NASCENTE ✦'];
          case _OracleLevel.exceptional:
            return const ['✦ SOVRANO DELLA FIORITURA ✦', '✦ ARCHONTE DEL GIARDINO PIENO ✦'];
        }
      case _OracleSeason.summer:
        switch (level) {
          case _OracleLevel.gravelyInsufficient:
            return const ['✦ DISPERSO NEL SOLE CRUDO ✦', '✦ DIVORATO DALLA CALURA ✦'];
          case _OracleLevel.insufficient:
            return const ['✦ VIANDANTE DELLA SETE ✦', "✦ GUARDIANO DELL'OMBRA CORTA ✦"];
          case _OracleLevel.sufficient:
            return const ["✦ CUSTODE DELL'OMBRA UTILE ✦", '✦ VEGLIANTE DEL SOLE MISURATO ✦'];
          case _OracleLevel.good:
            return const ['✦ DOMATORE DEL SOLE ✦', '✦ SIGNORE DELLA LUCE FERMA ✦'];
          case _OracleLevel.exceptional:
            return const ['✦ SOVRANO DELLA LUCE PIENA ✦', "✦ IMPERATORE DELL'ESTATE QUIETA ✦"];
        }
      case _OracleSeason.autumn:
        switch (level) {
          case _OracleLevel.gravelyInsufficient:
            return const ["✦ SPRECATORE DEL RACCOLTO D'AUTUNNO ✦", '✦ OMBRA SUL GRANAIO ✦'];
          case _OracleLevel.insufficient:
            return const ['✦ VIANDANTE DEL GRANAIO SCARSO ✦', '✦ GUARDIANO DELLE FOGLIE CADUTE ✦'];
          case _OracleLevel.sufficient:
            return const ['✦ CUSTODE DEL GRANAIO ✦', '✦ VEGLIANTE DEL RACCOLTO SOBRIO ✦'];
          case _OracleLevel.good:
            return const ['✦ SIGNORE DELLA MIETITURA ✦', '✦ TESSITORE DEL GRANAIO ✦'];
          case _OracleLevel.exceptional:
            return const ['✦ SOVRANO DEL GRANAIO PIENO ✦', '✦ IMPERATORE DELLA MIETITURA ✦'];
        }
    }
  }

  static String _normalizeLabel(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll('@', 'a')
        .replaceAll('à', 'a')
        .replaceAll('á', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('í', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ó', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('ú', 'u')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _joinOracleLines(List<String> observations) {
    return observations.where((line) => line.trim().isNotEmpty).join('\n');
  }

  static String _pick(List<String> list) {
    return list[_random.nextInt(list.length)];
  }
}
