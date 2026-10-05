import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SupplierPortalApp());
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
// AUTH (same as buyer app)
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
          'name': userCred.user!.displayName ?? 'Supplier',
          'email': userCred.user!.email ?? '',
          'photoUrl': userCred.user!.photoURL ?? '',
          'role': 'supplier',
          'lastLogin': FieldValue.serverTimestamp(),
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
// MODEL (same 'suppliers' collection the buyer app reads)
// ============================================================
class Supplier {
  String id;
  String name;
  String product;
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
  String ownerUid;

  Supplier({
    required this.id,
    required this.name,
    required this.product,
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
    required this.ownerUid,
  });

  factory Supplier.fromJson(String id, Map<String, dynamic> j) => Supplier(
        id: id,
        name: j['name'] ?? 'Unknown',
        product: j['product'] ?? '',
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
        ownerUid: j['ownerUid'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'product': product,
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
        'ownerUid': ownerUid,
        'ownerEmail': AuthService.currentUser?.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

// Same risk formula as the buyer app's RF engine
double mlRisk(Supplier s) {
  final v = (1.0 - s.reliability) * 35 +
      (1.0 - s.qualityScore) * 20 +
      s.priceRisk * 15 +
      s.deliveryRisk * 15 +
      s.capacityRisk * 10;
  return v.clamp(5.0, 98.0);
}

// How the buyer's "Balanced" engine would score you (lower = better)
double buyerScore(Supplier s) {
  final days = s.deliveryDays + (1 - s.reliability) * 3;
  return s.price * 0.5 + mlRisk(s) * 0.35 + days * 8 * 0.15;
}

Color riskColor(double r) {
  if (r < 0.3) return AppColors.primary;
  if (r < 0.6) return AppColors.warning;
  return AppColors.danger;
}

String fmt(num n) => NumberFormat('#,##0').format(n);

// ============================================================
// ROOT
// ============================================================
class SupplierPortalApp extends StatelessWidget {
  const SupplierPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supplier Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
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
      ),
      home: StreamBuilder<User?>(
        stream: AuthService.authState,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _Splash(text: 'Checking authentication...');
          }
          if (snap.hasData && snap.data != null) return const PortalShell();
          return const LoginScreen();
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  final String text;
  const _Splash({this.text = 'Loading...'});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.storefront, color: AppColors.primary, size: 64),
          const SizedBox(height: 20),
          const Text('Supplier Portal',
              style: TextStyle(color: AppColors.textBright, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: AppColors.textDim)),
          const SizedBox(height: 30),
          const CircularProgressIndicator(color: AppColors.primary),
        ]),
      ),
    );
  }
}

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
        boxShadow: borderColor != null ? [BoxShadow(color: borderColor!.withOpacity(0.1), blurRadius: 20)] : null,
      ),
      child: child,
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
  bool loading = false;
  String? err;

  Future<void> _go() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final c = await AuthService.signInWithGoogle();
      if (c == null && mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.secondary.withOpacity(0.4), width: 2),
                ),
                child: const Icon(Icons.storefront, color: AppColors.secondary, size: 56),
              ),
              const SizedBox(height: 28),
              const Text('Supplier Portal',
                  style: TextStyle(color: AppColors.textBright, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.secondary.withOpacity(0.4)),
                ),
                child: const Text('FOR SUPPLIERS · PROCUREMENTPILOT',
                    style: TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              ),
              const SizedBox(height: 16),
              const Text(
                'List your materials, price & capacity.\nSee how you rank against competitors.',
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
                  onPressed: loading ? null : _go,
                  child: loading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ]),
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: 20),
                Text(err!, style: const TextStyle(color: AppColors.danger, fontSize: 12), textAlign: TextAlign.center),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SHELL
// ============================================================
class PortalShell extends StatefulWidget {
  const PortalShell({super.key});
  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  List<Supplier> all = [];
  bool loading = true;
  int nav = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance.collection('suppliers').snapshots().listen((snap) {
      if (!mounted) return;
      setState(() {
        all = snap.docs.map((d) => Supplier.fromJson(d.id, d.data())).toList();
        loading = false;
      });
    }, onError: (e) {
      if (mounted) setState(() => loading = false);
      debugPrint('Firestore error: $e');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Supplier? get mine {
    final uid = AuthService.currentUser?.uid;
    for (final s in all) {
      if (s.ownerUid == uid || s.id == uid) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Splash(text: 'Loading marketplace...');
    final user = AuthService.currentUser;
    final me = mine;
    final competitors = all.where((s) => me == null || s.id != me.id).toList();

    final pages = <Widget>[
      if (me != null) DashboardScreen(me: me, competitors: competitors),
      ProfileScreen(existing: me, key: ValueKey(me?.id ?? 'new')),
      if (me != null) CompetitorsScreen(me: me, competitors: competitors),
    ];
    final idx = me == null ? 0 : nav.clamp(0, pages.length - 1);
    // when onboarding, only profile page exists (index 0 -> profile)

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.storefront, color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Supplier Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.secondary.withOpacity(0.2),
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? Text((user?.displayName ?? 'S')[0].toUpperCase(),
                      style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold))
                  : null,
            ),
            color: AppColors.card,
            onSelected: (v) async {
              if (v == 'signout') await AuthService.signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.displayName ?? 'Supplier',
                      style: const TextStyle(color: AppColors.textBright, fontWeight: FontWeight.bold)),
                  Text(user?.email ?? '', style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'signout',
                child: Row(children: [
                  Icon(Icons.logout, color: AppColors.danger, size: 18),
                  SizedBox(width: 10),
                  Text('Sign Out', style: TextStyle(color: AppColors.danger)),
                ]),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: pages[me == null ? 0 : idx],
      bottomNavigationBar: me == null
          ? null
          : NavigationBar(
              selectedIndex: idx,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.secondary.withOpacity(0.2),
              onDestinationSelected: (i) => setState(() => nav = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                NavigationDestination(icon: Icon(Icons.edit_note_rounded), label: 'My Details'),
                NavigationDestination(icon: Icon(Icons.groups_rounded), label: 'Competitors'),
              ],
            ),
    );
  }
}

// ============================================================
// PROFILE / DETAILS FORM
// ============================================================
class ProfileScreen extends StatefulWidget {
  final Supplier? existing;
  const ProfileScreen({super.key, this.existing});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController nameC, productC, catC, locC, priceC, daysC, capC, minC, stockC;
  double reliability = 0.9, quality = 0.9;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    nameC = TextEditingController(text: e?.name ?? (AuthService.currentUser?.displayName ?? ''));
    productC = TextEditingController(text: e?.product ?? '');
    catC = TextEditingController(text: e?.category ?? 'Electronics');
    locC = TextEditingController(text: e?.location ?? '');
    priceC = TextEditingController(text: e?.price.toString() ?? '');
    daysC = TextEditingController(text: e?.deliveryDays.toString() ?? '');
    capC = TextEditingController(text: e?.capacity.toString() ?? '');
    minC = TextEditingController(text: e?.minOrder.toString() ?? '');
    stockC = TextEditingController(text: e?.currentStock.toString() ?? '');
    if (e != null) {
      reliability = e.reliability.clamp(0.5, 1.0);
      quality = e.qualityScore.clamp(0.5, 1.0);
    }
  }

  Future<void> _save() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    if (nameC.text.trim().isEmpty || priceC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company name and price are required'), backgroundColor: AppColors.card));
      return;
    }
    setState(() => saving = true);
    final days = int.tryParse(daysC.text) ?? 5;
    final cap = int.tryParse(capC.text) ?? 1000;
    final old = widget.existing;
    final s = Supplier(
      id: uid,
      name: nameC.text.trim(),
      product: productC.text.trim(),
      category: catC.text.trim().isEmpty ? 'General' : catC.text.trim(),
      price: double.tryParse(priceC.text) ?? 100,
      deliveryDays: days,
      capacity: cap,
      minOrder: int.tryParse(minC.text) ?? 100,
      currentStock: int.tryParse(stockC.text) ?? 0,
      reliability: reliability,
      qualityScore: quality,
      priceRisk: old?.priceRisk ?? 0.3,
      deliveryRisk: min(1.0, days / 20),
      qualityRisk: (1 - quality).clamp(0.0, 1.0),
      capacityRisk: cap < 2000 ? 0.35 : (cap < 8000 ? 0.2 : 0.1),
      location: locC.text.trim().isEmpty ? 'India' : locC.text.trim(),
      ownerUid: uid,
    );
    try {
      await FirebaseFirestore.instance.collection('suppliers').doc(uid).set(s.toJson(), SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('history').add({
        'title': old == null ? '🏭 New Supplier Joined' : '📝 Supplier Updated Details',
        'subtitle': '${s.name} · ${s.product} · ₹${fmt(s.price)}',
        'type': 'manual',
        'time': Timestamp.now(),
        'userId': uid,
        'userEmail': AuthService.currentUser?.email ?? '',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved! Buyers can now see your details.'), backgroundColor: AppColors.card));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.card));
      }
    }
    if (mounted) setState(() => saving = false);
  }

  Widget _num(String l, TextEditingController c, {IconData? icon}) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: AppColors.textBright),
        decoration: InputDecoration(labelText: l, prefixIcon: icon == null ? null : Icon(icon, size: 20, color: AppColors.textDim)),
      );

  Widget _slider(String l, double v, ValueChanged<double> on) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(l, style: const TextStyle(color: AppColors.textBright, fontSize: 13)),
          const Spacer(),
          Text('${(v * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ]),
        Slider(value: v, min: 0.5, max: 1.0, divisions: 50, activeColor: AppColors.primary, onChanged: on),
      ]);

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(isNew ? 'Welcome! Set up your supplier profile' : 'My Supplier Details',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBright)),
        const SizedBox(height: 4),
        const Text('This is what procurement teams see and the AI engine uses to allocate orders.',
            style: TextStyle(color: AppColors.textDim, fontSize: 12)),
        const SizedBox(height: 16),
        GlowCard(
          borderColor: AppColors.secondary,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('COMPANY & PRODUCT',
                style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            TextField(
                controller: nameC,
                style: const TextStyle(color: AppColors.textBright),
                decoration: const InputDecoration(labelText: 'Company name (e.g. Jindal Steel)', prefixIcon: Icon(Icons.business, size: 20))),
            const SizedBox(height: 10),
            TextField(
                controller: productC,
                style: const TextStyle(color: AppColors.textBright),
                decoration: const InputDecoration(labelText: 'Product (e.g. TMT Steel Bars)', prefixIcon: Icon(Icons.inventory_2, size: 20))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: catC,
                      style: const TextStyle(color: AppColors.textBright),
                      decoration: const InputDecoration(labelText: 'Category'))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: locC,
                      style: const TextStyle(color: AppColors.textBright),
                      decoration: const InputDecoration(labelText: 'Location'))),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        GlowCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PRICING & CAPACITY',
                style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _num('Price / unit (₹)', priceC, icon: Icons.currency_rupee)),
              const SizedBox(width: 10),
              Expanded(child: _num('Delivery days', daysC, icon: Icons.schedule)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _num('Capacity (units)', capC, icon: Icons.warehouse)),
              const SizedBox(width: 10),
              Expanded(child: _num('Min order', minC, icon: Icons.shopping_cart)),
            ]),
            const SizedBox(height: 10),
            _num('Current stock', stockC, icon: Icons.inventory),
            const SizedBox(height: 16),
            _slider('Reliability (on-time delivery)', reliability, (v) => setState(() => reliability = v)),
            _slider('Quality score', quality, (v) => setState(() => quality = v)),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Icon(Icons.cloud_upload),
            label: Text(isNew ? 'PUBLISH MY PROFILE' : 'SAVE CHANGES', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ============================================================
// DASHBOARD
// ============================================================
class DashboardScreen extends StatelessWidget {
  final Supplier me;
  final List<Supplier> competitors;
  const DashboardScreen({super.key, required this.me, required this.competitors});

  int _rank(List<Supplier> group, num Function(Supplier) key, {bool lowerBetter = true}) {
    final sorted = List<Supplier>.from(group)
      ..sort((a, b) => lowerBetter ? key(a).compareTo(key(b)) : key(b).compareTo(key(a)));
    return sorted.indexWhere((s) => s.id == me.id) + 1;
  }

  double _avg(List<Supplier> l, num Function(Supplier) f) =>
      l.isEmpty ? 0 : l.map(f).reduce((a, b) => a + b) / l.length;

  @override
  Widget build(BuildContext context) {
    final peers = competitors.where((c) => c.category.toLowerCase() == me.category.toLowerCase()).toList();
    final group = [me, ...peers];
    final n = group.length;
    final avgPrice = _avg(peers, (s) => s.price);
    final avgDays = _avg(peers, (s) => s.deliveryDays);
    final avgRel = _avg(peers, (s) => s.reliability);
    final avgCap = _avg(peers, (s) => s.capacity);
    final risk = mlRisk(me);

    final priceRank = _rank(group, (s) => s.price);
    final speedRank = _rank(group, (s) => s.deliveryDays);
    final relRank = _rank(group, (s) => s.reliability, lowerBetter: false);
    final aiRank = _rank(group, buyerScore);

    final tips = <String>[];
    if (peers.isEmpty) {
      tips.add('No competitors in "${me.category}" yet — you have the market to yourself.');
    } else {
      if (me.price > avgPrice * 1.05) {
        tips.add('Your price is ${((me.price / avgPrice - 1) * 100).toStringAsFixed(0)}% above the category average (₹${fmt(avgPrice)}). Consider lowering or justifying with quality.');
      } else if (me.price < avgPrice * 0.85) {
        tips.add('You are ${((1 - me.price / avgPrice) * 100).toStringAsFixed(0)}% cheaper than average — room to raise price slightly without losing orders.');
      } else {
        tips.add('Your price is close to market average — good competitive position.');
      }
      if (me.deliveryDays > avgDays) tips.add('Delivery (${me.deliveryDays}d) is slower than average (${avgDays.toStringAsFixed(1)}d). Faster delivery boosts your AI score.');
      if (me.reliability < avgRel) tips.add('Reliability (${(me.reliability * 100).toStringAsFixed(0)}%) is below average (${(avgRel * 100).toStringAsFixed(0)}%). Buyers weight this heavily.');
      if (me.capacity < avgCap) tips.add('Capacity (${fmt(me.capacity)}) is below average (${fmt(avgCap)}) — larger orders may be split away from you.');
    }

    final chartList = List<Supplier>.from(group)..sort((a, b) => a.price.compareTo(b.price));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Hello, ${me.name} 👋',
            style: const TextStyle(color: AppColors.textBright, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${me.product.isEmpty ? me.category : me.product} · ${me.location}',
            style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
        const SizedBox(height: 16),
        GlowCard(
          borderColor: AppColors.primary,
          child: Row(children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), shape: BoxShape.circle),
              child: Text('#$aiRank', style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your rank in buyer\'s AI engine',
                    style: TextStyle(color: AppColors.textBright, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Out of $n supplier${n == 1 ? '' : 's'} in "${me.category}". Based on price, risk & delivery.',
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _stat('My Price', '₹${fmt(me.price)}', Icons.currency_rupee, AppColors.primary, peers.isEmpty ? '—' : 'Avg ₹${fmt(avgPrice)}')),
          const SizedBox(width: 10),
          Expanded(child: _stat('Delivery', '${me.deliveryDays}d', Icons.schedule, AppColors.secondary, peers.isEmpty ? '—' : 'Avg ${avgDays.toStringAsFixed(1)}d')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _stat('Capacity', fmt(me.capacity), Icons.warehouse, AppColors.warning, peers.isEmpty ? '—' : 'Avg ${fmt(avgCap)}')),
          const SizedBox(width: 10),
          Expanded(child: _stat('ML Risk', '${risk.toStringAsFixed(0)}/100', Icons.security, riskColor(risk / 100), 'Lower is better')),
        ]),
        const SizedBox(height: 16),
        GlowCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('RANKINGS IN YOUR CATEGORY',
                style: TextStyle(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 12),
            _rankRow('Cheapest price', priceRank, n),
            _rankRow('Fastest delivery', speedRank, n),
            _rankRow('Most reliable', relRank, n),
          ]),
        ),
        const SizedBox(height: 16),
        GlowCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Price Comparison (₹ / unit)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBright)),
            const SizedBox(height: 4),
            const Text('Green = you', style: TextStyle(color: AppColors.textDim, fontSize: 11)),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  maxY: (chartList.map((e) => e.price).reduce(max)) * 1.2,
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
                          final i = v.toInt();
                          if (i < 0 || i >= chartList.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(chartList[i].name.split(' ').first,
                                style: const TextStyle(fontSize: 9, color: AppColors.textDim)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: chartList.asMap().entries.map((e) {
                    final isMe = e.value.id == me.id;
                    return BarChartGroupData(x: e.key, barRods: [
                      BarChartRodData(
                        toY: e.value.price,
                        color: isMe ? AppColors.primary : AppColors.textDim,
                        width: 22,
                        borderRadius: BorderRadius.circular(4),
                      )
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        GlowCard(
          borderColor: AppColors.secondary,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('HOW TO WIN MORE ORDERS',
                style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 10),
            ...tips.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.lightbulb, color: AppColors.secondary, size: 14),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t, style: const TextStyle(color: AppColors.textBright, fontSize: 13, height: 1.4))),
                  ]),
                )),
          ]),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _rankRow(String label, int rank, int total) {
    final good = rank <= (total / 2).ceil();
    final c = rank == 1 ? AppColors.primary : (good ? AppColors.warning : AppColors.danger);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.textBright, fontSize: 13))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text('#$rank of $total', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color, String sub) {
    return GlowCard(
      borderColor: color,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 12))),
        ]),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(sub, style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
      ]),
    );
  }
}

// ============================================================
// COMPETITORS
// ============================================================
class CompetitorsScreen extends StatefulWidget {
  final Supplier me;
  final List<Supplier> competitors;
  const CompetitorsScreen({super.key, required this.me, required this.competitors});
  @override
  State<CompetitorsScreen> createState() => _CompetitorsScreenState();
}

class _CompetitorsScreenState extends State<CompetitorsScreen> {
  String filter = 'My Category';

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final cats = widget.competitors.map((c) => c.category).toSet().toList()..sort();
    List<Supplier> list = widget.competitors;
    if (filter == 'My Category') {
      list = list.where((c) => c.category.toLowerCase() == me.category.toLowerCase()).toList();
    } else if (filter != 'All') {
      list = list.where((c) => c.category == filter).toList();
    }
    list = List<Supplier>.from(list)..sort((a, b) => buyerScore(a).compareTo(buyerScore(b)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          const Icon(Icons.groups, color: AppColors.secondary),
          const SizedBox(width: 8),
          const Text('Competitors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBright)),
          const Spacer(),
          Text('${list.length} FOUND', style: const TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        const Text('Sorted by how the buyer\'s AI engine ranks them', style: TextStyle(color: AppColors.textDim, fontSize: 12)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: ['My Category', 'All', ...cats].map((c) {
          final sel = filter == c;
          return ChoiceChip(
            label: Text(c),
            selected: sel,
            onSelected: (_) => setState(() => filter = c),
            selectedColor: AppColors.secondary.withOpacity(0.3),
          );
        }).toList()),
        const SizedBox(height: 14),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No competitors found', style: TextStyle(color: AppColors.textDim))),
          ),
        ...list.map((c) => _card(c, me)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _card(Supplier c, Supplier me) {
    final r = mlRisk(c);
    final beatsMe = buyerScore(c) < buyerScore(me);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlowCard(
        borderColor: beatsMe ? AppColors.danger : AppColors.primary,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: riskColor(r / 100).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.factory, color: riskColor(r / 100)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: const TextStyle(color: AppColors.textBright, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${c.location}  •  ${c.product.isEmpty ? c.category : c.product}',
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: (beatsMe ? AppColors.danger : AppColors.primary).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(beatsMe ? 'AHEAD OF YOU' : 'BEHIND YOU',
                  style: TextStyle(color: beatsMe ? AppColors.danger : AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _m('Price', '₹${fmt(c.price)}', c.price - me.price, lowerBetter: true, unit: '₹'),
            _m('Delivery', '${c.deliveryDays}d', (c.deliveryDays - me.deliveryDays).toDouble(), lowerBetter: true, unit: 'd'),
            _m('Capacity', fmt(c.capacity), (c.capacity - me.capacity).toDouble(), lowerBetter: false, unit: ''),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _m('Reliability', '${(c.reliability * 100).toInt()}%', (c.reliability - me.reliability) * 100, lowerBetter: false, unit: '%'),
            _m('Quality', '${(c.qualityScore * 100).toInt()}%', (c.qualityScore - me.qualityScore) * 100, lowerBetter: false, unit: '%'),
            _m('ML Risk', r.toStringAsFixed(0), r - mlRisk(me), lowerBetter: true, unit: ''),
          ]),
        ]),
      ),
    );
  }

  // diff = competitor - me. Red when competitor is better than you.
  Widget _m(String l, String v, double diff, {required bool lowerBetter, required String unit}) {
    final compBetter = lowerBetter ? diff < 0 : diff > 0;
    final c = diff.abs() < 0.0001 ? AppColors.textDim : (compBetter ? AppColors.danger : AppColors.primary);
    final sign = diff > 0 ? '+' : (diff < 0 ? '-' : '');
    final d = diff.abs() < 0.0001 ? '=' : '$sign${unit == '₹' ? '₹' : ''}${diff.abs().toStringAsFixed(unit == '%' ? 0 : (unit == '₹' ? 0 : 0))}${unit == '₹' ? '' : unit}';
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
        Text(v, style: const TextStyle(color: AppColors.textBright, fontSize: 13, fontWeight: FontWeight.w600)),
        Text('vs you $d', style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}