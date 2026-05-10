// lib/services/upload_career_rules_from_string.dart

import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Call this once (from a debug button or main()).
/// Uploads career-based rules to Firestore → collection: career_rules
Future<void> uploadCareerRulesFromString() async {
  final firestore = FirebaseFirestore.instance;

  // 1) Guard flag to prevent re-upload
  final flagRef = firestore.collection('app_settings').doc('career_rules_status');
  final flag = await flagRef.get();
  if (flag.exists && flag.data()?['uploaded'] == true) {
    throw 'Career rules already uploaded (career_rules_status.uploaded == true)';
  }

  // 2) Your full rules block as a raw JSON array
  const String rulesBlock = r'''
[
  {
    "id": "c_student_01",
    "role": "Student",
    "text": "Track all pocket money and daily spending to build financial awareness.",
    "category": "Tracking",
    "priority": 70,
    "tags": ["student","tracking","awareness"],
    "active": true
  },
  {
    "id": "c_student_02",
    "role": "Student",
    "text": "Avoid unnecessary subscriptions and premium apps; audit recurring charges monthly.",
    "category": "Cutting Costs",
    "priority": 65,
    "tags": ["student","subscriptions","saving"],
    "active": true
  },
  {
    "id": "c_student_03",
    "role": "Student",
    "text": "Save a small fixed amount each week in a separate savings account to build habit.",
    "category": "Savings",
    "priority": 72,
    "tags": ["student","savings","habit"],
    "active": true
  },
  {
    "id": "c_student_04",
    "role": "Student",
    "text": "Use second-hand books, borrow materials, or share costs with classmates to reduce expenses.",
    "category": "Frugality",
    "priority": 60,
    "tags": ["student","books","frugal"],
    "active": true
  },
  {
    "id": "c_student_05",
    "role": "Student",
    "text": "Learn basic budgeting and investing concepts early—start with low-cost index funds or SIPs.",
    "category": "Education",
    "priority": 75,
    "tags": ["student","investing","education"],
    "active": true
  },
  {
    "id": "c_student_06",
    "role": "Student",
    "text": "Consider part-time or freelance work to gain income experience and build a small buffer.",
    "category": "Income",
    "priority": 58,
    "tags": ["student","part-time","income"],
    "active": true
  },
  {
    "id": "c_student_07",
    "role": "Student",
    "text": "Avoid taking loans for non-educational items; prefer saving for discretionary purchases.",
    "category": "Debt",
    "priority": 80,
    "tags": ["student","debt","discipline"],
    "active": true
  },

  {
    "id": "c_private_01",
    "role": "Private Employee",
    "text": "Adopt the 50-30-20 rule: 50% needs, 30% wants, 20% savings/debt repayment.",
    "category": "Budgeting",
    "priority": 85,
    "tags": ["private","budget","50-30-20"],
    "active": true
  },
  {
    "id": "c_private_02",
    "role": "Private Employee",
    "text": "Automate a portion of your salary into savings or retirement accounts on payday.",
    "category": "Automation",
    "priority": 80,
    "tags": ["private","automation","savings"],
    "active": true
  },
  {
    "id": "c_private_03",
    "role": "Private Employee",
    "text": "Build and maintain an emergency fund that covers 3–6 months of essential expenses.",
    "category": "Safety",
    "priority": 90,
    "tags": ["private","emergency","fund"],
    "active": true
  },
  {
    "id": "c_private_04",
    "role": "Private Employee",
    "text": "Review and trim recurring subscriptions; reallocate savings to higher-priority goals.",
    "category": "Optimization",
    "priority": 70,
    "tags": ["private","subscriptions","optimize"],
    "active": true
  },
  {
    "id": "c_private_05",
    "role": "Private Employee",
    "text": "Increase retirement contributions gradually each year, even by 1–2% annually.",
    "category": "Retirement",
    "priority": 78,
    "tags": ["private","retirement","contribute"],
    "active": true
  },
  {
    "id": "c_private_06",
    "role": "Private Employee",
    "text": "Wait 24 hours before making large non-essential purchases to curb impulse buying.",
    "category": "Behavior",
    "priority": 60,
    "tags": ["private","impulse","delay"],
    "active": true
  },

  {
    "id": "c_gov_01",
    "role": "Government Employee",
    "text": "Ensure consistent contributions to provident fund or pension schemes and review allocations.",
    "category": "Retirement",
    "priority": 85,
    "tags": ["government","pension","pf"],
    "active": true
  },
  {
    "id": "c_gov_02",
    "role": "Government Employee",
    "text": "Plan long-term investments—leverage stable income for balanced, long-horizon portfolios.",
    "category": "Investment",
    "priority": 78,
    "tags": ["government","investment","long-term"],
    "active": true
  },
  {
    "id": "c_gov_03",
    "role": "Government Employee",
    "text": "Avoid lifestyle inflation after pay raises—channel part of increments to savings or investments.",
    "category": "Discipline",
    "priority": 74,
    "tags": ["government","inflation","discipline"],
    "active": true
  },
  {
    "id": "c_gov_04",
    "role": "Government Employee",
    "text": "Allocate bonuses or arrears directly to investments or debt repayment instead of spending.",
    "category": "Windfalls",
    "priority": 70,
    "tags": ["government","bonus","allocate"],
    "active": true
  },
  {
    "id": "c_gov_05",
    "role": "Government Employee",
    "text": "Maintain paperwork and documentation for pensions, service records, and benefits to avoid disputes.",
    "category": "Administration",
    "priority": 65,
    "tags": ["government","documents","pension"],
    "active": true
  },

  {
    "id": "c_self_01",
    "role": "Self Employeed",
    "text": "Separate business and personal finances—use dedicated accounts for clarity and taxes.",
    "category": "Accounting",
    "priority": 90,
    "tags": ["self-employed","business","separation"],
    "active": true
  },
  {
    "id": "c_self_02",
    "role": "Self Employeed",
    "text": "Save aggressively during high-income months to cover low-income periods—aim for a 6-month buffer.",
    "category": "Safety",
    "priority": 92,
    "tags": ["self-employed","buffer","savings"],
    "active": true
  },
  {
    "id": "c_self_03",
    "role": "Self Employeed",
    "text": "Track all business receipts and expenses to claim deductions and improve cash flow visibility.",
    "category": "Tax",
    "priority": 80,
    "tags": ["self-employed","tax","receipts"],
    "active": true
  },
  {
    "id": "c_self_04",
    "role": "Self Employeed",
    "text": "Invest in health and liability insurance to protect against business and personal risks.",
    "category": "Insurance",
    "priority": 85,
    "tags": ["self-employed","insurance","health"],
    "active": true
  },
  {
    "id": "c_self_05",
    "role": "Self Employeed",
    "text": "Avoid over-leveraging—only take loans that your business cash flow can comfortably service.",
    "category": "Credit",
    "priority": 88,
    "tags": ["self-employed","loans","leverage"],
    "active": true
  },
  {
    "id": "c_self_06",
    "role": "Self Employeed",
    "text": "Automate tax set-asides from income to avoid surprise liabilities at year-end.",
    "category": "Taxes",
    "priority": 82,
    "tags": ["self-employed","taxes","automation"],
    "active": true
  },

  {
    "id": "c_freelancer_01",
    "role": "Freelancer",
    "text": "Treat yourself like a business—budget for income, expenses, taxes, and reinvestment.",
    "category": "Mindset",
    "priority": 80,
    "tags": ["freelancer","business","mindset"],
    "active": true
  },

  {
    "id": "c_freelancer_02",
    "role": "Freelancer",
    "text": "Save a fixed percentage (10–30%) from every invoice to cover taxes and savings.",
    "category": "Savings",
    "priority": 85,
    "tags": ["freelancer","savings","invoice"],
    "active": true
  },
  {
    "id": "c_freelancer_03",
    "role": "Freelancer",
    "text": "Create multiple income streams or diversify clients to reduce dependency on one source.",
    "category": "Diversification",
    "priority": 78,
    "tags": ["freelancer","diversify","clients"],
    "active": true
  },
  {
    "id": "c_freelancer_04",
    "role": "Freelancer",
    "text": "Maintain a working capital buffer to cover lean months and unexpected expenses.",
    "category": "Buffer",
    "priority": 88,
    "tags": ["freelancer","buffer","capital"],
    "active": true
  },
  {
    "id": "c_freelancer_05",
    "role": "Freelancer",
    "text": "Regularly review subscription tools and software—cancel or downgrade unused services.",
    "category": "Optimization",
    "priority": 65,
    "tags": ["freelancer","subscriptions","optimize"],
    "active": true
  },

  {
    "id": "c_homemaker_01",
    "role": "Homemaker",
    "text": "Track household expenses to identify areas where you can save without reducing quality of life.",
    "category": "Tracking",
    "priority": 70,
    "tags": ["homemaker","tracking","household"],
    "active": true
  },
  
  {
    "id": "c_homemaker_02",
    "role": "Homemaker",
    "text": "Create and follow a monthly grocery list to reduce impulsive purchases and waste.",
    "category": "Groceries",
    "priority": 68,
    "tags": ["homemaker","grocery","planning"],
    "active": true
  },
  {
    "id": "c_homemaker_03",
    "role": "Homemaker",
    "text": "Start a small personal savings habit—even a modest weekly amount builds over time.",
    "category": "Savings",
    "priority": 60,
    "tags": ["homemaker","savings","habit"],
    "active": true
  },
  {
    "id": "c_homemaker_04",
    "role": "Homemaker",
    "text": "Encourage periodic family budget meetings to align spending priorities and goals.",
    "category": "Communication",
    "priority": 66,
    "tags": ["homemaker","family","budget"],
    "active": true
  },
  {
    "id": "c_homemaker_05",
    "role": "Homemaker",
    "text": "Choose DIY solutions or repurpose items where practical to extend household budgets.",
    "category": "Frugality",
    "priority": 62,
    "tags": ["homemaker","diy","frugal"],
    "active": true
  },

  {
    "id": "c_retired_01",
    "role": "Retired person",
    "text": "Prioritize essential spending and reduce discretionary expenses to preserve capital.",
    "category": "Conservation",
    "priority": 88,
    "tags": ["retired","conserve","budget"],
    "active": true
  },
  {
    "id": "c_retired_02",
    "role": "Retired person",
    "text": "Prefer low-volatility income-generating instruments and avoid speculative investments.",
    "category": "Investment",
    "priority": 90,
    "tags": ["retired","income","low-volatility"],
    "active": true
  },
  {
    "id": "c_retired_03",
    "role": "Retired person",
    "text": "Track medical and healthcare expenses and plan for insurance renewals in advance.",
    "category": "Healthcare",
    "priority": 85,
    "tags": ["retired","medical","insurance"],
    "active": true
  },
  {
    "id": "c_retired_04",
    "role": "Retired person",
    "text": "Maintain a small liquid emergency fund for unexpected needs without touching long-term investments.",
    "category": "Safety",
    "priority": 82,
    "tags": ["retired","emergency","liquid"],
    "active": true
  },
  {
    "id": "c_retired_05",
    "role": "Retired person",
    "text": "Avoid taking new loans; focus on managing existing obligations conservatively.",
    "category": "Debt",
    "priority": 80,
    "tags": ["retired","loans","debt"],
    "active": true
  },

  {
    "id": "c_other_01",
    "role": "Other",
    "text": "Track all expenses for a month to understand where your money goes before making changes.",
    "category": "Tracking",
    "priority": 60,
    "tags": ["other","tracking"],
    "active": true
  },
  
  {
    "id": "c_other_02",
    "role": "Other",
    "text": "Set one small financial goal each month (save a certain amount or reduce one expense).",
    "category": "Goal",
    "priority": 65,
    "tags": ["other","goal"],
    "active": true
  },

  {
    "id": "c_other_03",
    "role": "Other",
    "text": "Avoid emotional buying; compare options and wait before making non-essential purchases.",
    "category": "Behavior",
    "priority": 58,
    "tags": ["other","behavior"],
    "active": true
  },
  {
    "id": "c_other_04",
    "role": "Other",
    "text": "Start small investments early to benefit from compounding—even modest monthly contributions help.",
    "category": "Investment",
    "priority": 70,
    "tags": ["other","investment","compound"],
    "active": true
  },
  {
    "id": "c_other_05",
    "role": "Other",
    "text": "Maintain an emergency fund regardless of income type to handle unforeseen events.",
    "category": "Safety",
    "priority": 75,
    "tags": ["other","emergency","safety"],
    "active": true
  }
]
  ''';

  // 3) Parse JSON array
  late final List<dynamic> rulesList;
  try {
    rulesList = jsonDecode(rulesBlock) as List<dynamic>;
  } catch (e) {
    throw 'Failed to parse career rules JSON: $e';
  }

  if (rulesList.isEmpty) throw 'No rules found in JSON block';

  // 4) Batch upload
  const int batchSize = 400;
  for (var i = 0; i < rulesList.length; i += batchSize) {
    final batch = firestore.batch();
    final end = math.min(i + batchSize, rulesList.length);
    final chunk = rulesList.sublist(i, end);

    for (final item in chunk) {
      if (item is Map && item.containsKey('id')) {
        final id = item['id'].toString();
        final docRef = firestore.collection('role_rules').doc(id);
        batch.set(docRef, Map<String, dynamic>.from(item));
      }
    }

    try {
      await batch.commit();
    } on FirebaseException catch (fe) {
      throw 'Batch commit failed: ${fe.code} — ${fe.message}';
    }
  }

  // 5) Set uploaded flag
  await flagRef.set({
    'uploaded': true,
    'uploadedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
