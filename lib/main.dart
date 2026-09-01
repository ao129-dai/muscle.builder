import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const MuscleBuilderApp());
}

class MuscleBuilderApp extends StatelessWidget {
  const MuscleBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MUSCLE BUILDER',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      ),
      home: const MainScreen(),
    );
  }
}

// ============================================================
// メイン
// ============================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  final screens = const [
    HomeScreen(),
    WorkoutScreen(),
    AiScreen(),
    TimerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MUSCLE BUILDER',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今日のトレーニング',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
                title: const Text(
                  '胸・三頭筋',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('AIおすすめメニュー'),
                trailing: const Icon(Icons.arrow_forward_ios),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              '今日のタンパク質',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '80 g',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('目標 100 g'),
                      ],
                    ),
                    const SizedBox(height: 15),
                    LinearProgressIndicator(value: 0.8, minHeight: 10),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'AIからの提案',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 35),
                    SizedBox(width: 15),
                    Expanded(child: Text('今日は胸のトレーニングがおすすめです！')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 筋トレ記録
// ============================================================

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  String exercise = 'ベンチプレス';

  final weightController = TextEditingController();
  final repsController = TextEditingController();

  final exercises = [
    'ベンチプレス',
    'スクワット',
    'デッドリフト',
    'ショルダープレス',
    'ラットプルダウン',
    'アームカール',
  ];

  final List<String> records = [];

  @override
  void dispose() {
    weightController.dispose();
    repsController.dispose();
    super.dispose();
  }

  void saveRecord() {
    if (weightController.text.isEmpty || repsController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('重量と回数を入力してください')));
      return;
    }

    setState(() {
      records.add(
        '$exercise  ${weightController.text}kg × '
        '${repsController.text}回',
      );
    });

    weightController.clear();
    repsController.clear();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('記録しました！')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '筋トレ記録',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'トレーニングを記録',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              initialValue: exercise,
              decoration: const InputDecoration(
                labelText: '種目',
                border: OutlineInputBorder(),
              ),
              items: exercises.map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  exercise = value;
                });
              },
            ),

            const SizedBox(height: 15),

            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '重量 kg',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '回数',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saveRecord,
                icon: const Icon(Icons.save),
                label: const Text('記録する'),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              '記録履歴',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            if (records.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('まだ記録がありません。'),
                ),
              ),

            ...records.reversed.map(
              (record) => Card(
                child: ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: Text(record),
                  subtitle: const Text('今回の記録'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AI
// ============================================================

class AiScreen extends StatelessWidget {
  const AiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AIトレーニング',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.auto_awesome, size: 55),
                    SizedBox(height: 15),
                    Text(
                      '今日のおすすめ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '過去のトレーニング記録を参考にして、'
                      '今日のトレーニングを提案します。',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            menuCard('ベンチプレス', '50kg × 8〜10回 × 3セット'),

            menuCard('インクラインダンベルプレス', '10kg × 10〜12回 × 3セット'),

            menuCard('ケーブルプレスダウン', '15kg × 12〜15回 × 3セット'),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.refresh),
              label: const Text('もう一度提案'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget menuCard(String name, String detail) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.fitness_center),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(detail),
      ),
    );
  }
}

// ============================================================
// ★ タイマー完全版
// ============================================================

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Timer? timer;

  int exerciseSeconds = 40;
  int restSeconds = 20;
  int totalSets = 3;

  int remainingSeconds = 40;
  int currentSet = 1;

  bool isExercise = true;
  bool isRunning = false;

  // ----------------------------------------------------------
  // タイマー開始
  // ----------------------------------------------------------

  void startTimer() {
    if (isRunning) return;

    setState(() {
      isRunning = true;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        if (remainingSeconds > 0) {
          remainingSeconds--;
        } else {
          switchPhase();
        }
      });
    });
  }

  // ----------------------------------------------------------
  // 運動 ⇔ 休憩を切り替える
  // ----------------------------------------------------------

  void switchPhase() {
    if (isExercise) {
      // 運動終了 → 休憩
      isExercise = false;
      remainingSeconds = restSeconds;
    } else {
      // 休憩終了 → 次のセット
      if (currentSet >= totalSets) {
        timer?.cancel();
        timer = null;

        isRunning = false;
        currentSet = 1;
        isExercise = true;
        remainingSeconds = exerciseSeconds;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('トレーニング完了！お疲れさまでした💪')));
      } else {
        currentSet++;
        isExercise = true;
        remainingSeconds = exerciseSeconds;
      }
    }
  }

  // ----------------------------------------------------------
  // 一時停止
  // ----------------------------------------------------------

  void pauseTimer() {
    timer?.cancel();
    timer = null;

    setState(() {
      isRunning = false;
    });
  }

  // ----------------------------------------------------------
  // リセット
  // ----------------------------------------------------------

  void resetTimer() {
    timer?.cancel();
    timer = null;

    setState(() {
      isRunning = false;
      currentSet = 1;
      isExercise = true;
      remainingSeconds = exerciseSeconds;
    });
  }

  // ----------------------------------------------------------
  // 設定
  // ----------------------------------------------------------

  void openSettings() {
    int newExercise = exerciseSeconds;
    int newRest = restSeconds;
    int newSets = totalSets;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('タイマー設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: newExercise,
                    decoration: const InputDecoration(labelText: '運動時間'),
                    items: [10, 20, 30, 40, 45, 60, 90, 120].map((seconds) {
                      return DropdownMenuItem(
                        value: seconds,
                        child: Text('$seconds秒'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      dialogSetState(() {
                        newExercise = value;
                      });
                    },
                  ),

                  const SizedBox(height: 15),

                  DropdownButtonFormField<int>(
                    initialValue: newRest,
                    decoration: const InputDecoration(labelText: '休憩時間'),
                    items: [10, 15, 20, 30, 45, 60, 90, 120].map((seconds) {
                      return DropdownMenuItem(
                        value: seconds,
                        child: Text('$seconds秒'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      dialogSetState(() {
                        newRest = value;
                      });
                    },
                  ),

                  const SizedBox(height: 15),

                  DropdownButtonFormField<int>(
                    initialValue: newSets,
                    decoration: const InputDecoration(labelText: 'セット数'),
                    items: [1, 2, 3, 4, 5, 6, 8, 10].map((sets) {
                      return DropdownMenuItem(
                        value: sets,
                        child: Text('$setsセット'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      dialogSetState(() {
                        newSets = value;
                      });
                    },
                  ),
                ],
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
                    setState(() {
                      exerciseSeconds = newExercise;
                      restSeconds = newRest;
                      totalSets = newSets;

                      resetTimer();
                    });

                    Navigator.pop(context);
                  },
                  child: const Text('設定する'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'インターバルタイマー',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(onPressed: openSettings, icon: const Icon(Icons.settings)),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 現在の状態
            Text(
              isExercise ? '運動中' : '休憩中',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: isExercise ? Colors.red : Colors.blue,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'セット $currentSet / $totalSets',
              style: const TextStyle(fontSize: 20),
            ),

            const SizedBox(height: 40),

            // タイマー
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: 12,
                  color: isExercise ? Colors.red : Colors.blue,
                ),
              ),
              child: Center(
                child: Text(
                  formatTime(remainingSeconds),
                  style: const TextStyle(
                    fontSize: 55,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 設定内容
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('運動'),
                        Text(
                          '$exerciseSeconds秒',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('休憩'),
                        Text(
                          '$restSeconds秒',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('セット'),
                        Text(
                          '$totalSets',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: resetTimer,
                  icon: const Icon(Icons.refresh),
                  iconSize: 30,
                ),

                const SizedBox(width: 20),

                SizedBox(
                  width: 100,
                  height: 60,
                  child: FilledButton(
                    onPressed: isRunning ? pauseTimer : startTimer,
                    child: Icon(
                      isRunning ? Icons.pause : Icons.play_arrow,
                      size: 35,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
