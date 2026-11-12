import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MuscleBuilderApp());
}

/// 記録が変更されたら +1 して、ホーム画面などに再読み込みを知らせる
final ValueNotifier<int> recordsVersion = ValueNotifier<int>(0);

/// タイムライン側で共有を取り消したら +1 して、記録画面に知らせる
final ValueNotifier<int> sharedVersion = ValueNotifier<int>(0);

class MuscleBuilderApp extends StatelessWidget {
  const MuscleBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MUSCLE BUILDER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// ログイン状態の切り替え
// ============================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

// ============================================================
// ログイン画面（Google）
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool loading = false;
  String? error;

  Future<void> signInWithGoogle() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final provider = GoogleAuthProvider();
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithProvider(provider);
      }
    } on FirebaseAuthException catch (e) {
      // ポップアップを自分で閉じた場合はエラー表示しない
      final cancelled =
          e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request';
      if (mounted && !cancelled) {
        setState(() => error = 'ログインに失敗しました（${e.code}）');
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'ログインに失敗しました');
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fitness_center, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'MUSCLE BUILDER',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ログインして、記録を仲間と共有しよう',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: loading ? null : signInWithGoogle,
                      icon: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text(
                        'Googleでログイン',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// データモデル：トレーニング記録
// ============================================================

class WorkoutRecord {
  final String id; // 共有投稿の識別にも使う
  final String exercise;
  final double weight; // kg
  final int reps;
  final int? durationMinutes; // 運動時間（任意）
  final DateTime createdAt;

  const WorkoutRecord({
    required this.id,
    required this.exercise,
    required this.weight,
    required this.reps,
    required this.createdAt,
    this.durationMinutes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'exercise': exercise,
    'weight': weight,
    'reps': reps,
    'durationMinutes': durationMinutes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) {
    return WorkoutRecord(
      id: json['id'] as String,
      exercise: json['exercise'] as String,
      weight: (json['weight'] as num).toDouble(),
      reps: (json['reps'] as num).toInt(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// 50.0 → "50"、52.5 → "52.5"
  String get weightText =>
      weight == weight.roundToDouble() ? weight.toInt().toString() : '$weight';

  String get title => '$exercise  ${weightText}kg × $reps回';

  String get subtitle {
    final d = createdAt;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final date = '${d.month}/${d.day} $hh:$mm';
    return durationMinutes == null ? date : '$date ・ $durationMinutes分';
  }
}

// ============================================================
// 保存・読み込み（アカウントごとに SharedPreferences へ保存）
// ============================================================

class RecordStore {
  static const String _legacyV2 = 'records_v2'; // アカウント分け前の形式
  static const String _keyOld = 'records'; // 最初の文字列形式

  static String get _userKey =>
      'records_v2_${FirebaseAuth.instance.currentUser?.uid ?? 'guest'}';

  static List<WorkoutRecord> _decode(List<String> raw) {
    final list = <WorkoutRecord>[];
    for (final s in raw) {
      try {
        list.add(WorkoutRecord.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // 壊れたデータは読み飛ばす
      }
    }
    return list;
  }

  static Future<List<WorkoutRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getStringList(_userKey);
    if (raw != null) return _decode(raw);

    // これまでの記録は、最初にログインしたアカウントへ引き継ぐ
    final legacy = prefs.getStringList(_legacyV2);
    if (legacy != null) {
      final list = _decode(legacy);
      await save(list);
      await prefs.remove(_legacyV2);
      return list;
    }

    final old = prefs.getStringList(_keyOld);
    if (old == null || old.isEmpty) return [];

    final now = DateTime.now();
    final regex = RegExp(r'^(.*?)\s{2}([\d.]+)kg × (\d+)回$');
    final migrated = <WorkoutRecord>[];

    for (var i = 0; i < old.length; i++) {
      final m = regex.firstMatch(old[i]);
      if (m == null) continue;
      final w = double.tryParse(m.group(2)!);
      final r = int.tryParse(m.group(3)!);
      if (w == null || r == null) continue;

      migrated.add(
        WorkoutRecord(
          id: '${now.microsecondsSinceEpoch}_$i',
          exercise: m.group(1)!,
          weight: w,
          reps: r,
          createdAt: now, // 旧データには日時がないため移行時刻を入れる
        ),
      );
    }

    await save(migrated);
    await prefs.remove(_keyOld);
    return migrated;
  }

  static Future<void> save(List<WorkoutRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _userKey,
      records.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }
}

// ============================================================
// 共有（Firestore の posts コレクション）
// ============================================================

CollectionReference<Map<String, dynamic>> get postsRef =>
    FirebaseFirestore.instance.collection('posts');

/// 投稿のドキュメントID（同じ記録は何度共有しても1件になる）
String postIdFor(String uid, String recordId) => '${uid}_$recordId';

/// Firestore の投稿データ → WorkoutRecord
WorkoutRecord recordFromPost(Map<String, dynamic> data, String fallbackId) {
  return WorkoutRecord(
    id: data['recordId'] as String? ?? fallbackId,
    exercise: data['exercise'] as String? ?? '',
    weight: (data['weight'] as num?)?.toDouble() ?? 0,
    reps: (data['reps'] as num?)?.toInt() ?? 0,
    durationMinutes: (data['durationMinutes'] as num?)?.toInt(),
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

// ============================================================
// メイン画面
// ============================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    HomeScreen(),
    WorkoutScreen(),
    FeedScreen(),
    AiScreen(),
    TimerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: '記録',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'みんな',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'タイマー',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ホーム
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WorkoutRecord> records = [];

  @override
  void initState() {
    super.initState();
    loadRecords();
    recordsVersion.addListener(loadRecords);
  }

  @override
  void dispose() {
    recordsVersion.removeListener(loadRecords);
    super.dispose();
  }

  Future<void> loadRecords() async {
    final loaded = await RecordStore.load();

    if (!mounted) return;
    setState(() {
      records = loaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName = FirebaseAuth.instance.currentUser?.displayName ?? 'ゲスト';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadRecords,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'MUSCLE BUILDER',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'ログアウト',
                  icon: const Icon(Icons.logout),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '$userNameさん、トレーニングを記録しよう',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 25),

            // 今日のトレーニング
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.fitness_center),
                        SizedBox(width: 8),
                        Text(
                          '今日のトレーニング',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      '胸・三頭筋',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'おすすめ時間：18:00',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // タンパク質
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '今日のタンパク質',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '80',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 5),
                        Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text('g / 100g'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(
                      value: 0.8,
                      minHeight: 10,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // 最近の記録
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '最近の記録',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (records.isEmpty)
                      const Text(
                        'まだ記録がありません',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      ...records
                          .take(3)
                          .map(
                            (record) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.check_circle),
                              title: Text(record.title),
                              subtitle: Text(record.subtitle),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            const Card(
              child: ListTile(
                leading: Icon(Icons.auto_awesome),
                title: Text(
                  'AIからのおすすめ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('AIタブから今日のメニューを確認できます。'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// トレーニング記録（追加・編集・削除・共有）
// ============================================================

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  String exercise = 'ベンチプレス';

  final TextEditingController weightController = TextEditingController(
    text: '50',
  );
  final TextEditingController repsController = TextEditingController(
    text: '10',
  );
  final TextEditingController durationController = TextEditingController();

  static const List<String> defaultExercises = [
    'ベンチプレス',
    'スクワット',
    'デッドリフト',
    'ショルダープレス',
    'ラットプルダウン',
    'アームカール',
  ];

  List<String> exercises = [...defaultExercises];
  List<WorkoutRecord> records = [];

  /// 共有済みの記録ID
  Set<String> sharedIds = {};

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    loadData();
    loadSharedIds();
    sharedVersion.addListener(loadSharedIds);
  }

  @override
  void dispose() {
    sharedVersion.removeListener(loadSharedIds);
    weightController.dispose();
    repsController.dispose();
    durationController.dispose();
    super.dispose();
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = await RecordStore.load();

    if (!mounted) return;
    setState(() {
      exercises = prefs.getStringList('exercises') ?? [...defaultExercises];
      records = loaded;
      if (!exercises.contains(exercise) && exercises.isNotEmpty) {
        exercise = exercises.first;
      }
    });
  }

  /// 自分が共有している記録IDを Firestore から取得
  Future<void> loadSharedIds() async {
    final u = uid;
    if (u == null) return;

    try {
      final snap = await postsRef.where('uid', isEqualTo: u).get();
      if (!mounted) return;
      setState(() {
        sharedIds = snap.docs
            .map((d) => d.data()['recordId'])
            .whereType<String>()
            .toSet();
      });
    } catch (_) {
      // 読み込みに失敗しても、記録画面はそのまま使えるようにする
    }
  }

  Map<String, dynamic> postData(WorkoutRecord r) {
    final user = FirebaseAuth.instance.currentUser!;
    return {
      'uid': user.uid,
      'userName': user.displayName ?? '名無しさん',
      'recordId': r.id,
      'exercise': r.exercise,
      'weight': r.weight,
      'reps': r.reps,
      'durationMinutes': r.durationMinutes,
      'createdAt': Timestamp.fromDate(r.createdAt),
      'sharedAt': FieldValue.serverTimestamp(),
    };
  }

  /// 共有する／共有を取り消す
  Future<void> toggleShare(WorkoutRecord r) async {
    final u = uid;
    if (u == null) return;

    final docRef = postsRef.doc(postIdFor(u, r.id));

    try {
      if (sharedIds.contains(r.id)) {
        await docRef.delete();
        sharedIds.remove(r.id);
        if (!mounted) return;
        setState(() {});
        showMessage('共有を取り消しました');
      } else {
        await docRef.set(postData(r));
        sharedIds.add(r.id);
        if (!mounted) return;
        setState(() {});
        showMessage('みんなに共有しました！');
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      showMessage('共有に失敗しました（${e.code}）');
    }
  }

  Future<void> persist() async {
    await RecordStore.save(records);
    recordsVersion.value++;
  }

  Future<void> saveRecord() async {
    final weight = double.tryParse(weightController.text.trim());
    final reps = int.tryParse(repsController.text.trim());
    final durationText = durationController.text.trim();
    final duration = durationText.isEmpty ? null : int.tryParse(durationText);

    if (weight == null || weight < 0) {
      showMessage('重量を正しく入力してください');
      return;
    }
    if (reps == null || reps <= 0) {
      showMessage('回数を正しく入力してください');
      return;
    }
    if (durationText.isNotEmpty && (duration == null || duration < 0)) {
      showMessage('運動時間を正しく入力してください');
      return;
    }

    final now = DateTime.now();
    records.insert(
      0,
      WorkoutRecord(
        id: now.microsecondsSinceEpoch.toString(),
        exercise: exercise,
        weight: weight,
        reps: reps,
        durationMinutes: duration,
        createdAt: now,
      ),
    );

    await persist();

    if (!mounted) return;
    setState(() {});
    showMessage('トレーニングを記録しました！');
  }

  Future<void> addExercise() async {
    final controller = TextEditingController();

    final newExercise = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('種目を追加'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '種目名',
              hintText: '例：ダンベルフライ',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();

                if (text.isNotEmpty) {
                  Navigator.pop(context, text);
                }
              },
              child: const Text('追加'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (newExercise == null || newExercise.isEmpty) return;
    if (exercises.contains(newExercise)) return;

    final prefs = await SharedPreferences.getInstance();

    exercises.add(newExercise);

    await prefs.setStringList('exercises', exercises);

    if (!mounted) return;
    setState(() {
      exercise = newExercise;
    });
  }

  Future<void> deleteRecord(int index) async {
    final target = records[index];
    records.removeAt(index);
    await persist();

    // 共有していた記録は、共有投稿もいっしょに消す
    final u = uid;
    if (u != null && sharedIds.contains(target.id)) {
      try {
        await postsRef.doc(postIdFor(u, target.id)).delete();
        sharedIds.remove(target.id);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {});
  }

  /// 記録の編集（種目・重量・回数・運動時間）
  Future<void> editRecord(int index) async {
    final target = records[index];

    String editExercise = target.exercise;
    final editWeight = TextEditingController(text: target.weightText);
    final editReps = TextEditingController(text: target.reps.toString());
    final editDuration = TextEditingController(
      text: target.durationMinutes?.toString() ?? '',
    );

    // 種目リストにない種目でも選べるようにする
    final options = [...exercises];
    if (!options.contains(editExercise)) options.add(editExercise);

    final result = await showDialog<WorkoutRecord>(
      context: context,
      builder: (context) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('記録を編集'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: editExercise,
                      decoration: const InputDecoration(
                        labelText: '種目',
                        border: OutlineInputBorder(),
                      ),
                      items: options
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => editExercise = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editWeight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '重量',
                        suffixText: 'kg',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editReps,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '回数',
                        suffixText: '回',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: editDuration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '運動時間（任意）',
                        suffixText: '分',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    final w = double.tryParse(editWeight.text.trim());
                    final r = int.tryParse(editReps.text.trim());
                    final dText = editDuration.text.trim();
                    final d = dText.isEmpty ? null : int.tryParse(dText);

                    if (w == null || w < 0) {
                      setDialogState(() => errorText = '重量を正しく入力してください');
                      return;
                    }
                    if (r == null || r <= 0) {
                      setDialogState(() => errorText = '回数を正しく入力してください');
                      return;
                    }
                    if (dText.isNotEmpty && (d == null || d < 0)) {
                      setDialogState(() => errorText = '運動時間を正しく入力してください');
                      return;
                    }

                    Navigator.pop(
                      context,
                      WorkoutRecord(
                        id: target.id,
                        exercise: editExercise,
                        weight: w,
                        reps: r,
                        durationMinutes: d,
                        createdAt: target.createdAt,
                      ),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    editWeight.dispose();
    editReps.dispose();
    editDuration.dispose();

    if (result == null) return;

    records[index] = result;
    await persist();

    // 共有済みの記録は、共有投稿の内容も更新する
    final u = uid;
    if (u != null && sharedIds.contains(result.id)) {
      try {
        final data = postData(result)..remove('sharedAt');
        await postsRef.doc(postIdFor(u, result.id)).update(data);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {});
    showMessage('記録を更新しました');
  }

  Widget inputCard({
    required String label,
    required TextEditingController controller,
    required String suffix,
    bool decimal = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                suffixText: suffix,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'トレーニング記録',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // 種目選択
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '種目',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          // 種目追加時に表示を更新するため key を付ける
                          key: ValueKey(exercise),
                          initialValue: exercise,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          items: exercises.map((item) {
                            return DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                exercise = value;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        tooltip: '種目を追加',
                        onPressed: addExercise,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),

          inputCard(
            label: '重量',
            controller: weightController,
            suffix: 'kg',
            decimal: true,
          ),
          const SizedBox(height: 15),

          inputCard(label: '回数', controller: repsController, suffix: '回'),
          const SizedBox(height: 15),

          inputCard(
            label: '運動時間（任意）',
            controller: durationController,
            suffix: '分',
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 60,
            child: FilledButton.icon(
              onPressed: saveRecord,
              icon: const Icon(Icons.save),
              label: const Text('記録を保存', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 30),

          const Text(
            '記録一覧',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '共有ボタンを押した記録だけが「みんな」に表示されます',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 10),

          if (records.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('まだ記録がありません。'),
              ),
            )
          else
            ...records.asMap().entries.map((entry) {
              final index = entry.key;
              final record = entry.value;
              final shared = sharedIds.contains(record.id);

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: Text(record.title),
                  subtitle: Text(record.subtitle),
                  onTap: () => editRecord(index),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: shared ? '共有を取り消す' : 'みんなに共有',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          shared ? Icons.public : Icons.share_outlined,
                          color: shared ? primary : null,
                        ),
                        onPressed: () => toggleShare(record),
                      ),
                      IconButton(
                        tooltip: '編集',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => editRecord(index),
                      ),
                      IconButton(
                        tooltip: '削除',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => deleteRecord(index),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ============================================================
// みんな（共有された記録のタイムライン）
// ============================================================

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  Future<void> deletePost(BuildContext context, String docId) async {
    try {
      await postsRef.doc(docId).delete();
      sharedVersion.value++;
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('削除に失敗しました（${e.code}）')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    final stream = postsRef
        .orderBy('sharedAt', descending: true)
        .limit(50)
        .snapshots();

    return SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          final children = <Widget>[
            const Text(
              'みんなの記録',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '共有された最新のトレーニングです',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
          ];

          if (snapshot.hasError) {
            children.add(
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    '読み込みに失敗しました。\n${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            );
          } else if (!snapshot.hasData) {
            children.add(
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          } else if (snapshot.data!.docs.isEmpty) {
            children.add(
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'まだ共有された記録がありません。\n'
                    '「記録」タブの共有ボタンから投稿してみよう！',
                  ),
                ),
              ),
            );
          } else {
            for (final doc in snapshot.data!.docs) {
              final data = doc.data();
              final record = recordFromPost(data, doc.id);
              final userName = data['userName'] as String? ?? '名無しさん';
              final isMine = data['uid'] == myUid;

              children.add(
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        userName.isEmpty ? '?' : userName.characters.first,
                      ),
                    ),
                    title: Text(record.title),
                    subtitle: Text('$userName ・ ${record.subtitle}'),
                    trailing: isMine
                        ? IconButton(
                            tooltip: '共有を取り消す',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => deletePost(context, doc.id),
                          )
                        : null,
                  ),
                ),
              );
            }
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: children,
          );
        },
      ),
    );
  }
}

// ============================================================
// AI
// ============================================================

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  int suggestionIndex = 0;
  bool loading = false;

  final List<Map<String, String>> suggestions = [
    {
      'title': '胸を中心にトレーニング',
      'menu': 'ベンチプレス\nダンベルフライ\nインクラインプレス\nプッシュアップ',
      'reason': '胸を中心に鍛えたい日におすすめのメニューです。',
    },
    {
      'title': '脚を中心にトレーニング',
      'menu': 'スクワット\nレッグプレス\nランジ\nカーフレイズ',
      'reason': '下半身をバランスよく鍛える構成です。',
    },
    {
      'title': '背中を中心にトレーニング',
      'menu': 'ラットプルダウン\nローイング\nデッドリフト\nバックエクステンション',
      'reason': '背中の複数の部位を使うメニューです。',
    },
    {
      'title': '全身トレーニング',
      'menu': 'スクワット\nベンチプレス\nラットプルダウン\nショルダープレス',
      'reason': '全身をまんべんなく動かしたい日におすすめです。',
    },
  ];

  Future<void> getNewSuggestion() async {
    setState(() {
      loading = true;
    });

    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    setState(() {
      suggestionIndex = (suggestionIndex + 1) % suggestions.length;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = suggestions[suggestionIndex];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'AIトレーニング',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'あなたに合ったメニューを提案します',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 25),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome),
                      SizedBox(width: 8),
                      Text(
                        '今日のおすすめ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    suggestion['title']!,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.grey.shade100,
                    ),
                    child: Text(
                      suggestion['menu']!,
                      style: const TextStyle(fontSize: 17, height: 1.7),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    suggestion['reason']!,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 60,
            child: FilledButton.icon(
              onPressed: loading ? null : getNewSuggestion,
              icon: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                loading ? '考えています...' : 'もう一度提案',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 25),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '現在はアプリ内の提案エンジンです。'
                      '今後、サーバーを用意することで生成AIと安全に接続できます。',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// タイマー（運動 / 休憩 を自動で切り替え）
// ============================================================

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int workSeconds = 45;
  int restSeconds = 60;
  int totalSets = 3;

  int currentSet = 1;
  bool isWork = true;
  bool running = false;
  bool finished = false;
  int remaining = 45;

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get phaseTotal => isWork ? workSeconds : restSeconds;

  void start() {
    if (finished) reset();
    _timer?.cancel();
    setState(() => running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void pause() {
    _timer?.cancel();
    setState(() => running = false);
  }

  void reset() {
    _timer?.cancel();
    setState(() {
      running = false;
      finished = false;
      isWork = true;
      currentSet = 1;
      remaining = workSeconds;
    });
  }

  void tick() {
    if (remaining > 1) {
      setState(() => remaining--);
      return;
    }

    // フェーズ終了
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    setState(() {
      if (isWork) {
        if (currentSet >= totalSets) {
          // 全セット終了
          _timer?.cancel();
          running = false;
          finished = true;
          remaining = 0;
        } else {
          isWork = false;
          remaining = restSeconds;
        }
      } else {
        isWork = true;
        currentSet++;
        remaining = workSeconds;
      }
    });
  }

  String format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // 設定用の +/- 行（動作中は変更不可）
  Widget stepper({
    required String label,
    required String valueText,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton.outlined(
          onPressed: running ? null : onMinus,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 80,
          child: Text(
            valueText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
        ),
        IconButton.outlined(
          onPressed: running ? null : onPlus,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = finished
        ? Colors.green
        : (isWork ? Colors.orange : Colors.blue);
    final phaseLabel = finished ? '完了！おつかれさま' : (isWork ? '運動' : '休憩');
    final progress = finished || phaseTotal == 0
        ? 1.0
        : 1 - (remaining / phaseTotal);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'タイマー',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // タイマー表示
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    phaseLabel,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'セット $currentSet / $totalSets',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 12,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.15),
                          ),
                        ),
                        Text(
                          format(remaining),
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),

          // 操作ボタン
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    onPressed: running ? pause : start,
                    icon: Icon(running ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      running ? '一時停止' : (finished ? 'もう一度' : 'スタート'),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: reset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('リセット'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 設定
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  stepper(
                    label: '運動時間',
                    valueText: '$workSeconds秒',
                    onMinus: () => setState(() {
                      if (workSeconds > 5) workSeconds -= 5;
                      remaining = workSeconds;
                    }),
                    onPlus: () => setState(() {
                      workSeconds += 5;
                      remaining = workSeconds;
                    }),
                  ),
                  const SizedBox(height: 12),
                  stepper(
                    label: '休憩時間',
                    valueText: '$restSeconds秒',
                    onMinus: () => setState(() {
                      if (restSeconds > 5) restSeconds -= 5;
                    }),
                    onPlus: () => setState(() => restSeconds += 5),
                  ),
                  const SizedBox(height: 12),
                  stepper(
                    label: 'セット数',
                    valueText: '$totalSets',
                    onMinus: () => setState(() {
                      if (totalSets > 1) totalSets--;
                    }),
                    onPlus: () => setState(() => totalSets++),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
