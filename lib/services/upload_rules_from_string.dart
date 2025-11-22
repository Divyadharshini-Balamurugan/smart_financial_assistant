// lib/services/upload_rules_from_string.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Call this function once (from main() or from a debug button).
/// It will parse the embedded rulesBlock and upload each rule using its `id` as doc id.
Future<void> uploadSuggestionRulesFromString() async {
  final firestore = FirebaseFirestore.instance;

  // 1) One-time guard flag
  final flagRef = firestore.collection('app_settings').doc('rules_status');
  final flag = await flagRef.get();
  if (flag.exists && flag.data()?['uploaded'] == true) {
    throw 'Rules already uploaded (app_settings.rules_status.uploaded == true)';
  }

  // 2) Paste your rules block here (exactly as you provided). Keep it as a raw string.
  const String rulesBlock = r'''
{
  "id":"r001",
  "title":"Student — Start small emergency fund",
  "conditions":{"role":{"in":["Student"]},"monthlyObligations":{"containsAny":[]}},
  "suggestion":{
    "text":"As a student, prioritize a small emergency fund and low-cost investments. Aim to save 5-10% of any income or allowances.",
    "actions":[
      {"type":"save_percent","value":5,"note":"Save 5% of monthly income"},
      {"type":"open_account","value":"high_yield_savings","note":"Use a separate emergency account"}
    ],
    "priority":60
  },
  "tags":["student","emergency"],
  "active":true
}
{
  "id":"r002",
  "title":"Salaried with Rent/EMI — 50/30/20 baseline",
  "conditions":{"role":{"in":["Private Employee","Government Employee"]},"monthlyObligations":{"contains":"Rent/EMI"}},
  "suggestion":{
    "text":"Use a 50/30/20 baseline: 50% needs (including rent/EMI), 30% wants, 20% savings/debt repayment. Prioritize emergency fund to cover 3 months of essential expenses.",
    "actions":[
      {"type":"budget_split","value":{"needs":50,"wants":30,"savings":20}},
      {"type":"save_months_of_expense","value":3,"note":"Emergency fund target"}
    ],
    "priority":85
  },
  "tags":["salaried","rent","budget"],
  "active":true
}
{
  "id":"r003",
  "title":"High debt obligations — prioritize debt repayment",
  "conditions":{"monthlyObligations":{"containsAny":["Loan Repayment","Credit card bills"]}},
  "suggestion":{
    "text":"High monthly debt payments: allocate extra to high-interest debts. Reduce discretionary spending (subscriptions, dining out) and channel saved money to debt.",
    "actions":[
      {"type":"cut_category","category":"Subscriptions","value":40,"note":"Cancel or downgrade unnecessary subscriptions"},
      {"type":"debt_focus","value":"highest_interest_first","note":"Avalanche method"}
    ],
    "priority":95
  },
  "tags":["debt","urgent"],
  "active":true
}
{
  "id":"r004",
  "title":"Irregular income — build buffer and separate accounts",
  "conditions":{"role":{"in":["Self Employeed","Freelancer"]},"incomeSources":{"containsAny":["Business profits","Freelance/ contract work"]}},
  "suggestion":{
    "text":"Irregular income: keep a 6-month buffer in liquid savings and split income into buckets: tax, operations, owner pay, savings.",
    "actions":[
      {"type":"save_months_of_expense","value":6},
      {"type":"create_buckets","value":["tax","operations","owner_pay","savings"],"note":"Allocate each invoice"}
    ],
    "priority":90
  },
  "tags":["irregular","self-employed"],
  "active":true
}
{
  "id":"r005",
  "title":"Household with dependents — protect essentials & insurance",
  "conditions":{"role":{"in":["Homemaker"]},"monthlyObligations":{"contains":"Child/ family expenses"}},
  "suggestion":{
    "text":"Focus on shielding essentials (groceries, utilities) and secure life/health insurance for earning members. Build emergency fund and small sinking funds for school fees.",
    "actions":[
      {"type":"insurance_check","value":["health","term_life"],"note":"Ensure primary earners covered"},
      {"type":"sinking_fund","value":{"education":0},"note":"Start monthly contributions for education"}
    ],
    "priority":80
  },
  "tags":["household","insurance"],
  "active":true
}
{
  "id":"r006",
  "title":"Retired — preserve capital, steady income",
  "conditions":{"role":{"in":["Retired person"]},"incomeSources":{"contains":"Pension"}},
  "suggestion":{
    "text":"As a retiree, prioritize stable income and capital preservation. Move portion of savings to low-volatility instruments and keep a liquid monthly buffer.",
    "actions":[
      {"type":"reallocate","value":{"equity":10,"bonds":60,"cash":30},"note":"Consider lower-risk mix"},
      {"type":"withdrawal_plan","value":"monthly_needs","note":"Match income to monthly outflow"}
    ],
    "priority":85
  },
  "tags":["retired","preserve"],
  "active":true
}
{
  "id":"r007",
  "title":"Goal: Emergency fund (no big obligations)",
  "conditions":{"goals":{"contains":"Emergency fund"}},
  "suggestion":{
    "text":"If emergency fund is a priority, funnel 10-20% of income to a liquid account until you reach 3-6 months of essentials.",
    "actions":[
      {"type":"save_percent","value":15,"note":"Suggested starting %"},
      {"type":"save_months_of_expense","value":3}
    ],
    "priority":88
  },
  "tags":["goal","emergency"],
  "active":true
}
{
  "id":"r008",
  "title":"House goal while paying rent/EMI — balance saving and debt",
  "conditions":{"goals":{"contains":"Buying a house"},"monthlyObligations":{"contains":"Rent/EMI"}},
  "suggestion":{
    "text":"If buying a house is a goal but you're already paying rent/EMI, prioritize downpayment savings via a dedicated SIP or recurring deposit while avoiding new high-interest debt.",
    "actions":[
      {"type":"create_goal_savings","value":{"name":"home_downpayment","monthly":0},"note":"Start recurring deposit"},
      {"type":"cut_category","category":"Wants","value":20}
    ],
    "priority":87
  },
  "tags":["home","goal"],
  "active":true
}
{
  "id":"r009",
  "title":"Retirement planning — increase long-term investments",
  "conditions":{"goals":{"contains":"Retirement planning"},"incomeSources":{"containsAny":["Salary","Pension","Investments(rental, interest, etc)"]}},
  "suggestion":{
    "text":"Boost retirement savings: increase retirement contributions (e.g., 401k/EPF/PPF/retirement mutual funds) by 1-2% yearly and use tax-efficient vehicles.",
    "actions":[
      {"type":"increase_retirement_contribution","value":2,"unit":"percent","note":"Increase contribution annually"},
      {"type":"tax_efficient_saving","value":"ppf_or_similar"}
    ],
    "priority":90
  },
  "tags":["retirement","longterm"],
  "active":true
}
{
  "id":"r010",
  "title":"Reducing debt — aggressive payments",
  "conditions":{"goals":{"contains":"Reducing debt"}},
  "suggestion":{
    "text":"If debt reduction is the main goal, channel windfalls and cut discretionary spend to make extra payments. Consider consolidation if interest rates vary greatly.",
    "actions":[
      {"type":"extra_payment","value":"all_windfalls","note":"Use bonuses, tax refunds for debt"},
      {"type":"consolidation_check","value":true}
    ],
    "priority":95
  },
  "tags":["debt","priority"],
  "active":true
}
{
  "id":"r011",
  "title":"Investment income — tax & diversification",
  "conditions":{"incomeSources":{"contains":"Investments(rental, interest, etc)"}},
  "suggestion":{
    "text":"With investment income, focus on diversification and tax-efficient planning. Reinvest some returns and keep separate working capital for property/maintenance.",
    "actions":[
      {"type":"diversify","value":true},
      {"type":"tax_planning_check","value":true}
    ],
    "priority":75
  },
  "tags":["investments","tax"],
  "active":true
}
{
  "id":"r012",
  "title":"Allowance/Support — track & automate savings",
  "conditions":{"incomeSources":{"contains":"Allowance/ support"}},
  "suggestion":{
    "text":"If income is allowance/support, track spend categories carefully and automate small savings transfers when allowance arrives.",
    "actions":[
      {"type":"auto_transfer","value":{"percent":10},"note":"Automate 10% to savings"},
      {"type":"expense_tracking","value":true}
    ],
    "priority":65
  },
  "tags":["low_income","automation"],
  "active":true
}
{
  "id":"r013",
  "title":"High subscriptions/wants — trim discretionary",
  "conditions":{"monthlyObligations":{"contains":"Subscriptions"}},
  "suggestion":{
    "text":"Subscriptions add up—audit recurring charges and cancel unused ones. Re-allocate savings to higher-priority goals.",
    "actions":[
      {"type":"audit_subscriptions","value":true},
      {"type":"cut_category","category":"Subscriptions","value":50}
    ],
    "priority":70
  },
  "tags":["subscriptions","cut"],
  "active":true
}
{
  "id":"r014",
  "title":"Saving for Education — start a dedicated fund",
  "conditions":{"goals":{"contains":"Saving for Education"}},
  "suggestion":{
    "text":"Open a separate recurring deposit/SIP for education goals. If the timeline is short, prefer safer instruments; if long, consider equity SIPs.",
    "actions":[
      {"type":"create_goal_savings","value":{"name":"education_savings","monthly":0}},
      {"type":"risk_based_allocation","value":{"<3_years":"debt","3-10_years":"balanced","10+_years":"equity"}}
    ],
    "priority":80
  },
  "tags":["education","goal"],
  "active":true
}
{
  "id":"r015",
  "title":"Baseline — 3-step starter plan",
  "conditions":{},
  "suggestion":{
    "text":"Starter plan: (1) Track expenses for 1 month, (2) set a 10% auto-save rule, (3) build 1 month emergency buffer then increase.",
    "actions":[
      {"type":"track_expenses","value":30,"unit":"days"},
      {"type":"auto_save_percent","value":10}
    ],
    "priority":50
  },
  "tags":["baseline","starter"],
  "active":true
}
''';

  // 3) Normalize into a JSON array: replace `}{` (object boundary) with `},\n{`
  final normalized = rulesBlock.replaceAll(RegExp(r'}\s*{'), '},\n{');
  final jsonArrayText = '[\n$normalized\n]';

  final List<dynamic> rulesList;
  try {
    rulesList = jsonDecode(jsonArrayText) as List<dynamic>;
  } catch (e) {
    throw 'Failed to parse rules JSON: $e';
  }

  if (rulesList.isEmpty) {
    throw 'No rules found in provided block.';
  }

  // 4) Batch upload using rule id as document id (prevents duplicates)
  const int batchSize = 400;
  for (var i = 0; i < rulesList.length; i += batchSize) {
    final batch = firestore.batch();
    final end = math.min(i + batchSize, rulesList.length);
    final chunk = rulesList.sublist(i, end);

    for (final item in chunk) {
      if (item is Map && item.containsKey('id')) {
        final id = item['id'].toString();
        final docRef = firestore.collection('suggestion_rules').doc(id);
        batch.set(docRef, Map<String, dynamic>.from(item));
      } else {
        // skip invalid item
      }
    }

    // commit each batch
    try {
      await batch.commit();
    } on FirebaseException catch (fe) {
      throw 'Batch commit failed: ${fe.code} ${fe.message}';
    }
  }

  // 5) Set uploaded flag (so this won't run again)
  await flagRef.set({
    'uploaded': true,
    'uploadedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}


