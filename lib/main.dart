import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const defaultSupabaseUrl = 'https://bvexhnxklewrqdzbwlcd.supabase.co';
const defaultSupabaseKey = 'sb_publishable_SE3kLt6gcjYM2rAwxGWcQg_nqX2iwM3';
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: defaultSupabaseUrl,
);
const supabaseKey = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: defaultSupabaseKey,
);
const hasSupabaseConfig = supabaseUrl != '' && supabaseKey != '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (hasSupabaseConfig) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
    );
  }

  runApp(const NumberBattleApp(onlineEnabled: hasSupabaseConfig));
}

class NumberBattleApp extends StatelessWidget {
  const NumberBattleApp({super.key, required this.onlineEnabled});

  final bool onlineEnabled;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '九牌夺分',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D6F)),
        useMaterial3: true,
      ),
      home: HomePage(onlineEnabled: onlineEnabled),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onlineEnabled});

  final bool onlineEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      appBar: AppBar(
        title: const Text('九牌夺分'),
        backgroundColor: const Color(0xFF2E7D6F),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '选择模式',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GamePage()),
                ),
                icon: const Icon(Icons.phone_android),
                label: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('本机同屏游戏', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OnlineLobbyPage(onlineEnabled: onlineEnabled),
                  ),
                ),
                icon: const Icon(Icons.public),
                label: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('线上房间', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 18),
              if (!onlineEnabled)
                const Text(
                  '线上模式需要 Supabase 配置。配置后用运行参数启动，就可以创建房间和加入房间。',
                  style: TextStyle(fontSize: 15),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class Player {
  Player(this.name);

  final String name;
  double score = 0;
  final Set<int> usedCards = {};
  bool revolutionUsed = false;
  bool doubleUsed = false;
  bool doubleActive = false;
  bool lockUsed = false;
  bool peekUsed = false;
  int lossStreak = 0;
}

class RoundResult {
  RoundResult({
    required this.round,
    required this.plays,
    required this.pool,
    required this.winners,
    required this.reason,
    required this.revolution,
  });

  final int round;
  final Map<int, int> plays;
  final int pool;
  final List<int> winners;
  final String reason;
  final bool revolution;
}

enum Phase { setup, choosing, reveal, finished }

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  Phase phase = Phase.setup;
  int playerCount = 3;
  int round = 1;
  int currentPlayer = 0;
  int? selectedCard;
  int? lastSingleWinner;
  bool revolutionRound = false;
  final Map<int, int> currentLocks = {};

  final nameControllers = List.generate(
    5,
    (index) => TextEditingController(text: '玩家${index + 1}'),
  );

  List<Player> players = [];
  final Map<int, int> currentPlays = {};
  final List<RoundResult> history = [];
  RoundResult? latestResult;

  void startGame() {
    players = List.generate(
      playerCount,
      (index) => Player(
        nameControllers[index].text.trim().isEmpty
            ? '玩家${index + 1}'
            : nameControllers[index].text.trim(),
      ),
    );

    setState(() {
      phase = Phase.choosing;
      round = 1;
      currentPlayer = 0;
      selectedCard = null;
      lastSingleWinner = null;
      revolutionRound = false;
      currentLocks.clear();
      currentPlays.clear();
      history.clear();
      latestResult = null;
    });
  }

  void confirmCard() {
    if (selectedCard == null) return;

    currentPlays[currentPlayer] = selectedCard!;
    players[currentPlayer].usedCards.add(selectedCard!);

    setState(() {
      selectedCard = null;
      if (currentPlayer < players.length - 1) {
        currentPlayer++;
      } else {
        finishRound();
      }
    });
  }

  void finishRound() {
    final pool = currentPlays.values.fold<int>(0, (sum, card) => sum + card);
    final values = currentPlays.values.toList();
    final hasOne = values.contains(1);
    final hasNine = values.contains(9);

    int targetNumber;
    String reason;

    if (hasOne && hasNine) {
      targetNumber = revolutionRound ? 9 : 1;
      reason = revolutionRound
          ? 'revolution！场上同时出现 1 和 9，本轮 9 获胜'
          : '场上同时出现 1 和 9，本轮 1 获胜';
    } else {
      targetNumber = revolutionRound
          ? values.reduce((a, b) => a < b ? a : b)
          : values.reduce((a, b) => a > b ? a : b);
      reason = revolutionRound
          ? 'revolution！本轮最小数字是 $targetNumber'
          : '本轮最大数字是 $targetNumber';
    }

    final candidates = currentPlays.entries
        .where((entry) => entry.value == targetNumber)
        .map((entry) => entry.key)
        .toList();

    List<int> winners;

    if (candidates.length == 1) {
      winners = candidates;
    } else if (lastSingleWinner != null &&
        candidates.contains(lastSingleWinner)) {
      winners = [lastSingleWinner!];
      reason = '$reason；多人同为目标数字，上一轮胜者优先';
    } else {
      winners = candidates;
      reason = '$reason；多人同为目标数字，上一轮无可用胜者，平分分数';
    }

    final gain = pool / winners.length;
    final notes = <String>[];
    for (final winner in winners) {
      final multiplier = players[winner].doubleActive ? 2 : 1;
      players[winner].score += gain * multiplier;
      if (multiplier == 2) {
        notes.add('double：${players[winner].name} 得分翻倍');
      }
    }

    final compensation = <String>[];
    for (int i = 0; i < players.length; i++) {
      if (winners.contains(i)) {
        players[i].lossStreak = 0;
      } else {
        players[i].lossStreak++;
        if (players[i].lossStreak >= 2) {
          players[i].score += 2;
          compensation.add('${players[i].name} +2');
        }
      }
      players[i].doubleActive = false;
    }
    if (compensation.isNotEmpty) {
      notes.add('连输补偿：${compensation.join('、')}');
    }

    lastSingleWinner = winners.length == 1 ? winners.first : null;

    latestResult = RoundResult(
      round: round,
      plays: Map<int, int>.from(currentPlays),
      pool: pool,
      winners: winners,
      reason: notes.isEmpty ? reason : '$reason；${notes.join('；')}',
      revolution: revolutionRound,
    );
    history.add(latestResult!);

    currentPlays.clear();
    phase = round == 9 ? Phase.finished : Phase.reveal;
  }

  void nextRound() {
    setState(() {
      round++;
      currentPlayer = 0;
      selectedCard = null;
      revolutionRound = false;
      currentLocks.clear();
      phase = Phase.choosing;
    });
  }

  void restart() {
    setState(() {
      phase = Phase.setup;
      players.clear();
      currentPlays.clear();
      history.clear();
      latestResult = null;
      round = 1;
      currentPlayer = 0;
      selectedCard = null;
      lastSingleWinner = null;
      revolutionRound = false;
      currentLocks.clear();
    });
  }

  void activateRevolution() {
    final player = players[currentPlayer];
    if (player.revolutionUsed || revolutionRound) return;

    setState(() {
      revolutionRound = true;
      player.revolutionUsed = true;
    });
  }

  void activateDouble() {
    final player = players[currentPlayer];
    if (player.doubleUsed || player.doubleActive) return;

    setState(() {
      player.doubleUsed = true;
      player.doubleActive = true;
    });
  }

  Future<void> activateLock() async {
    final player = players[currentPlayer];
    if (player.lockUsed) return;

    final targets = [
      for (int i = 0; i < players.length; i++)
        if (i != currentPlayer && !currentPlays.containsKey(i)) i,
    ];
    if (targets.isEmpty) {
      showMessage('没有可以锁定的玩家');
      return;
    }

    var target = targets.first;
    var card = 9;
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('lock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: target,
                decoration: const InputDecoration(labelText: '锁定玩家'),
                items: [
                  for (final index in targets)
                    DropdownMenuItem(value: index, child: Text(players[index].name)),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => target = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: card,
                decoration: const InputDecoration(labelText: '禁止数字'),
                items: [
                  for (int i = 1; i <= 9; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => card = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop((target, card)),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    setState(() {
      player.lockUsed = true;
      currentLocks[result.$1] = result.$2;
    });
  }

  Future<void> activatePeek() async {
    final player = players[currentPlayer];
    if (player.peekUsed) return;

    final targets = currentPlays.keys.toList();
    if (targets.isEmpty) {
      showMessage('本轮还没有可偷看的牌');
      return;
    }

    setState(() {
      player.peekUsed = true;
    });

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('peek'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final index in targets)
              ListTile(
                title: Text(players[index].name),
                trailing: Text(
                  '${currentPlays[index]}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      appBar: AppBar(
        title: const Text('本机同屏'),
        backgroundColor: const Color(0xFF2E7D6F),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: switch (phase) {
            Phase.setup => buildSetup(),
            Phase.choosing => buildChoosing(),
            Phase.reveal => buildReveal(false),
            Phase.finished => buildReveal(true),
          },
        ),
      ),
    );
  }

  Widget buildSetup() {
    return ListView(
      children: [
        const Text('选择人数',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 2, label: Text('2人')),
            ButtonSegment(value: 3, label: Text('3人')),
            ButtonSegment(value: 4, label: Text('4人')),
            ButtonSegment(value: 5, label: Text('5人')),
          ],
          selected: {playerCount},
          onSelectionChanged: (value) => setState(() => playerCount = value.first),
        ),
        const SizedBox(height: 24),
        for (int i = 0; i < playerCount; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: nameControllers[i],
              decoration: InputDecoration(
                labelText: '玩家 ${i + 1} 名字',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: startGame,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text('开始游戏', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Widget buildChoosing() {
    final player = players[currentPlayer];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('第 $round / 9 轮',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('请 ${player.name} 出牌',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        buildSkillPanel(
          revolutionActive: revolutionRound,
          revolutionUsed: player.revolutionUsed,
          revolutionEnabled: !player.revolutionUsed && !revolutionRound,
          onRevolution: activateRevolution,
          doubleActive: player.doubleActive,
          doubleUsed: player.doubleUsed,
          doubleEnabled: !player.doubleUsed,
          onDouble: activateDouble,
          lockUsed: player.lockUsed,
          lockEnabled: !player.lockUsed,
          onLock: activateLock,
          peekUsed: player.peekUsed,
          peekEnabled: !player.peekUsed && currentPlays.isNotEmpty,
          onPeek: activatePeek,
          lockText: localLockText(),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(9, (index) {
            final card = index + 1;
            final used = player.usedCards.contains(card);
            final locked = currentLocks[currentPlayer] == card;
            final selected = selectedCard == card;

            return SizedBox(
              width: 76,
              height: 76,
              child: FilledButton(
                onPressed: used || locked
                    ? null
                    : () => setState(() => selectedCard = card),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      selected ? const Color(0xFFE09F3E) : const Color(0xFF2E7D6F),
                  disabledBackgroundColor: Colors.black12,
                ),
                child: Text('$card',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold)),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              buildCardMemoryBoard(localCardMemoryLines()),
              const SizedBox(height: 12),
              buildScoreBoard(
                players.map((p) => ScoreLine(p.name, p.score)).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: selectedCard == null ? null : confirmCard,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text('确认出牌', style: TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildReveal(bool finished) {
    final result = latestResult!;
    final sorted = [...players]..sort((a, b) => b.score.compareTo(a.score));
    final topScore = sorted.first.score;

    return ListView(
      children: [
        Text(
          finished ? '游戏结束' : '第 ${result.round} 轮结果',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (int i = 0; i < players.length; i++)
                  ListTile(
                    title: Text(players[i].name),
                    trailing:
                        Text('${result.plays[i]}', style: const TextStyle(fontSize: 24)),
                  ),
                const Divider(),
                Text('本轮分数池：${result.pool}',
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(result.reason, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  '获胜：${result.winners.map((i) => players[i].name).join('、')}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        buildScoreBoard(players.map((p) => ScoreLine(p.name, p.score)).toList()),
        const SizedBox(height: 12),
        buildCardMemoryBoard(localCardMemoryLines()),
        if (finished) ...[
          const SizedBox(height: 18),
          const Text('最终排名',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final player in sorted)
            ListTile(
              leading: Icon(player.score == topScore ? Icons.emoji_events : Icons.person),
              title: Text(player.name),
              trailing: Text(formatScore(player.score),
                  style: const TextStyle(fontSize: 18)),
            ),
          const SizedBox(height: 12),
          FilledButton(onPressed: restart, child: const Text('重新开始')),
        ] else ...[
          const SizedBox(height: 18),
          FilledButton(onPressed: nextRound, child: const Text('下一轮')),
        ],
      ],
    );
  }

  List<CardMemoryLine> localCardMemoryLines() {
    return List.generate(players.length, (playerIndex) {
      final cards = <int>[
        for (final result in history)
          if (result.plays[playerIndex] != null) result.plays[playerIndex]!,
      ]..sort();

      return CardMemoryLine(players[playerIndex].name, cards);
    });
  }

  String localLockText() {
    if (currentLocks.isEmpty) return '';
    return currentLocks.entries
        .map((entry) => '${players[entry.key].name} 不能出 ${entry.value}')
        .join('；');
  }
}

class ScoreLine {
  const ScoreLine(this.name, this.score);

  final String name;
  final double score;
}

class CardMemoryLine {
  const CardMemoryLine(this.name, this.cards);

  final String name;
  final List<int> cards;
}

Widget buildSkillPanel({
  required bool revolutionActive,
  required bool revolutionUsed,
  required bool revolutionEnabled,
  required VoidCallback onRevolution,
  required bool doubleActive,
  required bool doubleUsed,
  required bool doubleEnabled,
  required VoidCallback onDouble,
  required bool lockUsed,
  required bool lockEnabled,
  required VoidCallback onLock,
  required bool peekUsed,
  required bool peekEnabled,
  required VoidCallback onPeek,
  required String lockText,
}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('技能牌',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              buildSkillButton(
                icon: Icons.swap_vert,
                label: switch ((revolutionActive, revolutionUsed)) {
                  (true, _) => 'revolution 已启动',
                  (false, true) => 'revolution 已用',
                  _ => 'revolution',
                },
                description: '本轮改成比小',
                active: revolutionActive,
                used: revolutionUsed,
                enabled: revolutionEnabled,
                onPressed: onRevolution,
              ),
              buildSkillButton(
                icon: Icons.close_fullscreen,
                label: switch ((doubleActive, doubleUsed)) {
                  (true, _) => 'double 已启动',
                  (false, true) => 'double 已用',
                  _ => 'double',
                },
                description: '赢了得分翻倍',
                active: doubleActive,
                used: doubleUsed,
                enabled: doubleEnabled,
                onPressed: onDouble,
              ),
              buildSkillButton(
                icon: Icons.block,
                label: lockUsed ? 'lock 已用' : 'lock',
                description: '禁别人一个数字',
                active: lockText.isNotEmpty,
                used: lockUsed,
                enabled: lockEnabled,
                onPressed: onLock,
              ),
              buildSkillButton(
                icon: Icons.visibility,
                label: peekUsed ? 'peek 已用' : 'peek',
                description: '偷看已出的牌',
                active: false,
                used: peekUsed,
                enabled: peekEnabled,
                onPressed: onPeek,
              ),
            ],
          ),
          if (revolutionActive || doubleActive || lockText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (revolutionActive) '本轮比小',
                if (doubleActive) '本轮获胜得分翻倍',
                if (lockText.isNotEmpty) lockText,
              ].join('；'),
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget buildSkillButton({
  required IconData icon,
  required String label,
  required String description,
  required bool active,
  required bool used,
  required bool enabled,
  required VoidCallback onPressed,
}) {
  final color = active ? const Color(0xFFE09F3E) : const Color(0xFF2E7D6F);
  final textColor = used && !active ? Colors.black54 : color;

  return SizedBox(
    width: 156,
    child: OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        side: BorderSide(color: used && !active ? Colors.black26 : color),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        alignment: Alignment.centerLeft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            description,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.75)),
          ),
        ],
      ),
    ),
  );
}

Widget buildScoreBoard(List<ScoreLine> scores) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Text('当前分数',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final score in scores)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(score.name)),
                Text(formatScore(score.score)),
              ],
            ),
        ],
      ),
    ),
  );
}

Widget buildCardMemoryBoard(List<CardMemoryLine> lines) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('记牌器',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 86,
                    child: Text(
                      line.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: line.cards.isEmpty
                        ? const Text('还没有公开出牌',
                            style: TextStyle(color: Colors.black54))
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final card in line.cards)
                                Container(
                                  width: 30,
                                  height: 30,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE09F3E),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$card',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

String formatScore(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

enum OnlinePhase { lobby, choosing, reveal, finished }

class OnlinePlayer {
  OnlinePlayer({
    required this.id,
    required this.name,
    this.score = 0,
    this.revolutionUsed = false,
    this.doubleUsed = false,
    this.doubleActive = false,
    this.lockUsed = false,
    this.peekUsed = false,
    this.lossStreak = 0,
    Set<int>? usedCards,
  }) : usedCards = usedCards ?? {};

  final String id;
  final String name;
  double score;
  bool revolutionUsed;
  bool doubleUsed;
  bool doubleActive;
  bool lockUsed;
  bool peekUsed;
  int lossStreak;
  final Set<int> usedCards;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'score': score,
        'revolutionUsed': revolutionUsed,
        'doubleUsed': doubleUsed,
        'doubleActive': doubleActive,
        'lockUsed': lockUsed,
        'peekUsed': peekUsed,
        'lossStreak': lossStreak,
        'usedCards': usedCards.toList(),
      };

  factory OnlinePlayer.fromJson(Map<String, dynamic> json) {
    return OnlinePlayer(
      id: json['id'] as String,
      name: json['name'] as String,
      score: (json['score'] as num).toDouble(),
      revolutionUsed: (json['revolutionUsed'] as bool?) ?? false,
      doubleUsed: (json['doubleUsed'] as bool?) ?? false,
      doubleActive: (json['doubleActive'] as bool?) ?? false,
      lockUsed: (json['lockUsed'] as bool?) ?? false,
      peekUsed: (json['peekUsed'] as bool?) ?? false,
      lossStreak: (json['lossStreak'] as int?) ?? 0,
      usedCards:
          ((json['usedCards'] as List<dynamic>?) ?? []).map((item) => item as int).toSet(),
    );
  }
}

class OnlineRoundResult {
  OnlineRoundResult({
    required this.round,
    required this.plays,
    required this.pool,
    required this.winnerIds,
    required this.reason,
    required this.revolution,
  });

  final int round;
  final Map<String, int> plays;
  final int pool;
  final List<String> winnerIds;
  final String reason;
  final bool revolution;

  Map<String, dynamic> toJson() => {
        'round': round,
        'plays': plays,
        'pool': pool,
        'winnerIds': winnerIds,
        'reason': reason,
        'revolution': revolution,
      };

  factory OnlineRoundResult.fromJson(Map<String, dynamic> json) {
    return OnlineRoundResult(
      round: json['round'] as int,
      plays: Map<String, int>.from(json['plays'] as Map),
      pool: json['pool'] as int,
      winnerIds: List<String>.from(json['winnerIds'] as List),
      reason: json['reason'] as String,
      revolution: (json['revolution'] as bool?) ?? false,
    );
  }
}

class OnlineRoomState {
  OnlineRoomState({
    required this.phase,
    required this.playerCount,
    required this.players,
    this.round = 1,
    this.currentPlayerIndex = 0,
    this.lastSingleWinnerId,
    this.revolutionRound = false,
    Map<String, int>? currentPlays,
    Map<String, int>? lockedCards,
    this.latestResult,
  })  : currentPlays = currentPlays ?? {},
        lockedCards = lockedCards ?? {};

  OnlinePhase phase;
  int playerCount;
  int round;
  int currentPlayerIndex;
  String? lastSingleWinnerId;
  bool revolutionRound;
  List<OnlinePlayer> players;
  Map<String, int> currentPlays;
  Map<String, int> lockedCards;
  OnlineRoundResult? latestResult;

  Map<String, dynamic> toJson() => {
        'phase': phase.name,
        'playerCount': playerCount,
        'round': round,
        'currentPlayerIndex': currentPlayerIndex,
        'lastSingleWinnerId': lastSingleWinnerId,
        'revolutionRound': revolutionRound,
        'players': players.map((player) => player.toJson()).toList(),
        'currentPlays': currentPlays,
        'lockedCards': lockedCards,
        'latestResult': latestResult?.toJson(),
      };

  factory OnlineRoomState.fromJson(Map<String, dynamic> json) {
    return OnlineRoomState(
      phase: OnlinePhase.values.byName(json['phase'] as String),
      playerCount: json['playerCount'] as int,
      round: json['round'] as int,
      currentPlayerIndex: json['currentPlayerIndex'] as int,
      lastSingleWinnerId: json['lastSingleWinnerId'] as String?,
      revolutionRound: (json['revolutionRound'] as bool?) ?? false,
      players: (json['players'] as List<dynamic>)
          .map((item) => OnlinePlayer.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      currentPlays: Map<String, int>.from(json['currentPlays'] as Map),
      lockedCards: Map<String, int>.from((json['lockedCards'] as Map?) ?? {}),
      latestResult: json['latestResult'] == null
          ? null
          : OnlineRoundResult.fromJson(
              Map<String, dynamic>.from(json['latestResult'] as Map),
            ),
    );
  }
}

class OnlineLobbyPage extends StatefulWidget {
  const OnlineLobbyPage({super.key, required this.onlineEnabled});

  final bool onlineEnabled;

  @override
  State<OnlineLobbyPage> createState() => _OnlineLobbyPageState();
}

class _OnlineLobbyPageState extends State<OnlineLobbyPage> {
  final nameController = TextEditingController(text: '玩家');
  final roomController = TextEditingController();
  int playerCount = 3;

  void createRoom() {
    final roomCode = makeRoomCode();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnlineGamePage(
          roomCode: roomCode,
          playerName: cleanName(),
          playerCount: playerCount,
          isHost: true,
        ),
      ),
    );
  }

  void joinRoom() {
    final roomCode = roomController.text.trim().toUpperCase();
    if (roomCode.isEmpty) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnlineGamePage(
          roomCode: roomCode,
          playerName: cleanName(),
          playerCount: playerCount,
          isHost: false,
        ),
      ),
    );
  }

  String cleanName() {
    final name = nameController.text.trim();
    return name.isEmpty ? '玩家' : name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      appBar: AppBar(
        title: const Text('线上房间'),
        backgroundColor: const Color(0xFF2E7D6F),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ListView(
            children: [
              if (!widget.onlineEnabled) ...[
                const Text(
                  '还差一步配置',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  '线上房间需要 Supabase。创建项目后，用 SUPABASE_URL 和 SUPABASE_KEY 运行这个 App。',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 18),
              ],
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '你的名字',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              const Text('创建房间人数',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 2, label: Text('2人')),
                  ButtonSegment(value: 3, label: Text('3人')),
                  ButtonSegment(value: 4, label: Text('4人')),
                  ButtonSegment(value: 5, label: Text('5人')),
                ],
                selected: {playerCount},
                onSelectionChanged: (value) => setState(() => playerCount = value.first),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: widget.onlineEnabled ? createRoom : null,
                icon: const Icon(Icons.add),
                label: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('创建房间', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: roomController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: '输入房间码',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.onlineEnabled ? joinRoom : null,
                icon: const Icon(Icons.login),
                label: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('加入房间', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnlineGamePage extends StatefulWidget {
  const OnlineGamePage({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.playerCount,
    required this.isHost,
  });

  final String roomCode;
  final String playerName;
  final int playerCount;
  final bool isHost;

  @override
  State<OnlineGamePage> createState() => _OnlineGamePageState();
}

class _OnlineGamePageState extends State<OnlineGamePage> {
  late final String playerId;
  late final RealtimeChannel channel;
  OnlineRoomState? room;
  String connectionStatus = '连接中';
  int? selectedCard;

  bool get isHost => widget.isHost;

  int get myIndex =>
      room?.players.indexWhere((player) => player.id == playerId) ?? -1;

  bool get isMyTurn =>
      room?.phase == OnlinePhase.choosing && myIndex == room?.currentPlayerIndex;

  @override
  void initState() {
    super.initState();
    playerId = '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(999999)}';
    channel = Supabase.instance.client.channel(
      'number-battle:${widget.roomCode}',
      opts: const RealtimeChannelConfig(self: false, ack: true),
    );

    channel
        .onBroadcast(event: 'join', callback: handleJoin)
        .onBroadcast(event: 'state', callback: handleState)
        .onBroadcast(event: 'submit_card', callback: handleSubmitCard)
        .onBroadcast(event: 'revolution', callback: handleRevolution)
        .onBroadcast(event: 'skill', callback: handleSkill)
        .onBroadcast(event: 'next_round', callback: handleNextRound)
        .onBroadcast(event: 'state_request', callback: handleStateRequest)
        .subscribe((status, error) {
      setState(() {
        connectionStatus = status.name;
      });

      if (status == RealtimeSubscribeStatus.subscribed) {
        if (isHost) {
          room = OnlineRoomState(
            phase: OnlinePhase.lobby,
            playerCount: widget.playerCount,
            players: [
              OnlinePlayer(id: playerId, name: widget.playerName),
            ],
          );
          broadcastState();
        } else {
          send('join', {'id': playerId, 'name': widget.playerName});
          send('state_request', {'id': playerId});
        }
      }
    });
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(channel);
    super.dispose();
  }

  void handleJoin(Map<String, dynamic> payload) {
    if (!isHost || room == null || room!.phase != OnlinePhase.lobby) return;

    final id = payload['id'] as String?;
    final name = payload['name'] as String?;
    if (id == null || name == null) return;
    if (room!.players.any((player) => player.id == id)) return;
    if (room!.players.length >= room!.playerCount) return;

    setState(() {
      room!.players.add(OnlinePlayer(id: id, name: name));
    });
    broadcastState();
  }

  void handleState(Map<String, dynamic> payload) {
    final state = payload['state'];
    if (state is! Map) return;

    setState(() {
      room = OnlineRoomState.fromJson(Map<String, dynamic>.from(state));
      selectedCard = null;
    });
  }

  void handleSubmitCard(Map<String, dynamic> payload) {
    if (!isHost || room == null || room!.phase != OnlinePhase.choosing) return;

    final id = payload['id'] as String?;
    final card = payload['card'] as int?;
    if (id == null || card == null) return;

    final playerIndex = room!.players.indexWhere((player) => player.id == id);
    if (playerIndex != room!.currentPlayerIndex) return;

    final player = room!.players[playerIndex];
    if (player.usedCards.contains(card)) return;
    if (room!.lockedCards[player.id] == card) return;

    player.usedCards.add(card);
    room!.currentPlays[player.id] = card;

    if (room!.currentPlayerIndex < room!.players.length - 1) {
      room!.currentPlayerIndex++;
    } else {
      finishOnlineRound();
    }

    setState(() {});
    broadcastState();
  }

  void handleRevolution(Map<String, dynamic> payload) {
    if (!isHost || room == null || room!.phase != OnlinePhase.choosing) return;

    final id = payload['id'] as String?;
    if (id == null || room!.revolutionRound) return;

    final playerIndex = room!.players.indexWhere((player) => player.id == id);
    if (playerIndex != room!.currentPlayerIndex) return;

    final player = room!.players[playerIndex];
    if (player.revolutionUsed) return;

    setState(() {
      player.revolutionUsed = true;
      room!.revolutionRound = true;
    });
    broadcastState();
  }

  void handleSkill(Map<String, dynamic> payload) {
    if (!isHost || room == null || room!.phase != OnlinePhase.choosing) return;

    final id = payload['id'] as String?;
    final type = payload['type'] as String?;
    if (id == null || type == null) return;

    final playerIndex = room!.players.indexWhere((player) => player.id == id);
    if (playerIndex != room!.currentPlayerIndex) return;

    final player = room!.players[playerIndex];

    switch (type) {
      case 'revolution':
        if (player.revolutionUsed || room!.revolutionRound) return;
        player.revolutionUsed = true;
        room!.revolutionRound = true;
        break;
      case 'double':
        if (player.doubleUsed || player.doubleActive) return;
        player.doubleUsed = true;
        player.doubleActive = true;
        break;
      case 'lock':
        final targetId = payload['targetId'] as String?;
        final card = payload['card'] as int?;
        if (targetId == null || card == null) return;
        if (player.lockUsed || targetId == id || card < 1 || card > 9) return;
        if (room!.currentPlays.containsKey(targetId)) return;
        final targetIndex = room!.players.indexWhere((item) => item.id == targetId);
        if (targetIndex == -1 || room!.players[targetIndex].usedCards.contains(card)) {
          return;
        }
        player.lockUsed = true;
        room!.lockedCards[targetId] = card;
        break;
      case 'peek':
        final targetId = payload['targetId'] as String?;
        if (targetId == null) return;
        if (player.peekUsed || !room!.currentPlays.containsKey(targetId)) return;
        player.peekUsed = true;
        break;
      default:
        return;
    }

    setState(() {});
    broadcastState();
  }

  void handleNextRound(Map<String, dynamic> payload) {
    if (!isHost || room == null || room!.phase != OnlinePhase.reveal) return;
    startNextOnlineRound();
  }

  void handleStateRequest(Map<String, dynamic> payload) {
    if (isHost && room != null) {
      broadcastState();
    }
  }

  Future<void> send(String event, Map<String, dynamic> payload) async {
    await channel.sendBroadcastMessage(event: event, payload: payload);
  }

  Future<void> broadcastState() async {
    if (room == null) return;
    await send('state', {'state': room!.toJson()});
  }

  void startOnlineGame() {
    if (!isHost || room == null) return;
    if (room!.players.length != room!.playerCount) return;

    setState(() {
      room!.phase = OnlinePhase.choosing;
      room!.round = 1;
      room!.currentPlayerIndex = 0;
      room!.currentPlays.clear();
      room!.lockedCards.clear();
      room!.latestResult = null;
      room!.lastSingleWinnerId = null;
      room!.revolutionRound = false;
    });
    broadcastState();
  }

  void activateOnlineRevolution() {
    final me = myIndex >= 0 ? room!.players[myIndex] : null;
    if (!isMyTurn || me == null) return;
    if (me.revolutionUsed || room!.revolutionRound) return;

    final payload = {'id': playerId, 'type': 'revolution'};
    if (isHost) {
      handleSkill(payload);
    } else {
      send('skill', payload);
    }
  }

  void activateOnlineDouble() {
    final me = myIndex >= 0 ? room!.players[myIndex] : null;
    if (!isMyTurn || me == null || me.doubleUsed) return;

    final payload = {'id': playerId, 'type': 'double'};
    if (isHost) {
      handleSkill(payload);
    } else {
      send('skill', payload);
    }
  }

  Future<void> activateOnlineLock() async {
    final me = myIndex >= 0 ? room!.players[myIndex] : null;
    if (!isMyTurn || me == null || me.lockUsed) return;

    final targets = [
      for (final player in room!.players)
        if (player.id != playerId && !room!.currentPlays.containsKey(player.id)) player,
    ];
    if (targets.isEmpty) {
      showOnlineMessage('没有可以锁定的玩家');
      return;
    }

    var targetId = targets.first.id;
    var card = 9;
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('lock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: targetId,
                decoration: const InputDecoration(labelText: '锁定玩家'),
                items: [
                  for (final player in targets)
                    DropdownMenuItem(value: player.id, child: Text(player.name)),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => targetId = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: card,
                decoration: const InputDecoration(labelText: '禁止数字'),
                items: [
                  for (int i = 1; i <= 9; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => card = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop((targetId, card)),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final payload = {
      'id': playerId,
      'type': 'lock',
      'targetId': result.$1,
      'card': result.$2,
    };
    if (isHost) {
      handleSkill(payload);
    } else {
      send('skill', payload);
    }
  }

  Future<void> activateOnlinePeek() async {
    final me = myIndex >= 0 ? room!.players[myIndex] : null;
    if (!isMyTurn || me == null || me.peekUsed) return;

    final targets = [
      for (final player in room!.players)
        if (room!.currentPlays.containsKey(player.id)) player,
    ];
    if (targets.isEmpty) {
      showOnlineMessage('本轮还没有可偷看的牌');
      return;
    }

    var targetId = targets.first.id;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('peek'),
          content: DropdownButtonFormField<String>(
            initialValue: targetId,
            decoration: const InputDecoration(labelText: '偷看玩家'),
            items: [
              for (final player in targets)
                DropdownMenuItem(value: player.id, child: Text(player.name)),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => targetId = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(targetId),
              child: const Text('偷看'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    if (!mounted) return;
    final target = room!.players.firstWhere((player) => player.id == result);
    final card = room!.currentPlays[result];

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('peek 结果'),
        content: Text(
          '${target.name} 本轮出了 $card',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );

    final payload = {'id': playerId, 'type': 'peek', 'targetId': result};
    if (isHost) {
      handleSkill(payload);
    } else {
      send('skill', payload);
    }
  }

  void showOnlineMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void submitSelectedCard() {
    if (!isMyTurn || selectedCard == null) return;

    final payload = {'id': playerId, 'card': selectedCard};
    if (isHost) {
      handleSubmitCard(payload);
    } else {
      send('submit_card', payload);
    }
  }

  void finishOnlineRound() {
    final currentRoom = room!;
    final pool =
        currentRoom.currentPlays.values.fold<int>(0, (sum, card) => sum + card);
    final values = currentRoom.currentPlays.values.toList();
    final hasOne = values.contains(1);
    final hasNine = values.contains(9);

    int targetNumber;
    String reason;

    if (hasOne && hasNine) {
      targetNumber = currentRoom.revolutionRound ? 9 : 1;
      reason = currentRoom.revolutionRound
          ? 'revolution！场上同时出现 1 和 9，本轮 9 获胜'
          : '场上同时出现 1 和 9，本轮 1 获胜';
    } else {
      targetNumber = currentRoom.revolutionRound
          ? values.reduce((a, b) => a < b ? a : b)
          : values.reduce((a, b) => a > b ? a : b);
      reason = currentRoom.revolutionRound
          ? 'revolution！本轮最小数字是 $targetNumber'
          : '本轮最大数字是 $targetNumber';
    }

    final candidates = currentRoom.currentPlays.entries
        .where((entry) => entry.value == targetNumber)
        .map((entry) => entry.key)
        .toList();

    List<String> winnerIds;
    if (candidates.length == 1) {
      winnerIds = candidates;
    } else if (currentRoom.lastSingleWinnerId != null &&
        candidates.contains(currentRoom.lastSingleWinnerId)) {
      winnerIds = [currentRoom.lastSingleWinnerId!];
      reason = '$reason；多人同为目标数字，上一轮胜者优先';
    } else {
      winnerIds = candidates;
      reason = '$reason；多人同为目标数字，上一轮无可用胜者，平分分数';
    }

    final gain = pool / winnerIds.length;
    final notes = <String>[];
    for (final winnerId in winnerIds) {
      final winner = currentRoom.players.firstWhere((player) => player.id == winnerId);
      final multiplier = winner.doubleActive ? 2 : 1;
      winner.score += gain * multiplier;
      if (multiplier == 2) {
        notes.add('double：${winner.name} 得分翻倍');
      }
    }

    final compensation = <String>[];
    for (final player in currentRoom.players) {
      if (winnerIds.contains(player.id)) {
        player.lossStreak = 0;
      } else {
        player.lossStreak++;
        if (player.lossStreak >= 2) {
          player.score += 2;
          compensation.add('${player.name} +2');
        }
      }
      player.doubleActive = false;
    }
    if (compensation.isNotEmpty) {
      notes.add('连输补偿：${compensation.join('、')}');
    }

    currentRoom.lastSingleWinnerId = winnerIds.length == 1 ? winnerIds.first : null;
    currentRoom.latestResult = OnlineRoundResult(
      round: currentRoom.round,
      plays: Map<String, int>.from(currentRoom.currentPlays),
      pool: pool,
      winnerIds: winnerIds,
      reason: notes.isEmpty ? reason : '$reason；${notes.join('；')}',
      revolution: currentRoom.revolutionRound,
    );
    currentRoom.currentPlays.clear();
    currentRoom.lockedCards.clear();
    currentRoom.phase =
        currentRoom.round == 9 ? OnlinePhase.finished : OnlinePhase.reveal;
  }

  void startNextOnlineRound() {
    setState(() {
      room!.round++;
      room!.currentPlayerIndex = 0;
      room!.phase = OnlinePhase.choosing;
      room!.revolutionRound = false;
      room!.lockedCards.clear();
      selectedCard = null;
    });
    broadcastState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      appBar: AppBar(
        title: Text('房间 ${widget.roomCode}'),
        backgroundColor: const Color(0xFF2E7D6F),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: room == null
              ? Center(child: Text(connectionStatus))
              : switch (room!.phase) {
                  OnlinePhase.lobby => buildOnlineLobby(),
                  OnlinePhase.choosing => buildOnlineChoosing(),
                  OnlinePhase.reveal => buildOnlineReveal(false),
                  OnlinePhase.finished => buildOnlineReveal(true),
                },
        ),
      ),
    );
  }

  Widget buildOnlineLobby() {
    return ListView(
      children: [
        SelectableText(
          '房间码：${widget.roomCode}',
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text('连接状态：$connectionStatus'),
        const SizedBox(height: 18),
        Text('玩家 ${room!.players.length} / ${room!.playerCount}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final player in room!.players)
          ListTile(
            leading: Icon(player.id == playerId ? Icons.person_pin : Icons.person),
            title: Text(player.name),
          ),
        const SizedBox(height: 18),
        if (isHost)
          FilledButton(
            onPressed:
                room!.players.length == room!.playerCount ? startOnlineGame : null,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text('开始线上游戏', style: TextStyle(fontSize: 18)),
            ),
          )
        else
          const Text('等待房主开始游戏', style: TextStyle(fontSize: 18)),
      ],
    );
  }

  Widget buildOnlineChoosing() {
    final activePlayer = room!.players[room!.currentPlayerIndex];
    final me = myIndex >= 0 ? room!.players[myIndex] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('第 ${room!.round} / 9 轮',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          isMyTurn ? '轮到你出牌' : '等待 ${activePlayer.name} 出牌',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        buildSkillPanel(
          revolutionActive: room!.revolutionRound,
          revolutionUsed: me?.revolutionUsed ?? true,
          revolutionEnabled: isMyTurn &&
              me != null &&
              !me.revolutionUsed &&
              !room!.revolutionRound,
          onRevolution: activateOnlineRevolution,
          doubleActive: me?.doubleActive ?? false,
          doubleUsed: me?.doubleUsed ?? true,
          doubleEnabled: isMyTurn && me != null && !me.doubleUsed,
          onDouble: activateOnlineDouble,
          lockUsed: me?.lockUsed ?? true,
          lockEnabled: isMyTurn && me != null && !me.lockUsed,
          onLock: activateOnlineLock,
          peekUsed: me?.peekUsed ?? true,
          peekEnabled: isMyTurn &&
              me != null &&
              !me.peekUsed &&
              room!.currentPlays.isNotEmpty,
          onPeek: activateOnlinePeek,
          lockText: onlineLockText(),
        ),
        const SizedBox(height: 18),
        if (me != null)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(9, (index) {
              final card = index + 1;
              final used = me.usedCards.contains(card);
              final locked = room!.lockedCards[me.id] == card;
              final selected = selectedCard == card;
              return SizedBox(
                width: 76,
                height: 76,
                child: FilledButton(
                  onPressed: isMyTurn && !used && !locked
                      ? () => setState(() => selectedCard = card)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: selected
                        ? const Color(0xFFE09F3E)
                        : const Color(0xFF2E7D6F),
                    disabledBackgroundColor: Colors.black12,
                  ),
                  child: Text('$card',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                ),
              );
            }),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              buildCardMemoryBoard(onlineCardMemoryLines(includeCurrentRound: false)),
              const SizedBox(height: 12),
              buildScoreBoard(
                room!.players.map((p) => ScoreLine(p.name, p.score)).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isMyTurn && selectedCard != null ? submitSelectedCard : null,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text('提交出牌', style: TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildOnlineReveal(bool finished) {
    final result = room!.latestResult!;
    final sorted = [...room!.players]..sort((a, b) => b.score.compareTo(a.score));
    final topScore = sorted.first.score;

    return ListView(
      children: [
        Text(
          finished ? '游戏结束' : '第 ${result.round} 轮结果',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final player in room!.players)
                  ListTile(
                    title: Text(player.name),
                    trailing: Text('${result.plays[player.id]}',
                        style: const TextStyle(fontSize: 24)),
                  ),
                const Divider(),
                Text('本轮分数池：${result.pool}',
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text(result.reason, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  '获胜：${result.winnerIds.map(playerNameById).join('、')}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        buildScoreBoard(
          room!.players.map((p) => ScoreLine(p.name, p.score)).toList(),
        ),
        const SizedBox(height: 12),
        buildCardMemoryBoard(onlineCardMemoryLines(includeCurrentRound: true)),
        if (finished) ...[
          const SizedBox(height: 18),
          const Text('最终排名',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final player in sorted)
            ListTile(
              leading: Icon(player.score == topScore ? Icons.emoji_events : Icons.person),
              title: Text(player.name),
              trailing: Text(formatScore(player.score),
                  style: const TextStyle(fontSize: 18)),
            ),
        ] else ...[
          const SizedBox(height: 18),
          FilledButton(
            onPressed: isHost
                ? startNextOnlineRound
                : () => send('next_round', {'id': playerId}),
            child: Text(isHost ? '下一轮' : '请求下一轮'),
          ),
        ],
      ],
    );
  }

  String playerNameById(String id) {
    return room!.players.firstWhere((player) => player.id == id).name;
  }

  List<CardMemoryLine> onlineCardMemoryLines({required bool includeCurrentRound}) {
    return [
      for (final player in room!.players)
        CardMemoryLine(
          player.name,
          (player.usedCards
                .where((card) =>
                    includeCurrentRound || room!.currentPlays[player.id] != card)
                .toList()
            ..sort()),
        ),
    ];
  }

  String onlineLockText() {
    if (room!.lockedCards.isEmpty) return '';
    return room!.lockedCards.entries
        .map((entry) => '${playerNameById(entry.key)} 不能出 ${entry.value}')
        .join('；');
  }
}

String makeRoomCode() {
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random();
  return List.generate(5, (_) => letters[random.nextInt(letters.length)]).join();
}

