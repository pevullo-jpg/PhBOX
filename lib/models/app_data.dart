import 'package:family_boxes_2/models/app_category.dart';
import 'package:family_boxes_2/models/box.dart';
import 'package:family_boxes_2/models/cashflow.dart';
import 'package:family_boxes_2/models/fund.dart';
import 'package:family_boxes_2/models/monthly_snapshot.dart';
import 'package:family_boxes_2/models/recurring.dart';
import 'package:family_boxes_2/models/recurring_group.dart';
import 'package:family_boxes_2/models/transaction.dart';

class AppData {
  List<BoxModel> boxes;
  List<Fund> funds;
  List<TransactionModel> transactions;
  List<Recurring> recurring;
  List<Cashflow> cashflows;
  List<RecurringGroup> recurringGroups;
  List<AppCategory> categories;
  List<MonthlySnapshot> monthlySnapshots;

  AppData({
    required this.boxes,
    required this.funds,
    required this.transactions,
    required this.recurring,
    required this.cashflows,
    required this.recurringGroups,
    required this.categories,
    required this.monthlySnapshots,
  });

  factory AppData.empty() {
    return AppData(
      boxes: [],
      funds: [],
      transactions: [],
      recurring: [],
      cashflows: [],
      recurringGroups: [],
      categories: [],
      monthlySnapshots: [],
    );
  }

  factory AppData.initialTemplate({List<String> familyMembers = const []}) {
    const personalColors = [
      4294929205,
      4286263230,
      4293467788,
      4293212469,
    ];

    final boxes = <BoxModel>[
      BoxModel(
        id: 'box_risparmi_core',
        name: 'RISPARMI',
        initialAmount: 0.0,
        color: 4286263230,
      ),
      BoxModel(
        id: 'box_necessita_core',
        name: 'NECESSITÀ',
        initialAmount: 0.0,
        color: 4293467788,
      ),
      BoxModel(
        id: 'box_abbonamenti_core',
        name: 'ABBONAMENTI',
        initialAmount: 0.0,
        color: 4293212469,
      ),
      BoxModel(
        id: 'box_necessita_annuali_core',
        name: 'NECESSITÀ ANNUALI',
        initialAmount: 0.0,
        color: 4286263230,
      ),
    ];

    for (int i = 0; i < familyMembers.length; i++) {
      final member = familyMembers[i].trim();
      if (member.isEmpty) {
        continue;
      }
      boxes.add(
        BoxModel(
          id: 'box_personal_${i + 1}',
          name: member.toUpperCase(),
          initialAmount: 0.0,
          color: personalColors[i % personalColors.length],
        ),
      );
    }

    return AppData(
      boxes: boxes,
      funds: [],
      transactions: [],
      recurring: [],
      cashflows: [],
      recurringGroups: [
        RecurringGroup(id: 'group_risparmi_core', name: 'RISPARMI'),
        RecurringGroup(id: 'group_necessita_core', name: 'NECESSITÀ'),
        RecurringGroup(id: 'group_abbonamenti_core', name: 'ABBONAMENTI'),
        RecurringGroup(
          id: 'group_necessita_annuali_core',
          name: 'NECESSITÀ ANNUALI',
        ),
      ],
      categories: [],
      monthlySnapshots: [],
    );
  }


  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      boxes: ((json['boxes'] as List?) ?? [])
          .map((e) => BoxModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      funds: ((json['funds'] as List?) ?? [])
          .map((e) => Fund.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      transactions: ((json['transactions'] as List?) ?? [])
          .map((e) =>
              TransactionModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      recurring: ((json['recurring'] as List?) ?? [])
          .map((e) => Recurring.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      cashflows: ((json['cashflows'] as List?) ?? [])
          .map((e) => Cashflow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      recurringGroups: ((json['recurringGroups'] as List?) ?? [])
          .map(
            (e) => RecurringGroup.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      categories: ((json['categories'] as List?) ?? [])
          .map((e) => AppCategory.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      monthlySnapshots: ((json['monthlySnapshots'] as List?) ?? [])
          .map(
            (e) =>
                MonthlySnapshot.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'boxes': boxes.map((e) => e.toJson()).toList(),
      'funds': funds.map((e) => e.toJson()).toList(),
      'transactions': transactions.map((e) => e.toJson()).toList(),
      'recurring': recurring.map((e) => e.toJson()).toList(),
      'cashflows': cashflows.map((e) => e.toJson()).toList(),
      'recurringGroups': recurringGroups.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'monthlySnapshots': monthlySnapshots.map((e) => e.toJson()).toList(),
    };
  }
}
