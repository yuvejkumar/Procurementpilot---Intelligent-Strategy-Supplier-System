
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';

// ============================================================
// ⚠️ PASTE YOUR GEMINI KEY
// ============================================================
const String GEMINI_API_KEY = "your_gemini_api";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProcureAIApp());
}

// ============================================================
// COLORS
// ============================================================
class AppColors {
  static const Color bg = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF141B2D);
  static const Color card = Color(0xFF1A2238);
  static const Color primary = Color(0xFF00FF9C);
  static const Color secondary = Color(0xFF00D4FF);
  static const Color danger = Color(0xFFFF3B6B);
  static const Color warning = Color(0xFFFFB800);
  static const Color textDim = Color(0xFF8892B0);
  static const Color textBright = Color(0xFFCCD6F6);
}

// ============================================================
// AUTH
// ============================================================
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authState => _auth.authStateChanges();

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred = await _auth.signInWithCredential(credential);
      if (userCred.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
          'uid': userCred.user!.uid,
          'name': userCred.user!.displayName ?? 'User',
          'email': userCred.user!.email ?? '',
          'photoUrl': userCred.user!.photoURL ?? '',
          'lastLogin': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return userCred;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

// ============================================================
// MODELS
// ============================================================
class Supplier {
  String id;
  String name;
  String category;
  double price;
  int deliveryDays;
  int capacity;
  int minOrder;
  double reliability;
  double qualityScore;
  double priceRisk;
  double deliveryRisk;
  double qualityRisk;
  double capacityRisk;
  int currentStock;
  String location;

  Supplier({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.deliveryDays,
    required this.capacity,
    required this.minOrder,
    required this.reliability,
    required this.qualityScore,
    required this.priceRisk,
    required this.deliveryRisk,
    required this.qualityRisk,
    required this.capacityRisk,
    required this.currentStock,
    required this.location,
  });

  double get overallRisk =>
      (priceRisk + deliveryRisk + qualityRisk + capacityRisk + (1 - reliability)) / 5;

  factory Supplier.fromJson(String id, Map<String, dynamic> j) => Supplier(
        id: id,
        name: j['name'] ?? 'Unknown',
        category: j['category'] ?? 'General',
        price: (j['price'] ?? 0).toDouble(),
        deliveryDays: (j['deliveryDays'] ?? 5).toInt(),
        capacity: (j['capacity'] ?? 1000).toInt(),
        minOrder: (j['minOrder'] ?? 100).toInt(),
        reliability: (j['reliability'] ?? 0.85).toDouble(),
        qualityScore: (j['qualityScore'] ?? 0.85).toDouble(),
        priceRisk: (j['priceRisk'] ?? 0.3).toDouble(),
        deliveryRisk: (j['deliveryRisk'] ?? 0.3).toDouble(),
        qualityRisk: (j['qualityRisk'] ?? 0.3).toDouble(),
        capacityRisk: (j['capacityRisk'] ?? 0.3).toDouble(),
        currentStock: (j['currentStock'] ?? 500).toInt(),
        location: j['location'] ?? 'India',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'price': price,
        'deliveryDays': deliveryDays,
        'capacity': capacity,
        'minOrder': minOrder,
        'reliability': reliability,
        'qualityScore': qualityScore,
        'priceRisk': priceRisk,
        'deliveryRisk': deliveryRisk,
        'qualityRisk': qualityRisk,
        'capacityRisk': capacityRisk,
        'currentStock': currentStock,
        'location': location,
      };
}

class AllocationItem {
  final String supplierName;
  final int quantity;
  final double percentage;
  final double cost;
  final int deliveryDays;
  final String rationale;

  AllocationItem({
    required this.supplierName,
    required this.quantity,
    required this.percentage,
    required this.cost,
    required this.deliveryDays,
    required this.rationale,
  });
}

class AIStrategyResult {
  final String title;
  final String reasoning;
  final double totalCost;
  final int totalRiskScore;
  final int estimatedDays;
  final List<AllocationItem> allocations;
  final List<String> insights;
  final List<String> warnings;
  final bool isBaseline;

  AIStrategyResult({
    required this.title,
    required this.reasoning,
    required this.totalCost,
    required this.totalRiskScore,
    required this.estimatedDays,
    required this.allocations,
    this.insights = const [],
    this.warnings = const [],
    this.isBaseline = false,
  });
}

class StrategyBundle {
  final AIStrategyResult cheapest;
  final AIStrategyResult safest;
  final AIStrategyResult balanced;
  final AIStrategyResult baseline;

  StrategyBundle({
    required this.cheapest,
    required this.safest,
    required this.balanced,
    required this.baseline,
  });
}

class HistoryEvent {
  final String id;
  final DateTime time;
  final String title;
  final String? subtitle;
  final String type;

  HistoryEvent({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  factory HistoryEvent.fromJson(String id, Map<String, dynamic> j) => HistoryEvent(
        id: id,
        title: j['title'] ?? '',
        subtitle: j['subtitle'],
        type: j['type'] ?? 'system',
        time: (j['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'type': type,
        'time': Timestamp.fromDate(time),
        'userId': AuthService.currentUser?.uid ?? '',
        'userEmail': AuthService.currentUser?.email ?? '',
      };
}

class ProcurementRequest {
  int quantity;
  int maxDays;
  double maxBudget;
  String priority;
  String notes;

  ProcurementRequest({
    this.quantity = 1000,
    this.maxDays = 7,
    this.maxBudget = 200000,
    this.priority = 'balanced',
    this.notes = '',
  });
}

// ============================================================
// RANDOM FOREST STYLE ML BACKEND (Deterministic)
// Mirrors your trained .joblib model logic in-app for hackathon.
// Same inputs => same risk / same % splits.
// ============================================================
class RandomForestMLBackend {
  /// Predict overall risk 0-100 (like your RF model target)
  static double predictOverallRisk(Supplier s, {double disruptionSeverity = 0}) {
    final reliabilityRisk = (1.0 - s.reliability) * 35;
    final qualityRisk = (1.0 - s.qualityScore) * 20;
    final priceRisk = s.priceRisk * 15;
    final deliveryRisk = s.deliveryRisk * 15;
    final capacityRisk = s.capacityRisk * 10;
    final disruption = disruptionSeverity * 0.2;
    return (reliabilityRisk + qualityRisk + priceRisk + deliveryRisk + capacityRisk + disruption)
        .clamp(5.0, 98.0);
  }

  static double predictUnitPrice(Supplier s, {double disruptionSeverity = 0, int orderQty = 1000}) {
    double price = s.price;
    if (orderQty >= 5000) price *= 0.95;
    if (disruptionSeverity > 0) price *= (1 + disruptionSeverity / 200);
    return price;
  }

  static int predictDeliveryDays(Supplier s, {double disruptionSeverity = 0}) {
    double days = s.deliveryDays.toDouble();
    days += (1 - s.reliability) * 3;
    if (disruptionSeverity > 0) days *= (1 + disruptionSeverity / 150);
    return max(1, days.round());
  }

  static double _score(Supplier s, {required double costW, required double riskW, required double speedW}) {
    final risk = predictOverallRisk(s);
    final price = predictUnitPrice(s);
    final days = predictDeliveryDays(s).toDouble();
    return price * costW + risk * riskW + days * 8 * speedW;
  }

  static StrategyBundle generateAll(List<Supplier> suppliers, ProcurementRequest req) {
    final cheapest = _allocate(
      name: 'Cheapest Strategy',
      suppliers: suppliers,
      req: req,
      costW: 1.0,
      riskW: 0.0,
      speedW: 0.0,
      isBaseline: true,
    );
    final safest = _allocate(
      name: 'Safest Strategy',
      suppliers: suppliers,
      req: req,
      costW: 0.1,
      riskW: 1.0,
      speedW: 0.2,
    );
    final balancedRaw = _allocate(
      name: 'Balanced Strategy (RF Optimized)',
      suppliers: suppliers,
      req: req,
      costW: req.priority == 'cost'
          ? 0.75
          : req.priority == 'speed'
              ? 0.35
              : req.priority == 'quality'
                  ? 0.3
                  : 0.5,
      riskW: req.priority == 'quality'
          ? 0.55
          : req.priority == 'cost'
              ? 0.2
              : 0.35,
      speedW: req.priority == 'speed' ? 0.45 : 0.15,
    );

    final riskDrop = cheapest.totalRiskScore == 0
        ? 0.0
        : ((cheapest.totalRiskScore - balancedRaw.totalRiskScore) / cheapest.totalRiskScore * 100);
    final costDrop = safest.totalCost == 0
        ? 0.0
        : ((safest.totalCost - balancedRaw.totalCost) / safest.totalCost * 100);

    final balanced = AIStrategyResult(
      title: balancedRaw.title,
      reasoning: '', // Gemini fills later
      totalCost: balancedRaw.totalCost,
      totalRiskScore: balancedRaw.totalRiskScore,
      estimatedDays: balancedRaw.estimatedDays,
      allocations: balancedRaw.allocations,
      insights: [
        'Splits produced by deterministic RF-style engine (not LLM).',
        '${riskDrop.toStringAsFixed(0)}% lower risk than cheapest baseline.',
        '${costDrop.toStringAsFixed(0)}% lower cost than safest strategy.',
        'Percentages sum to ~100% of requested quantity.',
        'Capacity & min-order constraints enforced.',
      ],
      warnings: balancedRaw.warnings,
    );

    return StrategyBundle(
      cheapest: cheapest,
      safest: safest,
      balanced: balanced,
      baseline: cheapest,
    );
  }

  static AIStrategyResult _allocate({
    required String name,
    required List<Supplier> suppliers,
    required ProcurementRequest req,
    required double costW,
    required double riskW,
    required double speedW,
    bool isBaseline = false,
  }) {
    if (suppliers.isEmpty) {
      return AIStrategyResult(
        title: name,
        reasoning: '',
        totalCost: 0,
        totalRiskScore: 100,
        estimatedDays: 0,
        allocations: const [],
        warnings: const ['No suppliers available'],
        isBaseline: isBaseline,
      );
    }

    final ranked = List<Supplier>.from(suppliers)
      ..sort((a, b) => _score(a, costW: costW, riskW: riskW, speedW: speedW)
          .compareTo(_score(b, costW: costW, riskW: riskW, speedW: speedW)));

    // Diversify across top 3 when possible (still deterministic)
    final targets = ranked.take(min(3, ranked.length)).toList();
    final rawWeights = targets.map((s) {
      final sc = _score(s, costW: costW, riskW: riskW, speedW: speedW);
      return 1.0 / (sc + 1e-6);
    }).toList();
    final weightSum = rawWeights.fold(0.0, (a, b) => a + b);

    final desired = <int>[];
    int assigned = 0;
    for (int i = 0; i < targets.length; i++) {
      if (i == targets.length - 1) {
        desired.add(max(0, req.quantity - assigned));
      } else {
        final q = (req.quantity * (rawWeights[i] / weightSum)).round();
        desired.add(q);
        assigned += q;
      }
    }

    final qty = List<int>.filled(targets.length, 0);
    int remaining = req.quantity;

    for (int i = 0; i < targets.length; i++) {
      final s = targets[i];
      int take = min(desired[i], s.capacity);
      take = min(take, remaining);
      if (take > 0 && take < s.minOrder) {
        take = (s.capacity >= s.minOrder && remaining >= s.minOrder) ? s.minOrder : 0;
      }
      take = min(take, remaining);
      qty[i] = take;
      remaining -= take;
    }

    // Fill leftovers
    if (remaining > 0) {
      for (int i = 0; i < targets.length && remaining > 0; i++) {
        final s = targets[i];
        final can = s.capacity - qty[i];
        if (can <= 0) continue;
        int add = min(can, remaining);
        if (qty[i] == 0 && add < s.minOrder) {
          if (can >= s.minOrder && remaining >= s.minOrder) {
            add = s.minOrder;
          } else {
            continue;
          }
        }
        add = min(add, remaining);
        qty[i] += add;
        remaining -= add;
      }
    }

    final allocations = <AllocationItem>[];
    double totalCost = 0;
    double riskAcc = 0;
    int maxDays = 0;

    for (int i = 0; i < targets.length; i++) {
      if (qty[i] <= 0) continue;
      final s = targets[i];
      final unit = predictUnitPrice(s, orderQty: qty[i]);
      final days = predictDeliveryDays(s);
      final cost = qty[i] * unit;
      final pct = req.quantity > 0 ? (qty[i] / req.quantity) * 100.0 : 0.0;
      final mlRisk = predictOverallRisk(s);

      totalCost += cost;
      riskAcc += (qty[i] / max(1, req.quantity)) * mlRisk;
      maxDays = max(maxDays, days);

      allocations.add(AllocationItem(
        supplierName: s.name,
        quantity: qty[i],
        percentage: double.parse(pct.toStringAsFixed(1)),
        cost: cost,
        deliveryDays: days,
        rationale:
            'RF score rank share. ML risk ${mlRisk.toStringAsFixed(1)}/100. Weight cost=$costW risk=$riskW.',
      ));
    }

    final warnings = <String>[];
    if (remaining > 0) {
      warnings.add('Shortfall of $remaining units — insufficient total capacity.');
      riskAcc = min(100, riskAcc + 20);
    }
    if (maxDays > req.maxDays) {
      warnings.add('Full delivery exceeds deadline (${req.maxDays}d).');
    }
    if (totalCost > req.maxBudget) {
      warnings.add('Exceeds max budget ₹${req.maxBudget.toStringAsFixed(0)}.');
    }

    return AIStrategyResult(
      title: name,
      reasoning: '',
      totalCost: totalCost,
      totalRiskScore: riskAcc.round().clamp(0, 100),
      estimatedDays: maxDays,
      allocations: allocations,
      insights: const [
        'Allocation computed by deterministic RF-style engine.',
      ],
      warnings: warnings,
      isBaseline: isBaseline,
    );
  }
}

// ============================================================
// GEMINI = EXPLAINER ONLY
// ============================================================
class GeminiService {
  static Future<String> explainStrategy({
    required ProcurementRequest req,
    required StrategyBundle bundle,
  }) async {
    if (GEMINI_API_KEY.contains('YOUR_GEMINI')) {
      // Offline fallback explanation (still deterministic numbers)
      final b = bundle.balanced;
      final splits = b.allocations
          .map((a) => '${a.supplierName} ${a.percentage.toStringAsFixed(0)}%')
          .join(', ');
      return 'The RF deterministic engine recommends Balanced because it diversifies '
          'order as $splits, keeping cost at ₹${b.totalCost.toStringAsFixed(0)} and risk at '
          '${b.totalRiskScore}/100 versus cheapest risk ${bundle.cheapest.totalRiskScore}/100 '
          'and safest cost ₹${bundle.safest.totalCost.toStringAsFixed(0)}. Gemini is only narrating fixed engine output.';
    }

    final model = GenerativeModel(model: 'gemini-3.6-flash', apiKey: GEMINI_API_KEY);

    String fmt(AIStrategyResult s) => s.allocations
        .map((a) =>
            '${a.supplierName}: ${a.percentage.toStringAsFixed(1)}% (${a.quantity} u, ₹${a.cost.toStringAsFixed(0)}, ${a.deliveryDays}d)')
        .join(' | ');

    final prompt = '''
You are a procurement analyst. You do NOT choose suppliers or percentages.
A DETERMINISTIC Random-Forest-style engine already fixed all numbers. Only explain them.

USER REQUEST:
- Qty: ${req.quantity}
- Max days: ${req.maxDays}
- Budget: ₹${req.maxBudget}
- Priority: ${req.priority}
- Notes: ${req.notes}

ENGINE OUTPUT (DO NOT CHANGE):
CHEAPEST/BASELINE: cost=₹${bundle.cheapest.totalCost.toStringAsFixed(0)}, risk=${bundle.cheapest.totalRiskScore}, days=${bundle.cheapest.estimatedDays}
Split: ${fmt(bundle.cheapest)}

SAFEST: cost=₹${bundle.safest.totalCost.toStringAsFixed(0)}, risk=${bundle.safest.totalRiskScore}, days=${bundle.safest.estimatedDays}
Split: ${fmt(bundle.safest)}

BALANCED (RECOMMENDED): cost=₹${bundle.balanced.totalCost.toStringAsFixed(0)}, risk=${bundle.balanced.totalRiskScore}, days=${bundle.balanced.estimatedDays}
Split: ${fmt(bundle.balanced)}

Write 4-6 plain business sentences:
- Why Balanced % split is recommended
- Exact cost/risk tradeoff using numbers above
- How multi-supplier % reduces dependency
No JSON, no markdown, no new percentages.
''';

    final response = await model.generateContent([Content.text(prompt)]);
    return response.text?.trim() ??
        'Balanced allocation is recommended as the deterministic tradeoff between cost and risk.';
  }
}

// ============================================================
// FIRESTORE SERVICE
// ============================================================
class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference get suppliers => _db.collection('suppliers');
  static CollectionReference get history => _db.collection('history');
  static CollectionReference get strategies => _db.collection('strategies');

  static Future<void> addSupplier(Supplier s) => suppliers.add(s.toJson());
  static Future<void> updateSupplier(String id, Map<String, dynamic> data) =>
      suppliers.doc(id).update(data);
  static Future<void> deleteSupplier(String id) => suppliers.doc(id).delete();
  static Future<void> addHistory(HistoryEvent e) => history.add(e.toJson());
  static Future<void> saveStrategy(Map<String, dynamic> data) => strategies.add({
        ...data,
        'time': Timestamp.now(),
        'userId': AuthService.currentUser?.uid ?? '',
        'userEmail': AuthService.currentUser?.email ?? '',
        'engine': 'random_forest_deterministic',
        'llm_role': 'explanation_only',
      });

  static Future<void> seedIfEmpty() async {
    final snap = await suppliers.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final mocks = [
      Supplier(
        id: '',
        name: 'FastExpress Ltd',
        category: 'Electronics',
        price: 150,
        deliveryDays: 1,
        capacity: 2000,
        minOrder: 100,
        reliability: 0.98,
        qualityScore: 0.95,
        priceRisk: 0.10,
        deliveryRisk: 0.05,
        qualityRisk: 0.08,
        capacityRisk: 0.35,
        currentStock: 1500,
        location: 'Mumbai, IN',
      ),
      Supplier(
        id: '',
        name: 'GlobalCorp Industries',
        category: 'Electronics',
        price: 80,
        deliveryDays: 12,
        capacity: 15000,
        minOrder: 500,
        reliability: 0.85,
        qualityScore: 0.82,
        priceRisk: 0.15,
        deliveryRisk: 0.55,
        qualityRisk: 0.20,
        capacityRisk: 0.10,
        currentStock: 12000,
        location: 'Shenzhen, CN',
      ),
      Supplier(
        id: '',
        name: 'MidTier Suppliers',
        category: 'Electronics',
        price: 110,
        deliveryDays: 4,
        capacity: 6000,
        minOrder: 200,
        reliability: 0.91,
        qualityScore: 0.88,
        priceRisk: 0.25,
        deliveryRisk: 0.20,
        qualityRisk: 0.15,
        capacityRisk: 0.20,
        currentStock: 4500,
        location: 'Delhi, IN',
      ),
      Supplier(
        id: '',
        name: 'EuroTech Manufacturing',
        category: 'Electronics',
        price: 175,
        deliveryDays: 7,
        capacity: 3500,
        minOrder: 150,
        reliability: 0.96,
        qualityScore: 0.98,
        priceRisk: 0.20,
        deliveryRisk: 0.15,
        qualityRisk: 0.05,
        capacityRisk: 0.25,
        currentStock: 2800,
        location: 'Berlin, DE',
      ),
      Supplier(
        id: '',
        name: 'BudgetBulk Traders',
        category: 'Electronics',
        price: 65,
        deliveryDays: 15,
        capacity: 20000,
        minOrder: 1000,
        reliability: 0.72,
        qualityScore: 0.70,
        priceRisk: 0.45,
        deliveryRisk: 0.65,
        qualityRisk: 0.40,
        capacityRisk: 0.08,
        currentStock: 18000,
        location: 'Guangzhou, CN',
      ),
    ];

    for (final m in mocks) {
      await suppliers.add(m.toJson());
    }
    await addHistory(HistoryEvent(
      id: '',
      title: '🚀 System Initialized',
      subtitle: 'Seeded ${mocks.length} suppliers + RF engine ready',
      type: 'system',
    ));
  }
}

// ============================================================
// ROOT APP
// ============================================================
class ProcureAIApp extends StatelessWidget {
  const ProcureAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProcurementPilot AI',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: StreamBuilder<User?>(
        stream: AuthService.authState,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SplashScreen(text: 'Checking authentication...');
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const MainShell();
          }
          return const LoginScreen();
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      cardColor: AppColors.card,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.textDim.withOpacity(0.15)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.textDim.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.textDim.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        labelStyle: const TextStyle(color: AppColors.textDim),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  final String text;
  const _SplashScreen({this.text = 'Loading...'});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology, color: AppColors.primary, size: 64),
            const SizedBox(height: 20),
            const Text('ProcurementPilot',
                style: TextStyle(color: AppColors.textBright, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(color: AppColors.textDim)),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOGIN
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;
  String? errorMsg;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      final cred = await AuthService.signInWithGoogle();
      if (cred == null) setState(() => isLoading = false);
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMsg = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 2),
                  ),
                  child: const Icon(Icons.psychology, color: AppColors.primary, size: 56),
                ),
                const SizedBox(height: 28),
                const Text('ProcurementPilot',
                    style: TextStyle(color: AppColors.textBright, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: const Text('RF ENGINE + GEMINI EXPLAINER',
                      style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Deterministic ML allocations\nGemini only explains the fixed plan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textDim, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isLoading ? null : _handleGoogleSignIn,
                    child: isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          ),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 20),
                  Text(errorMsg!, style: const TextStyle(color: AppColors.danger, fontSize: 12), textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MAIN SHELL
// ============================================================
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  List<Supplier> suppliers = [];
  List<HistoryEvent> history = [];
  AIStrategyResult? lastAI;
  AIStrategyResult? lastBaseline;
  StrategyBundle? lastBundle;
  ProcurementRequest currentRequest = ProcurementRequest();
  bool isLoading = true;
  int navIndex = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await FirestoreService.seedIfEmpty();
    FirestoreService.suppliers.snapshots().listen((snap) {
      setState(() {
        suppliers = snap.docs
            .map((d) => Supplier.fromJson(d.id, d.data() as Map<String, dynamic>))
            .toList();
        isLoading = false;
      });
    });
    FirestoreService.history.orderBy('time', descending: true).limit(50).snapshots().listen((snap) {
      setState(() {
        history = snap.docs
            .map((d) => HistoryEvent.fromJson(d.id, d.data() as Map<String, dynamic>))
            .toList();
      });
    });
    await FirestoreService.addHistory(HistoryEvent(
      id: '',
      title: '🔐 User Signed In',
      subtitle: AuthService.currentUser?.email,
      type: 'system',
    ));
  }

  void _onStrategy(AIStrategyResult ai, AIStrategyResult baseline, StrategyBundle bundle) {
    setState(() {
      lastAI = ai;
      lastBaseline = baseline;
      lastBundle = bundle;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _SplashScreen(text: 'Loading suppliers + RF engine...');
    final user = AuthService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.psychology, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('ProcurementPilot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: const Text('RF + GEMINI',
                  style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? Text((user?.displayName ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                  : null,
            ),
            color: AppColors.card,
            onSelected: (v) async {
              if (v == 'signout') await AuthService.signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.displayName ?? 'User',
                        style: const TextStyle(color: AppColors.textBright, fontWeight: FontWeight.bold)),
                    Text(user?.email ?? '', style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.danger, size: 18),
                    SizedBox(width: 10),
                    Text('Sign Out', style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: navIndex,
        children: [
          DashboardScreen(
            suppliers: suppliers,
            lastAI: lastAI,
            lastBaseline: lastBaseline,
            lastBundle: lastBundle,
            history: history,
          ),
          AgentScreen(
            suppliers: suppliers,
            request: currentRequest,
            onStrategyGenerated: _onStrategy,
          ),
          SuppliersScreen(suppliers: suppliers),
          RiskMatrixScreen(suppliers: suppliers),
          SimulatorScreen(suppliers: suppliers),
          HistoryScreen(history: history),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withOpacity(0.2),
        onDestinationSelected: (i) => setState(() => navIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.psychology_rounded), label: 'AI Agent'),
          NavigationDestination(icon: Icon(Icons.factory_rounded), label: 'Suppliers'),
          NavigationDestination(icon: Icon(Icons.security_rounded), label: 'Risk'),
          NavigationDestination(icon: Icon(Icons.bolt_rounded), label: 'Simulate'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'History'),
        ],
      ),
    );
  }
}

// ============================================================
// SHARED UI
// ============================================================
class GlowCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final EdgeInsets? padding;
  const GlowCard({super.key, required this.child, this.borderColor, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (borderColor ?? AppColors.textDim).withOpacity(0.25)),
        boxShadow: borderColor != null
            ? [BoxShadow(color: borderColor!.withOpacity(0.1), blurRadius: 20)]
            : null,
      ),
      child: child,
    );
  }
}

Color riskColor(double r) {
  if (r < 0.3) return AppColors.primary;
  if (r < 0.6) return AppColors.warning;
  return AppColors.danger;
}

String riskLabel(double r) {
  if (r < 0.3) return 'LOW';
  if (r < 0.6) return 'MED';
  return 'HIGH';
}

String fmt(num n) => NumberFormat('#,##0').format(n);

// ============================================================
// 1. DASHBOARD
// ============================================================
class DashboardScreen extends StatelessWidget {
  final List<Supplier> suppliers;
  final AIStrategyResult? lastAI;
  final AIStrategyResult? lastBaseline;
  final StrategyBundle? lastBundle;
  final List<HistoryEvent> history;

  const DashboardScreen({
    super.key,
    required this.suppliers,
    this.lastAI,
    this.lastBaseline,
    this.lastBundle,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final avgRisk = suppliers.isEmpty
        ? 0.0
        : suppliers.map((s) => RandomForestMLBackend.predictOverallRisk(s)).reduce((a, b) => a + b) /
            suppliers.length;
    final totalCapacity = suppliers.fold<int>(0, (a, s) => a + s.capacity);
    final totalStock = suppliers.fold<int>(0, (a, s) => a + s.currentStock);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Welcome, ${AuthService.currentUser?.displayName?.split(' ').first ?? 'User'} 👋',
          style: const TextStyle(color: AppColors.textBright, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text('RF deterministic engine + Gemini explanation layer',
            style: TextStyle(color: AppColors.textDim, fontSize: 13)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _stat('Suppliers', '${suppliers.length}', Icons.factory, AppColors.primary)),
          const SizedBox(width: 10),
          Expanded(child: _stat('Capacity', fmt(totalCapacity), Icons.warehouse, AppColors.secondary)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _stat('In-Stock', fmt(totalStock), Icons.inventory_2, AppColors.warning)),
          const SizedBox(width: 10),
          Expanded(child: _stat('Avg ML Risk', '${avgRisk.toStringAsFixed(0)}%', Icons.security, riskColor(avgRisk / 100))),
        ]),
        const SizedBox(height: 20),
        if (lastAI != null && lastBaseline != null) _comparisonCard(),
        if (lastAI == null) _emptyCard(),
        if (lastBundle != null) ...[
          const SizedBox(height: 16),
          _threeStrategyMini(lastBundle!),
        ],
        const SizedBox(height: 20),
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Supplier ML Risk Distribution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBright)),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: suppliers.isEmpty
                    ? const Center(child: Text('No data', style: TextStyle(color: AppColors.textDim)))
                    : BarChart(
                        BarChartData(
                          maxY: 100,
                          alignment: BarChartAlignment.spaceAround,
                          barTouchData: BarTouchData(enabled: true),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) {
                                  if (v.toInt() >= suppliers.length) return const SizedBox();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(suppliers[v.toInt()].name.split(' ').first,
                                        style: const TextStyle(fontSize: 9, color: AppColors.textDim)),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: false),
                          barGroups: suppliers.asMap().entries.map((e) {
                            final r = RandomForestMLBackend.predictOverallRisk(e.value);
                            return BarChartGroupData(x: e.key, barRods: [
                              BarChartRodData(
                                toY: r,
                                color: riskColor(r / 100),
                                width: 22,
                                borderRadius: BorderRadius.circular(4),
                              )
                            ]);
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent Agent Activity',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBright)),
              const SizedBox(height: 12),
              if (history.isEmpty)
                const Text('No activity yet', style: TextStyle(color: AppColors.textDim))
              else
                ...history.take(5).map(_historyMini),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return GlowCard(
      borderColor: color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 12))),
          ]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _comparisonCard() {
    final costSaved = lastBaseline!.totalCost - lastAI!.totalCost;
    final savePct = lastBaseline!.totalCost > 0 ? (costSaved / lastBaseline!.totalCost * 100) : 0.0;
    final riskDiff = lastBaseline!.totalRiskScore - lastAI!.totalRiskScore;
    return GlowCard(
      borderColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.compare_arrows, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('RF Balanced vs Baseline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBright)),
            ),
            Text('${savePct.toStringAsFixed(1)}%',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _mini('Baseline', '₹${fmt(lastBaseline!.totalCost)}', 'Risk ${lastBaseline!.totalRiskScore}%', AppColors.textDim)),
            const Icon(Icons.arrow_forward, color: AppColors.primary),
            Expanded(child: _mini('RF Balanced', '₹${fmt(lastAI!.totalCost)}', 'Risk ${lastAI!.totalRiskScore}%', AppColors.primary)),
          ]),
          const SizedBox(height: 10),
          Text('Risk change: ${riskDiff >= 0 ? '-' : '+'}${riskDiff.abs()} pts  •  Engine fixed % splits',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: lastAI!.allocations
                .map((a) => Chip(
                      label: Text('${a.supplierName.split(' ').first} ${a.percentage.toStringAsFixed(0)}%'),
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      labelStyle: const TextStyle(color: AppColors.primary, fontSize: 12),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _mini(String l, String v, String s, Color c) => Column(
        children: [
          Text(l, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          Text(v, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(s, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        ],
      );

  Widget _threeStrategyMini(StrategyBundle b) {
    Widget card(String t, AIStrategyResult s, Color c) => Expanded(
          child: GlowCard(
            borderColor: c,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('₹${fmt(s.totalCost)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Risk ${s.totalRiskScore}%', style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
              ],
            ),
          ),
        );
    return Row(children: [
      card('Cheapest', b.cheapest, AppColors.warning),
      const SizedBox(width: 8),
      card('Safest', b.safest, AppColors.secondary),
      const SizedBox(width: 8),
      card('Balanced', b.balanced, AppColors.primary),
    ]);
  }

  Widget _emptyCard() => GlowCard(
        borderColor: AppColors.secondary,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ready to plan procurement?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBright)),
            SizedBox(height: 8),
            Text('Open AI Agent → RF engine computes % splits → Gemini explains.',
                style: TextStyle(color: AppColors.textDim, fontSize: 13)),
          ],
        ),
      );

  Widget _historyMini(HistoryEvent h) {
    Color c = AppColors.textDim;
    IconData icon = Icons.info;
    if (h.type == 'ai') {
      c = AppColors.primary;
      icon = Icons.psychology;
    } else if (h.type == 'disruption') {
      c = AppColors.danger;
      icon = Icons.warning_amber;
    } else if (h.type == 'manual') {
      c = AppColors.secondary;
      icon = Icons.edit;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: c, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.title, style: const TextStyle(color: AppColors.textBright, fontSize: 13, fontWeight: FontWeight.w500)),
                if (h.subtitle != null)
                  Text(h.subtitle!, style: const TextStyle(color: AppColors.textDim, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(DateFormat('HH:mm').format(h.time), style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        ],
      ),
    );
  }
}

// ============================================================
// 2. AGENT SCREEN
// ============================================================
class AgentScreen extends StatefulWidget {
  final List<Supplier> suppliers;
  final ProcurementRequest request;
  final void Function(AIStrategyResult ai, AIStrategyResult baseline, StrategyBundle bundle) onStrategyGenerated;

  const AgentScreen({
    super.key,
    required this.suppliers,
    required this.request,
    required this.onStrategyGenerated,
  });

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  late TextEditingController qtyCtrl;
  late TextEditingController daysCtrl;
  late TextEditingController budgetCtrl;
  late TextEditingController notesCtrl;
  String priority = 'balanced';
  bool isThinking = false;
  String thinkingText = '';
  AIStrategyResult? aiResult;
  AIStrategyResult? baselineResult;
  StrategyBundle? bundle;

  @override
  void initState() {
    super.initState();
    qtyCtrl = TextEditingController(text: widget.request.quantity.toString());
    daysCtrl = TextEditingController(text: widget.request.maxDays.toString());
    budgetCtrl = TextEditingController(text: widget.request.maxBudget.toString());
    notesCtrl = TextEditingController(
        text: 'Need 300 units urgently for production. Remaining can arrive later. Prefer diversified suppliers.');
  }

  Future<void> _generate() async {
    if (widget.suppliers.isEmpty) {
      _snack('Add suppliers first');
      return;
    }

    widget.request.quantity = int.tryParse(qtyCtrl.text) ?? 1000;
    widget.request.maxDays = int.tryParse(daysCtrl.text) ?? 7;
    widget.request.maxBudget = double.tryParse(budgetCtrl.text) ?? 200000;
    widget.request.priority = priority;
    widget.request.notes = notesCtrl.text;

    setState(() {
      isThinking = true;
      aiResult = null;
      baselineResult = null;
      bundle = null;
      thinkingText = 'Running Random Forest risk models...';
    });

    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => thinkingText = 'Deterministic allocation engine computing % splits...');

    try {
      // 1) DETERMINISTIC RF ENGINE (numbers / %)
      final b = RandomForestMLBackend.generateAll(widget.suppliers, widget.request);

      setState(() => thinkingText = 'Gemini explaining fixed strategy (no decisions)...');

      // 2) LLM EXPLAINS ONLY
      final explanation = await GeminiService.explainStrategy(req: widget.request, bundle: b);

      final recommended = AIStrategyResult(
        title: b.balanced.title,
        reasoning: explanation,
        totalCost: b.balanced.totalCost,
        totalRiskScore: b.balanced.totalRiskScore,
        estimatedDays: b.balanced.estimatedDays,
        allocations: b.balanced.allocations,
        insights: b.balanced.insights,
        warnings: b.balanced.warnings,
      );

      setState(() {
        bundle = b;
        aiResult = recommended;
        baselineResult = b.baseline;
        isThinking = false;
      });

      widget.onStrategyGenerated(recommended, b.baseline, b);

      final splitText = recommended.allocations
          .map((a) => '${a.supplierName.split(' ').first} ${a.percentage.toStringAsFixed(0)}%')
          .join(', ');

      await FirestoreService.addHistory(HistoryEvent(
        id: '',
        title: '📐 RF Strategy + Gemini Explain',
        subtitle: '${widget.request.quantity} u • ₹${fmt(recommended.totalCost)} • $splitText',
        type: 'ai',
      ));

      await FirestoreService.saveStrategy({
        'title': recommended.title,
        'totalCost': recommended.totalCost,
        'risk': recommended.totalRiskScore,
        'quantity': widget.request.quantity,
        'reasoning': recommended.reasoning,
        'splits': recommended.allocations
            .map((a) => {
                  'supplier': a.supplierName,
                  'pct': a.percentage,
                  'qty': a.quantity,
                })
            .toList(),
      });
    } catch (e) {
      setState(() => isThinking = false);
      _snack('Error: $e');
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.card));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.psychology, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RF Allocation Agent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBright)),
                Text('Engine decides %  •  Gemini only explains', style: TextStyle(fontSize: 12, color: AppColors.textDim)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 20),
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PROCUREMENT REQUEST',
                  style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _input('Units Needed', qtyCtrl, Icons.inventory)),
                const SizedBox(width: 10),
                Expanded(child: _input('Max Days', daysCtrl, Icons.schedule)),
              ]),
              const SizedBox(height: 12),
              _input('Max Budget (₹)', budgetCtrl, Icons.currency_rupee),
              const SizedBox(height: 14),
              const Text('Priority', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                _chip('balanced', 'Balanced', Icons.balance),
                _chip('cost', 'Save Cost', Icons.savings),
                _chip('speed', 'Fast Delivery', Icons.rocket),
                _chip('quality', 'High Quality', Icons.verified),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textBright),
                decoration: const InputDecoration(
                  labelText: 'Business notes (for Gemini explanation context)',
                  prefixIcon: Icon(Icons.edit_note, color: AppColors.textDim),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isThinking ? null : _generate,
                  icon: isThinking
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    isThinking ? thinkingText : 'RUN RF ENGINE + GEMINI EXPLAIN',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (aiResult != null && baselineResult != null && bundle != null) _results(aiResult!, baselineResult!, bundle!),
      ],
    );
  }

  Widget _input(String label, TextEditingController c, IconData icon) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.textBright),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: AppColors.textDim, size: 20)),
    );
  }

  Widget _chip(String val, String label, IconData icon) {
    final selected = priority == val;
    return GestureDetector(
      onTap: () => setState(() => priority = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
          border: Border.all(color: selected ? AppColors.primary : AppColors.textDim.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? AppColors.primary : AppColors.textDim),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textDim,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _results(AIStrategyResult ai, AIStrategyResult base, StrategyBundle b) {
    final saved = base.totalCost - ai.totalCost;
    return Column(
      children: [
        GlowCard(
          borderColor: AppColors.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.verified, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(ai.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBright)),
                ),
              ]),
              const SizedBox(height: 6),
              const Text('Allocations: Deterministic RF Engine  •  Narrative: Gemini',
                  style: TextStyle(color: AppColors.textDim, fontSize: 11)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _metric('Cost', '₹${fmt(ai.totalCost)}', AppColors.primary)),
                Expanded(child: _metric('Days', '${ai.estimatedDays}d', AppColors.secondary)),
                Expanded(child: _metric('Risk', '${ai.totalRiskScore}%', riskColor(ai.totalRiskScore / 100))),
              ]),
              const SizedBox(height: 16),
              const Divider(color: AppColors.textDim),
              const SizedBox(height: 12),
              const Text('ORDER ALLOCATION % SPLIT',
                  style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 10),
              ...ai.allocations.map(_allocTile),
              const SizedBox(height: 16),
              const Text('GEMINI EXPLANATION (non-decision)',
                  style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text(ai.reasoning, style: const TextStyle(color: AppColors.textBright, height: 1.5)),
              if (ai.insights.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...ai.insights.map((i) => _bullet(i, Icons.lightbulb, AppColors.secondary)),
              ],
              if (ai.warnings.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...ai.warnings.map((w) => _bullet(w, Icons.warning_amber, AppColors.warning)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ALL 3 DETERMINISTIC STRATEGIES',
                  style: TextStyle(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              _strategyMiniCard(b.cheapest, AppColors.warning),
              const SizedBox(height: 8),
              _strategyMiniCard(b.safest, AppColors.secondary),
              const SizedBox(height: 8),
              _strategyMiniCard(b.balanced, AppColors.primary),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (saved >= 0 ? AppColors.primary : AppColors.danger).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  saved >= 0
                      ? 'Balanced saves ₹${fmt(saved.abs())} vs pure cheapest-risk profile tradeoff baseline comparison.'
                      : 'Balanced costs ₹${fmt(saved.abs())} more than cheapest but reduces risk significantly.',
                  style: TextStyle(
                    color: saved >= 0 ? AppColors.primary : AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _strategyMiniCard(AIStrategyResult s, Color c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.title, style: TextStyle(color: c, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('₹${fmt(s.totalCost)}  •  Risk ${s.totalRiskScore}%  •  ${s.estimatedDays}d',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            s.allocations.map((a) => '${a.supplierName.split(' ').first} ${a.percentage.toStringAsFixed(0)}%').join('  |  '),
            style: const TextStyle(color: AppColors.textBright, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _metric(String l, String v, Color c) => Column(children: [
        Text(l, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        const SizedBox(height: 4),
        Text(v, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.bold)),
      ]);

  Widget _allocTile(AllocationItem a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(a.supplierName,
                  style: const TextStyle(color: AppColors.textBright, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
              child: Text('${a.percentage.toStringAsFixed(0)}% SHARE',
                  style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('${a.deliveryDays}d',
                  style: const TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${fmt(a.quantity)} units  •  ₹${fmt(a.cost)}',
              style: const TextStyle(color: AppColors.textBright, fontSize: 13)),
          const SizedBox(height: 4),
          Text(a.rationale, style: const TextStyle(color: AppColors.textDim, fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _bullet(String t, IconData i, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, color: c, size: 14),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: const TextStyle(color: AppColors.textBright, fontSize: 13))),
        ]),
      );
}

// ============================================================
// 3. SUPPLIERS CRUD
// ============================================================
class SuppliersScreen extends StatelessWidget {
  final List<Supplier> suppliers;
  const SuppliersScreen({super.key, required this.suppliers});

  void _showEditor(BuildContext context, {Supplier? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SupplierEditorSheet(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Add Supplier', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Icon(Icons.factory, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Supplier Database',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBright)),
            const Spacer(),
            Text('${suppliers.length} ACTIVE',
                style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          ...suppliers.map((s) => _card(context, s)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Supplier s) {
    final ml = RandomForestMLBackend.predictOverallRisk(s);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlowCard(
        borderColor: riskColor(ml / 100).withOpacity(0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: riskColor(ml / 100).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.factory, color: riskColor(ml / 100)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, style: const TextStyle(color: AppColors.textBright, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${s.location}  •  ${s.category}', style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                ]),
              ),
              Column(children: [
                Text('ML ${ml.toStringAsFixed(0)}', style: TextStyle(color: riskColor(ml / 100), fontWeight: FontWeight.bold)),
                Text(riskLabel(ml / 100), style: TextStyle(color: riskColor(ml / 100), fontSize: 10)),
              ]),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _ms('Price', '₹${fmt(s.price)}'),
              _ms('Days', '${s.deliveryDays}d'),
              _ms('Stock', fmt(s.currentStock)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _ms('Cap', fmt(s.capacity)),
              _ms('Rel', '${(s.reliability * 100).toInt()}%'),
              _ms('Qty', '${(s.qualityScore * 100).toInt()}%'),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditor(context, existing: s),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () async {
                    await FirestoreService.deleteSupplier(s.id);
                    await FirestoreService.addHistory(HistoryEvent(
                      id: '',
                      title: '🗑️ Supplier Removed',
                      subtitle: s.name,
                      type: 'manual',
                    ));
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _ms(String l, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          Text(v, style: const TextStyle(color: AppColors.textBright, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}

class SupplierEditorSheet extends StatefulWidget {
  final Supplier? existing;
  const SupplierEditorSheet({super.key, this.existing});
  @override
  State<SupplierEditorSheet> createState() => _SupplierEditorSheetState();
}

class _SupplierEditorSheetState extends State<SupplierEditorSheet> {
  late TextEditingController nameC, catC, priceC, daysC, capC, minC, stockC, locC;
  double reliability = 0.9, quality = 0.9;
  double priceRisk = 0.3, delRisk = 0.3, qRisk = 0.3, capRisk = 0.3;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    nameC = TextEditingController(text: e?.name ?? '');
    catC = TextEditingController(text: e?.category ?? 'Electronics');
    priceC = TextEditingController(text: e?.price.toString() ?? '100');
    daysC = TextEditingController(text: e?.deliveryDays.toString() ?? '5');
    capC = TextEditingController(text: e?.capacity.toString() ?? '5000');
    minC = TextEditingController(text: e?.minOrder.toString() ?? '100');
    stockC = TextEditingController(text: e?.currentStock.toString() ?? '1000');
    locC = TextEditingController(text: e?.location ?? 'Delhi, IN');
    if (e != null) {
      reliability = e.reliability;
      quality = e.qualityScore;
      priceRisk = e.priceRisk;
      delRisk = e.deliveryRisk;
      qRisk = e.qualityRisk;
      capRisk = e.capacityRisk;
    }
  }

  Future<void> _save() async {
    if (nameC.text.trim().isEmpty) return;
    final s = Supplier(
      id: widget.existing?.id ?? '',
      name: nameC.text.trim(),
      category: catC.text.trim(),
      price: double.tryParse(priceC.text) ?? 100,
      deliveryDays: int.tryParse(daysC.text) ?? 5,
      capacity: int.tryParse(capC.text) ?? 1000,
      minOrder: int.tryParse(minC.text) ?? 100,
      currentStock: int.tryParse(stockC.text) ?? 500,
      reliability: reliability,
      qualityScore: quality,
      priceRisk: priceRisk,
      deliveryRisk: delRisk,
      qualityRisk: qRisk,
      capacityRisk: capRisk,
      location: locC.text.trim(),
    );
    if (widget.existing == null) {
      await FirestoreService.addSupplier(s);
      await FirestoreService.addHistory(HistoryEvent(id: '', title: '➕ Supplier Added', subtitle: s.name, type: 'manual'));
    } else {
      await FirestoreService.updateSupplier(s.id, s.toJson());
      await FirestoreService.addHistory(HistoryEvent(id: '', title: '✏️ Supplier Updated', subtitle: s.name, type: 'manual'));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.existing == null ? 'Add Supplier' : 'Edit Supplier',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: catC, decoration: const InputDecoration(labelText: 'Category')),
            const SizedBox(height: 10),
            TextField(controller: locC, decoration: const InputDecoration(labelText: 'Location')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: daysC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Days'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: capC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: minC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Order'))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: stockC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock')),
            const SizedBox(height: 16),
            _sl('Reliability', reliability, (v) => setState(() => reliability = v)),
            _sl('Quality', quality, (v) => setState(() => quality = v)),
            _sl('Price Risk', priceRisk, (v) => setState(() => priceRisk = v), risk: true),
            _sl('Delivery Risk', delRisk, (v) => setState(() => delRisk = v), risk: true),
            _sl('Quality Risk', qRisk, (v) => setState(() => qRisk = v), risk: true),
            _sl('Capacity Risk', capRisk, (v) => setState(() => capRisk = v), risk: true),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
              onPressed: _save,
              child: const Text('SAVE TO DATABASE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sl(String l, double v, ValueChanged<double> on, {bool risk = false}) {
    final c = risk ? riskColor(v) : AppColors.primary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(l, style: const TextStyle(color: AppColors.textBright, fontSize: 13)),
        const Spacer(),
        Text('${(v * 100).toStringAsFixed(0)}%', style: TextStyle(color: c, fontWeight: FontWeight.bold)),
      ]),
      Slider(value: v, min: 0, max: 1, activeColor: c, onChanged: on),
    ]);
  }
}

// ============================================================
// 4. RISK MATRIX
// ============================================================
class RiskMatrixScreen extends StatelessWidget {
  final List<Supplier> suppliers;
  const RiskMatrixScreen({super.key, required this.suppliers});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('ML Risk Matrix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBright)),
        const SizedBox(height: 8),
        const Text('Scores from Random-Forest-style deterministic model', style: TextStyle(color: AppColors.textDim, fontSize: 13)),
        const SizedBox(height: 16),
        ...suppliers.map((s) {
          final ml = RandomForestMLBackend.predictOverallRisk(s);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: GlowCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textBright))),
                  Text('ML ${ml.toStringAsFixed(0)}/100', style: TextStyle(color: riskColor(ml / 100), fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 12),
                _bar('Price Risk', s.priceRisk),
                _bar('Delivery Risk', s.deliveryRisk),
                _bar('Quality Risk', s.qualityRisk),
                _bar('Capacity Risk', s.capacityRisk),
                _bar('Unreliability', 1 - s.reliability),
              ]),
            ),
          );
        }),
      ],
    );
  }

  Widget _bar(String l, double v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(l, style: const TextStyle(color: AppColors.textBright, fontSize: 12)),
            const Spacer(),
            Text('${(v * 100).toInt()}%', style: TextStyle(color: riskColor(v), fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: AppColors.surface, color: riskColor(v)),
          ),
        ]),
      );
}

// ============================================================
// 5. SIMULATOR
// ============================================================
class SimulatorScreen extends StatefulWidget {
  final List<Supplier> suppliers;
  const SimulatorScreen({super.key, required this.suppliers});
  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  String? targetId;
  String disruption = 'Price Spike';
  double magnitude = 30;
  bool applied = false;

  final disruptions = const ['Price Spike', 'Capacity Drop', 'Delivery Delay', 'Reliability Crash', 'Quality Issue'];

  Future<void> _apply() async {
    if (targetId == null) return;
    final s = widget.suppliers.firstWhere((x) => x.id == targetId);
    final f = magnitude / 100;
    final update = <String, dynamic>{};
    var desc = '';

    switch (disruption) {
      case 'Price Spike':
        update['price'] = s.price * (1 + f);
        update['priceRisk'] = min(1.0, s.priceRisk + f * 0.5);
        desc = 'Price +${magnitude.toInt()}%';
        break;
      case 'Capacity Drop':
        update['capacity'] = (s.capacity * (1 - f)).toInt();
        update['currentStock'] = (s.currentStock * (1 - f)).toInt();
        update['capacityRisk'] = min(1.0, s.capacityRisk + f * 0.5);
        desc = 'Capacity -${magnitude.toInt()}%';
        break;
      case 'Delivery Delay':
        update['deliveryDays'] = (s.deliveryDays * (1 + f)).ceil();
        update['deliveryRisk'] = min(1.0, s.deliveryRisk + f * 0.5);
        desc = 'Delivery delay +${magnitude.toInt()}%';
        break;
      case 'Reliability Crash':
        update['reliability'] = max(0.0, s.reliability - f);
        desc = 'Reliability -${magnitude.toInt()}%';
        break;
      case 'Quality Issue':
        update['qualityScore'] = max(0.0, s.qualityScore - f);
        update['qualityRisk'] = min(1.0, s.qualityRisk + f * 0.5);
        desc = 'Quality -${magnitude.toInt()}%';
        break;
    }

    await FirestoreService.updateSupplier(s.id, update);
    await FirestoreService.addHistory(HistoryEvent(
      id: '',
      title: '⚠️ Disruption: ${s.name}',
      subtitle: '$disruption — $desc',
      type: 'disruption',
    ));
    setState(() => applied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => applied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suppliers.isEmpty) {
      return const Center(child: Text('No suppliers', style: TextStyle(color: AppColors.textDim)));
    }
    targetId ??= widget.suppliers.first.id;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Disruption Simulator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBright)),
        const SizedBox(height: 8),
        const Text('Inject live Firestore changes → RF engine re-plans on next run', style: TextStyle(color: AppColors.textDim)),
        const SizedBox(height: 20),
        GlowCard(
          borderColor: AppColors.danger,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButtonFormField<String>(
              value: targetId,
              dropdownColor: AppColors.card,
              decoration: const InputDecoration(labelText: 'Target Supplier'),
              items: widget.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
              onChanged: (v) => setState(() => targetId = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: disruptions.map((d) {
                final sel = disruption == d;
                return ChoiceChip(
                  label: Text(d),
                  selected: sel,
                  onSelected: (_) => setState(() => disruption = d),
                  selectedColor: AppColors.danger.withOpacity(0.3),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text('Magnitude: ${magnitude.toInt()}%', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
            Slider(value: magnitude, min: 10, max: 80, divisions: 14, activeColor: AppColors.danger, onChanged: (v) => setState(() => magnitude = v)),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: applied ? AppColors.primary : AppColors.danger,
                  foregroundColor: Colors.black,
                ),
                onPressed: _apply,
                icon: Icon(applied ? Icons.check : Icons.warning),
                label: Text(applied ? 'APPLIED' : 'INJECT DISRUPTION', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ============================================================
// 6. HISTORY
// ============================================================
class HistoryScreen extends StatelessWidget {
  final List<HistoryEvent> history;
  const HistoryScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(child: Text('No activity yet', style: TextStyle(color: AppColors.textDim)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, i) {
        final h = history[i];
        Color c = AppColors.textDim;
        IconData icon = Icons.info;
        if (h.type == 'ai') {
          c = AppColors.primary;
          icon = Icons.psychology;
        } else if (h.type == 'disruption') {
          c = AppColors.danger;
          icon = Icons.warning_amber;
        } else if (h.type == 'manual') {
          c = AppColors.secondary;
          icon = Icons.edit;
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlowCard(
            borderColor: c.withOpacity(0.35),
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: c, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h.title, style: const TextStyle(color: AppColors.textBright, fontWeight: FontWeight.bold)),
                  if (h.subtitle != null) Text(h.subtitle!, style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(DateFormat('MMM d, HH:mm:ss').format(h.time),
                      style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}
