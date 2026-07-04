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

const skillDeck = [
  'revolution',
  'double',
  'lock',
  'peek',
  'ambush',
  'mirror',
  'tax',
  'insurance',
  'silence',
  'chaos',
  'last_word',
];

const skillsThatNeedLaterPlayers = {'lock'};
const skillsThatNeedEarlierPlayers = {'peek'};

const skillDefinitions = {
  'revolution': SkillDefinition(
    id: 'revolution',
    name: 'revolution',
    description: '本轮改成比小',
    detail: '本轮结算规则反转，数字最小的人赢分。特殊规则仍保留：如果场上同时有 1 和 9，revolution 状态下改成 9 赢。',
    icon: Icons.swap_vert,
  ),
  'double': SkillDefinition(
    id: 'double',
    name: 'double',
    description: '赢了得分翻倍',
    detail: '只影响自己。本轮如果你成为赢家，你拿到的分数翻倍；如果没赢，这张技能不会补偿分数。',
    icon: Icons.close_fullscreen,
  ),
  'lock': SkillDefinition(
    id: 'lock',
    name: 'lock',
    description: '禁别人一个数字',
    detail: '选择一个还没出牌的对手，并禁止他本轮打出一个指定数字。已经出过牌的人不能被锁；第9轮不能使用。',
    icon: Icons.block,
  ),
  'peek': SkillDefinition(
    id: 'peek',
    name: 'peek',
    description: '偷看已出的牌',
    detail: '查看一个本轮已经出牌玩家的数字。适合后手判断当前局势，决定要不要用 revolution、double 或其他技能。',
    icon: Icons.visibility,
  ),
  'ambush': SkillDefinition(
    id: 'ambush',
    name: 'ambush',
    description: '猜中后抢对方分',
    detail:
        '选择一个对手并猜他本轮会出的数字。猜中就从他身上抢分，最多抢到他 0 分为止：第1-2轮抢4分，第3-4轮抢3分，第5-6轮抢2分，第7-8轮抢1分，第9轮不能使用。',
    icon: Icons.radar,
  ),
  'mirror': SkillDefinition(
    id: 'mirror',
    name: 'mirror',
    description: '点数变成 10-x',
    detail: '只改变你本轮这张牌的结算点数：1 变 9、2 变 8、5 还是 5、9 变 1。分数池仍按大家实际出的牌计算。',
    icon: Icons.flip,
  ),
  'tax': SkillDefinition(
    id: 'tax',
    name: 'tax',
    description: '从赢家拿 2 分',
    detail:
        '本轮结算后，如果别人赢了，你从每个赢家那里拿分；2人局每个赢家拿5分，3人局拿2分，4-5人局拿1分。如果你自己就是赢家，不会从自己身上拿分。',
    icon: Icons.account_balance,
  ),
  'insurance': SkillDefinition(
    id: 'insurance',
    name: 'insurance',
    description: '没赢时递减加分',
    detail: '本轮如果你没有赢，结算时额外加分。第1次使用+5，第2次使用+3，第3次使用+1；无论是否成功触发都消耗次数，最多使用3次。',
    icon: Icons.health_and_safety,
  ),
  'silence': SkillDefinition(
    id: 'silence',
    name: 'silence',
    description: '本轮全部技能失效',
    detail: '发动后，本轮所有人已经启动的技能效果全部失效，包括自己的；之后本轮也不能再发动技能。每张技能牌一局仍然只能使用一次。',
    icon: Icons.volume_off,
  ),
  'chaos': SkillDefinition(
    id: 'chaos',
    name: 'chaos',
    description: '每张牌随机 -1/0/+1',
    detail: '本轮结算时，每个人出的牌点数都会随机 -1、不变或 +1，最低不低于 1，最高不超过 9。适合打乱大小判断。',
    icon: Icons.casino,
  ),
  'snipe': SkillDefinition(
    id: 'snipe',
    name: 'snipe',
    description: '猜中某人 +5',
    detail: '选择一个对手并猜他本轮会出的数字。结算时如果猜中，你额外 +5 分，不要求你赢本轮。',
    icon: Icons.center_focus_strong,
  ),
  'last_word': SkillDefinition(
    id: 'last_word',
    name: 'last word',
    description: '并列时优先赢',
    detail: '只影响自己。本轮如果你和别人并列成为目标数字，优先判定你单独获胜；如果发动成功，可以再次使用这张技能。',
    icon: Icons.record_voice_over,
  ),
};

class SkillDefinition {
  const SkillDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.detail,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final String detail;
  final IconData icon;
}

List<String> drawSkillHand(Random random) {
  final deck = [...skillDeck]..shuffle(random);
  return deck.take(3).toList();
}

bool hasAnySkill(List<String> hand, Set<String> skillIds) {
  return hand.any(skillIds.contains);
}

int ambushBonusForRound(int round) {
  if (round <= 2) return 4;
  if (round <= 4) return 3;
  if (round <= 6) return 2;
  if (round <= 8) return 1;
  return 0;
}

int taxAmountForPlayerCount(int count) {
  if (count <= 2) return 5;
  if (count == 3) return 2;
  return 1;
}

int insuranceBonusForUse(int useCount) {
  return switch (useCount) {
    1 => 5,
    2 => 3,
    3 => 1,
    _ => 0,
  };
}

List<int> makeFairTurnOrder({
  required int count,
  required bool Function(int index) avoidsFirst,
  required bool Function(int index) avoidsLast,
  Random? random,
}) {
  final randomizer = random ?? Random();
  if (count <= 1) return List.generate(count, (index) => index);

  final firstCandidates = [
    for (var index = 0; index < count; index++)
      if (!avoidsFirst(index)) index,
  ]..shuffle(randomizer);
  final lastCandidates = [
    for (var index = 0; index < count; index++)
      if (!avoidsLast(index)) index,
  ]..shuffle(randomizer);

  for (final first in firstCandidates) {
    for (final last in lastCandidates) {
      if (first == last) continue;
      final middle = [
        for (var index = 0; index < count; index++)
          if (index != first && index != last) index,
      ]..shuffle(randomizer);
      return [first, ...middle, last];
    }
  }

  return List.generate(count, (index) => index)..shuffle(randomizer);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (hasSupabaseConfig) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
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
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const GamePage())),
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
                    builder: (_) =>
                        OnlineLobbyPage(onlineEnabled: onlineEnabled),
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
  List<String> skillHand = [];
  final Set<String> usedSkills = {};
  bool doubleActive = false;
  bool mirrorActive = false;
  bool taxActive = false;
  bool insuranceActive = false;
  int insuranceUses = 0;
  int insuranceBonus = 0;
  bool anchorActive = false;
  bool lastWordActive = false;
  bool lastWordAttemptedThisRound = false;
  int? ambushTargetIndex;
  int? ambushNumber;
  int ambushBonus = 0;
  int? snipeTargetIndex;
  int? snipeNumber;
  int loanDebtRounds = 0;
  int loanStartRound = 0;
  int lossStreak = 0;
  int skillRefreshTokens = 0;

  bool get shouldAvoidFirst =>
      hasAnySkill(skillHand, skillsThatNeedEarlierPlayers);

  bool get shouldAvoidLast =>
      hasAnySkill(skillHand, skillsThatNeedLaterPlayers);

  void resetForNewGame(Random random) {
    score = 0;
    usedCards.clear();
    skillHand = drawSkillHand(random);
    usedSkills.clear();
    doubleActive = false;
    mirrorActive = false;
    taxActive = false;
    insuranceActive = false;
    insuranceUses = 0;
    insuranceBonus = 0;
    anchorActive = false;
    lastWordActive = false;
    lastWordAttemptedThisRound = false;
    ambushTargetIndex = null;
    ambushNumber = null;
    ambushBonus = 0;
    snipeTargetIndex = null;
    snipeNumber = null;
    loanDebtRounds = 0;
    loanStartRound = 0;
    lossStreak = 0;
    skillRefreshTokens = 0;
  }
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
  List<int> turnOrder = [];
  int turnPosition = 0;
  int? selectedCard;
  int? lastSingleWinner;
  bool revolutionRound = false;
  bool defenseRound = false;
  int? revolutionOwner;
  final Map<int, int> currentLocks = {};
  final Map<int, int> currentLockOwners = {};
  final Set<int> currentSilenced = {};
  final Map<int, int> currentSilenceOwners = {};
  final Map<int, int> currentChaosDeltas = {};
  int currentChaosDelta = 0;

  final nameControllers = List.generate(
    5,
    (index) => TextEditingController(text: '玩家${index + 1}'),
  );

  List<Player> players = [];
  final Map<int, int> currentPlays = {};
  final List<RoundResult> history = [];
  RoundResult? latestResult;

  int get currentPlayer {
    if (turnOrder.isEmpty) return 0;
    final position = turnPosition.clamp(0, turnOrder.length - 1).toInt();
    return turnOrder[position];
  }

  void resetLocalTurnOrder() {
    turnOrder = makeFairTurnOrder(
      count: players.length,
      avoidsFirst: (index) => players[index].shouldAvoidFirst,
      avoidsLast: (index) => players[index].shouldAvoidLast,
    );
    turnPosition = 0;
  }

  String localTurnOrderText() {
    if (turnOrder.isEmpty) return '';
    return turnOrder.map((index) => players[index].name).join(' → ');
  }

  void startGame() {
    final random = Random();
    players = List.generate(playerCount, (index) {
      final player = Player(
        nameControllers[index].text.trim().isEmpty
            ? '玩家${index + 1}'
            : nameControllers[index].text.trim(),
      );
      player.skillHand = drawSkillHand(random);
      return player;
    });

    setState(() {
      phase = Phase.choosing;
      round = 1;
      resetLocalTurnOrder();
      selectedCard = null;
      lastSingleWinner = null;
      revolutionRound = false;
      defenseRound = false;
      revolutionOwner = null;
      currentLocks.clear();
      currentLockOwners.clear();
      currentSilenced.clear();
      currentSilenceOwners.clear();
      currentChaosDeltas.clear();
      currentChaosDelta = 0;
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
      if (turnPosition < turnOrder.length - 1) {
        turnPosition++;
      } else {
        finishRound();
      }
    });
  }

  void finishRound() {
    final notes = <String>[];
    final effectivePlays = <int, int>{};
    for (final entry in currentPlays.entries) {
      final player = players[entry.key];
      final value = player.mirrorActive ? 10 - entry.value : entry.value;
      effectivePlays[entry.key] = value;
      if (player.mirrorActive) {
        notes.add('mirror：${player.name} 的 ${entry.value} 变成 $value');
      }
    }

    if (currentChaosDeltas.isNotEmpty) {
      final random = Random();
      final chaosNotes = <String>[];
      for (final playerIndex in effectivePlays.keys.toList()) {
        final oldValue = effectivePlays[playerIndex]!;
        final delta = random.nextInt(3) - 1;
        final newValue = (oldValue + delta).clamp(1, 9).toInt();
        effectivePlays[playerIndex] = newValue;
        chaosNotes.add('${players[playerIndex].name} $oldValue→$newValue');
      }
      notes.add('chaos：${chaosNotes.join('、')}');
    }

    final rawPool = effectivePlays.values.fold<int>(
      0,
      (sum, card) => sum + card,
    );
    final pool = max(0, rawPool);

    final values = effectivePlays.values.toList();
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

    final candidates = effectivePlays.entries
        .where((entry) => entry.value == targetNumber)
        .map((entry) => entry.key)
        .toList();
    if (candidates.length > 1) {
      for (final index in candidates) {
        if (players[index].lastWordAttemptedThisRound) {
          players[index].usedSkills.remove('last_word');
        }
      }
    }

    List<int> winners;

    final lastWordCandidates = candidates
        .where((index) => players[index].lastWordActive)
        .toList();
    if (lastWordCandidates.isNotEmpty) {
      winners = [lastWordCandidates.first];
      reason = '$reason；last word：${players[winners.first].name} 并列优先';
      players[winners.first].usedSkills.remove('last_word');
    } else if (candidates.length == 1) {
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
    for (final winner in winners) {
      final multiplier = players[winner].doubleActive ? 2 : 1;
      players[winner].score += gain * multiplier;
      if (multiplier == 2) {
        notes.add('double：${players[winner].name} 得分翻倍');
      }
    }

    for (int i = 0; i < players.length; i++) {
      final player = players[i];
      if (player.ambushNumber != null &&
          player.ambushTargetIndex != null &&
          currentPlays[player.ambushTargetIndex] == player.ambushNumber) {
        final target = players[player.ambushTargetIndex!];
        final steal = min(
          player.ambushBonus.toDouble(),
          max(0.0, target.score),
        );
        target.score -= steal;
        player.score += steal;
        notes.add(
          'ambush：${player.name} 从 ${target.name} 抢 ${formatScore(steal)} 分',
        );
      }

      if (player.snipeTargetIndex != null &&
          player.snipeNumber != null &&
          currentPlays[player.snipeTargetIndex] == player.snipeNumber) {
        player.score += 5;
        notes.add('snipe：${player.name} +5');
      }

      if (player.insuranceActive && !winners.contains(i)) {
        player.score += player.insuranceBonus;
        notes.add('insurance：${player.name} +${player.insuranceBonus}');
      }
    }

    for (int i = 0; i < players.length; i++) {
      final player = players[i];
      if (!player.taxActive) continue;
      final taxAmount = taxAmountForPlayerCount(players.length);
      for (final winner in winners) {
        if (winner == i) continue;
        players[winner].score -= taxAmount;
        player.score += taxAmount;
        notes.add(
          'tax：${player.name} 从 ${players[winner].name} 拿 $taxAmount 分',
        );
      }
    }

    final compensation = <String>[];
    for (int i = 0; i < players.length; i++) {
      if (winners.contains(i)) {
        players[i].lossStreak = 0;
      } else {
        players[i].lossStreak++;
        if (players[i].lossStreak % 4 == 0) {
          players[i].skillRefreshTokens++;
          notes.add('连输奖励：${players[i].name} 可以恢复 1 张已用技能');
        }
        if (players[i].lossStreak >= 2) {
          players[i].score += 2;
          compensation.add('${players[i].name} +2');
        }
      }
      clearLocalRoundSkills(players[i]);
      players[i].lastWordAttemptedThisRound = false;
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

  void clearLocalRoundSkills(Player player) {
    player.doubleActive = false;
    player.mirrorActive = false;
    player.taxActive = false;
    player.insuranceActive = false;
    player.insuranceBonus = 0;
    player.anchorActive = false;
    player.lastWordActive = false;
    player.ambushTargetIndex = null;
    player.ambushNumber = null;
    player.ambushBonus = 0;
    player.snipeTargetIndex = null;
    player.snipeNumber = null;
  }

  void clearAllLocalSkillEffects() {
    revolutionRound = false;
    revolutionOwner = null;
    currentLocks.clear();
    currentLockOwners.clear();
    currentSilenced.clear();
    currentSilenceOwners.clear();
    currentChaosDeltas.clear();
    currentChaosDelta = 0;
    for (final player in players) {
      clearLocalRoundSkills(player);
    }
  }

  void activateDefense(Player player) {
    setState(() {
      markLocalSkillUsed(player, 'silence');
      clearAllLocalSkillEffects();
      defenseRound = true;
    });
  }

  void silenceLocalPlayer(int targetIndex) {
    final target = players[targetIndex];

    if (revolutionOwner == targetIndex) {
      revolutionRound = false;
      revolutionOwner = null;
    }

    currentLocks.removeWhere(
      (lockedPlayer, _) => currentLockOwners[lockedPlayer] == targetIndex,
    );
    currentLockOwners.removeWhere((_, owner) => owner == targetIndex);

    currentSilenced.removeWhere(
      (silencedPlayer) => currentSilenceOwners[silencedPlayer] == targetIndex,
    );
    currentSilenceOwners.removeWhere((_, owner) => owner == targetIndex);

    currentChaosDeltas.remove(targetIndex);
    currentChaosDelta = currentChaosDeltas.length;

    clearLocalRoundSkills(target);
    currentSilenced.add(targetIndex);
    currentSilenceOwners[targetIndex] = currentPlayer;
  }

  void nextRound() {
    setState(() {
      round++;
      resetLocalTurnOrder();
      selectedCard = null;
      revolutionRound = false;
      defenseRound = false;
      revolutionOwner = null;
      currentLocks.clear();
      currentLockOwners.clear();
      currentSilenced.clear();
      currentSilenceOwners.clear();
      currentChaosDeltas.clear();
      currentChaosDelta = 0;
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
      turnOrder.clear();
      turnPosition = 0;
      selectedCard = null;
      lastSingleWinner = null;
      revolutionRound = false;
      defenseRound = false;
      revolutionOwner = null;
      currentLocks.clear();
      currentLockOwners.clear();
      currentSilenced.clear();
      currentSilenceOwners.clear();
      currentChaosDeltas.clear();
      currentChaosDelta = 0;
    });
  }

  void restartSamePlayers() {
    final random = Random();
    setState(() {
      for (final player in players) {
        player.resetForNewGame(random);
      }
      phase = Phase.choosing;
      round = 1;
      resetLocalTurnOrder();
      selectedCard = null;
      lastSingleWinner = null;
      revolutionRound = false;
      defenseRound = false;
      revolutionOwner = null;
      currentLocks.clear();
      currentLockOwners.clear();
      currentSilenced.clear();
      currentSilenceOwners.clear();
      currentChaosDeltas.clear();
      currentChaosDelta = 0;
      currentPlays.clear();
      history.clear();
      latestResult = null;
    });
  }

  bool localSkillEnabled(String skillId) {
    final player = players[currentPlayer];
    if (!player.skillHand.contains(skillId) ||
        player.usedSkills.contains(skillId)) {
      return false;
    }
    if (defenseRound) {
      return false;
    }
    return switch (skillId) {
      'revolution' => !revolutionRound,
      'double' => !player.doubleActive,
      'lock' => round < 9,
      'peek' => currentPlays.isNotEmpty,
      'ambush' => round < 9,
      'mirror' => !player.mirrorActive,
      'tax' => !player.taxActive,
      'insurance' => !player.insuranceActive && player.insuranceUses < 3,
      'silence' => true,
      'chaos' => true,
      'snipe' => true,
      'last_word' => !player.lastWordActive,
      _ => false,
    };
  }

  bool localSkillActive(String skillId) {
    final player = players[currentPlayer];
    return switch (skillId) {
      'revolution' => revolutionRound,
      'double' => player.doubleActive,
      'mirror' => player.mirrorActive,
      'tax' => player.taxActive,
      'insurance' => player.insuranceActive,
      'silence' => defenseRound,
      'last_word' => player.lastWordActive,
      'ambush' => player.ambushNumber != null,
      'snipe' => player.snipeNumber != null,
      'chaos' => currentChaosDeltas.isNotEmpty,
      'lock' => currentLocks.isNotEmpty,
      _ => false,
    };
  }

  void markLocalSkillUsed(Player player, String skillId) {
    player.usedSkills.add(skillId);
  }

  Future<void> useLocalSkill(String skillId) async {
    if (!localSkillEnabled(skillId)) return;
    final player = players[currentPlayer];

    switch (skillId) {
      case 'revolution':
        setState(() {
          markLocalSkillUsed(player, skillId);
          revolutionRound = true;
          revolutionOwner = currentPlayer;
        });
        break;
      case 'double':
        setState(() {
          markLocalSkillUsed(player, skillId);
          player.doubleActive = true;
        });
        break;
      case 'lock':
        await activateLock();
        break;
      case 'peek':
        await activatePeek();
        break;
      case 'ambush':
        await activateAmbush();
        break;
      case 'mirror':
        setState(() {
          markLocalSkillUsed(player, skillId);
          player.mirrorActive = true;
        });
        break;
      case 'tax':
        setState(() {
          markLocalSkillUsed(player, skillId);
          player.taxActive = true;
        });
        break;
      case 'insurance':
        setState(() {
          player.insuranceUses++;
          player.insuranceBonus = insuranceBonusForUse(player.insuranceUses);
          if (player.insuranceUses >= 3) {
            markLocalSkillUsed(player, skillId);
          }
          player.insuranceActive = true;
        });
        break;
      case 'silence':
        activateDefense(player);
        break;
      case 'chaos':
        setState(() {
          markLocalSkillUsed(player, skillId);
          currentChaosDeltas[currentPlayer] = 1;
          currentChaosDelta = currentChaosDeltas.length;
        });
        break;
      case 'snipe':
        await activateSnipe();
        break;
      case 'last_word':
        setState(() {
          markLocalSkillUsed(player, skillId);
          player.lastWordActive = true;
          player.lastWordAttemptedThisRound = true;
        });
        break;
    }
  }

  bool canRefreshLocalSkill(Player player) {
    return player.skillRefreshTokens > 0 &&
        player.skillHand.any(
          (skillId) =>
              player.usedSkills.contains(skillId) &&
              skillDefinitions.containsKey(skillId),
        );
  }

  Future<void> refreshLocalSkill(Player player) async {
    final choices = [
      for (final skillId in player.skillHand)
        if (player.usedSkills.contains(skillId) &&
            skillDefinitions.containsKey(skillId))
          skillId,
    ];
    if (choices.isEmpty || player.skillRefreshTokens <= 0) return;

    var selectedSkill = choices.first;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('连输奖励'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedSkill,
            decoration: const InputDecoration(labelText: '恢复一张已用技能'),
            items: [
              for (final skillId in choices)
                DropdownMenuItem(
                  value: skillId,
                  child: Text(skillDefinitions[skillId]!.name),
                ),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => selectedSkill = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selectedSkill),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;

    setState(() {
      player.usedSkills.remove(result);
      if (result == 'insurance') {
        player.insuranceUses = min(player.insuranceUses, 2);
      }
      player.skillRefreshTokens--;
    });
  }

  Future<void> activateLock() async {
    final player = players[currentPlayer];

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
                    DropdownMenuItem(
                      value: index,
                      child: Text(players[index].name),
                    ),
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
      markLocalSkillUsed(player, 'lock');
      currentLocks[result.$1] = result.$2;
      currentLockOwners[result.$1] = currentPlayer;
    });
  }

  Future<void> activatePeek() async {
    final player = players[currentPlayer];

    final targets = currentPlays.keys.toList();
    if (targets.isEmpty) {
      showMessage('本轮还没有可偷看的牌');
      return;
    }

    setState(() {
      markLocalSkillUsed(player, 'peek');
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
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
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

  Future<void> activateAmbush() async {
    final player = players[currentPlayer];
    final targets = [
      for (int i = 0; i < players.length; i++)
        if (i != currentPlayer) i,
    ];
    if (targets.isEmpty) return;

    final result = await chooseTargetAndNumberDialog(
      title: 'ambush',
      targetIndexes: targets,
      targetName: (index) => players[index].name,
    );
    if (result == null) return;

    setState(() {
      markLocalSkillUsed(player, 'ambush');
      player.ambushTargetIndex = result.$1;
      player.ambushNumber = result.$2;
      player.ambushBonus = ambushBonusForRound(round);
    });
  }

  Future<void> activateSnipe() async {
    final player = players[currentPlayer];
    final targets = [
      for (int i = 0; i < players.length; i++)
        if (i != currentPlayer) i,
    ];
    if (targets.isEmpty) return;

    final result = await chooseTargetAndNumberDialog(
      title: 'snipe',
      targetIndexes: targets,
      targetName: (index) => players[index].name,
    );
    if (result == null) return;

    setState(() {
      markLocalSkillUsed(player, 'snipe');
      player.snipeTargetIndex = result.$1;
      player.snipeNumber = result.$2;
    });
  }

  Future<void> activateSilence() async {
    final player = players[currentPlayer];
    final targets = [
      for (int i = 0; i < players.length; i++)
        if (i != currentPlayer) i,
    ];
    if (targets.isEmpty) {
      showMessage('没有可以禁技的玩家');
      return;
    }

    var target = targets.first;
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('silence'),
          content: DropdownButtonFormField<int>(
            initialValue: target,
            decoration: const InputDecoration(labelText: '禁技玩家'),
            items: [
              for (final index in targets)
                DropdownMenuItem(
                  value: index,
                  child: Text(players[index].name),
                ),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => target = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(target),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    setState(() {
      markLocalSkillUsed(player, 'silence');
      silenceLocalPlayer(result);
    });
  }

  Future<int?> chooseNumberDialog(String title, String label) async {
    var number = 5;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: DropdownButtonFormField<int>(
            initialValue: number,
            decoration: InputDecoration(labelText: label),
            items: [
              for (int i = 1; i <= 9; i++)
                DropdownMenuItem(value: i, child: Text('$i')),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => number = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(number),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
  }

  Future<(int, int)?> chooseTargetAndNumberDialog({
    required String title,
    required List<int> targetIndexes,
    required String Function(int index) targetName,
  }) async {
    var target = targetIndexes.first;
    var number = 5;
    return showDialog<(int, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: target,
                decoration: const InputDecoration(labelText: '选择玩家'),
                items: [
                  for (final index in targetIndexes)
                    DropdownMenuItem(
                      value: index,
                      child: Text(targetName(index)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => target = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: number,
                decoration: const InputDecoration(labelText: '选择数字'),
                items: [
                  for (int i = 1; i <= 9; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => number = value);
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
              onPressed: () => Navigator.of(context).pop((target, number)),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        const Text(
          '选择人数',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 2, label: Text('2人')),
            ButtonSegment(value: 3, label: Text('3人')),
            ButtonSegment(value: 4, label: Text('4人')),
            ButtonSegment(value: 5, label: Text('5人')),
          ],
          selected: {playerCount},
          onSelectionChanged: (value) =>
              setState(() => playerCount = value.first),
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
        const SizedBox(height: 18),
        buildSkillCatalogPanel(),
      ],
    );
  }

  Widget buildChoosing() {
    final player = players[currentPlayer];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '第 $round / 9 轮',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '本轮顺序：${localTurnOrderText()}',
          style: const TextStyle(fontSize: 15, color: Color(0xFF55524A)),
        ),
        const SizedBox(height: 8),
        Text(
          '请 ${player.name} 出牌',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        buildSkillHandPanel(
          cards: [
            for (final skillId in player.skillHand)
              if (skillDefinitions[skillId] != null)
                SkillButtonData(
                  definition: skillDefinitions[skillId]!,
                  active: localSkillActive(skillId),
                  used: player.usedSkills.contains(skillId),
                  enabled: localSkillEnabled(skillId),
                  onPressed: () => useLocalSkill(skillId),
                ),
          ],
          statusText: localSkillStatusText(player),
        ),
        if (canRefreshLocalSkill(player)) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => refreshLocalSkill(player),
            icon: const Icon(Icons.replay),
            label: const Text('连输奖励：恢复一张已用技能'),
          ),
        ],
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
                  backgroundColor: selected
                      ? const Color(0xFFE09F3E)
                      : const Color(0xFF2E7D6F),
                  disabledBackgroundColor: Colors.black12,
                ),
                child: Text(
                  '$card',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                    trailing: Text(
                      '${result.plays[i]}',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                const Divider(),
                Text(
                  '本轮分数池：${result.pool}',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(result.reason, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  '获胜：${result.winners.map((i) => players[i].name).join('、')}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        buildScoreBoard(
          players.map((p) => ScoreLine(p.name, p.score)).toList(),
        ),
        const SizedBox(height: 12),
        buildCardMemoryBoard(localCardMemoryLines()),
        if (finished) ...[
          const SizedBox(height: 18),
          const Text(
            '最终排名',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final player in sorted)
            ListTile(
              leading: Icon(
                player.score == topScore ? Icons.emoji_events : Icons.person,
              ),
              title: Text(player.name),
              trailing: Text(
                formatScore(player.score),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: restartSamePlayers,
            child: const Text('重开新一把'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: restart, child: const Text('重新设置人数')),
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

  String localSkillStatusText(Player player) {
    final items = [
      if (revolutionRound) 'revolution：本轮比小',
      if (player.doubleActive) 'double：赢了得分翻倍',
      if (player.mirrorActive) 'mirror：点数变成 10-x',
      if (player.taxActive)
        'tax：从赢家拿 ${taxAmountForPlayerCount(players.length)} 分',
      if (player.insuranceActive) 'insurance：没赢 +${player.insuranceBonus}',
      if (defenseRound) 'silence：本轮全部技能失效',
      if (player.lastWordActive) 'last word：并列优先',
      if (player.ambushTargetIndex != null && player.ambushNumber != null)
        'ambush：猜 ${players[player.ambushTargetIndex!].name} 出 ${player.ambushNumber}，抢 ${player.ambushBonus} 分',
      if (player.snipeTargetIndex != null && player.snipeNumber != null)
        'snipe：猜 ${players[player.snipeTargetIndex!].name} 出 ${player.snipeNumber}',
      if (currentChaosDeltas.isNotEmpty) 'chaos：本轮每张牌随机 -1/0/+1',
      if (localLockText().isNotEmpty) localLockText(),
    ];
    return items.join('；');
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

class SkillButtonData {
  const SkillButtonData({
    required this.definition,
    required this.active,
    required this.used,
    required this.enabled,
    required this.onPressed,
  });

  final SkillDefinition definition;
  final bool active;
  final bool used;
  final bool enabled;
  final VoidCallback onPressed;
}

Widget buildSkillHandPanel({
  required List<SkillButtonData> cards,
  required String statusText,
}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '技能牌',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Builder(
                builder: (context) => TextButton.icon(
                  onPressed: () => showSkillCatalogDialog(context),
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('全部技能'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final card in cards)
                buildSkillButton(
                  icon: card.definition.icon,
                  label: card.used
                      ? '${card.definition.name} 已用'
                      : card.active
                      ? '${card.definition.name} 已启动'
                      : card.definition.name,
                  description: card.definition.description,
                  active: card.active,
                  used: card.used,
                  enabled: card.enabled,
                  onPressed: card.onPressed,
                ),
            ],
          ),
          if (statusText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(statusText, style: const TextStyle(color: Colors.black54)),
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
            maxLines: 2,
            overflow: TextOverflow.fade,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showSkillCatalogDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('全部技能'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(child: buildSkillCatalogList()),
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

Widget buildSkillCatalogPanel() {
  return Card(
    child: ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.style),
      title: const Text(
        '全部技能',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [buildSkillCatalogList()],
    ),
  );
}

Widget buildSkillCatalogList() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '每局每人随机抽 3 张技能牌，每张技能牌一局只能用一次。',
        style: TextStyle(fontSize: 13, color: Colors.black54),
      ),
      const SizedBox(height: 8),
      for (final skillId in skillDeck)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                skillDefinitions[skillId]!.icon,
                size: 20,
                color: const Color(0xFF2E7D6F),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skillDefinitions[skillId]!.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      skillDefinitions[skillId]!.detail,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

Widget buildScoreBoard(List<ScoreLine> scores) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Text(
            '当前分数',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
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
          const Text(
            '记牌器',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
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
                        ? const Text(
                            '还没有公开出牌',
                            style: TextStyle(color: Colors.black54),
                          )
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
    List<String>? skillHand,
    Set<String>? usedSkills,
    this.doubleActive = false,
    this.mirrorActive = false,
    this.taxActive = false,
    this.insuranceActive = false,
    this.insuranceUses = 0,
    this.insuranceBonus = 0,
    this.anchorActive = false,
    this.lastWordActive = false,
    this.lastWordAttemptedThisRound = false,
    this.ambushTargetId,
    this.ambushNumber,
    this.ambushBonus = 0,
    this.snipeTargetId,
    this.snipeNumber,
    this.loanDebtRounds = 0,
    this.loanStartRound = 0,
    this.lossStreak = 0,
    this.skillRefreshTokens = 0,
    Set<int>? usedCards,
  }) : skillHand = skillHand ?? [],
       usedSkills = usedSkills ?? {},
       usedCards = usedCards ?? {};

  final String id;
  final String name;
  double score;
  List<String> skillHand;
  Set<String> usedSkills;
  bool doubleActive;
  bool mirrorActive;
  bool taxActive;
  bool insuranceActive;
  int insuranceUses;
  int insuranceBonus;
  bool anchorActive;
  bool lastWordActive;
  bool lastWordAttemptedThisRound;
  String? ambushTargetId;
  int? ambushNumber;
  int ambushBonus;
  String? snipeTargetId;
  int? snipeNumber;
  int loanDebtRounds;
  int loanStartRound;
  int lossStreak;
  int skillRefreshTokens;
  final Set<int> usedCards;

  bool get shouldAvoidFirst =>
      hasAnySkill(skillHand, skillsThatNeedEarlierPlayers);

  bool get shouldAvoidLast =>
      hasAnySkill(skillHand, skillsThatNeedLaterPlayers);

  void resetForNewGame(Random random) {
    score = 0;
    skillHand = drawSkillHand(random);
    usedSkills.clear();
    doubleActive = false;
    mirrorActive = false;
    taxActive = false;
    insuranceActive = false;
    insuranceUses = 0;
    insuranceBonus = 0;
    anchorActive = false;
    lastWordActive = false;
    lastWordAttemptedThisRound = false;
    ambushTargetId = null;
    ambushNumber = null;
    ambushBonus = 0;
    snipeTargetId = null;
    snipeNumber = null;
    loanDebtRounds = 0;
    loanStartRound = 0;
    lossStreak = 0;
    skillRefreshTokens = 0;
    usedCards.clear();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'score': score,
    'skillHand': skillHand,
    'usedSkills': usedSkills.toList(),
    'doubleActive': doubleActive,
    'mirrorActive': mirrorActive,
    'taxActive': taxActive,
    'insuranceActive': insuranceActive,
    'insuranceUses': insuranceUses,
    'insuranceBonus': insuranceBonus,
    'anchorActive': anchorActive,
    'lastWordActive': lastWordActive,
    'lastWordAttemptedThisRound': lastWordAttemptedThisRound,
    'ambushTargetId': ambushTargetId,
    'ambushNumber': ambushNumber,
    'ambushBonus': ambushBonus,
    'snipeTargetId': snipeTargetId,
    'snipeNumber': snipeNumber,
    'loanDebtRounds': loanDebtRounds,
    'loanStartRound': loanStartRound,
    'lossStreak': lossStreak,
    'skillRefreshTokens': skillRefreshTokens,
    'usedCards': usedCards.toList(),
  };

  factory OnlinePlayer.fromJson(Map<String, dynamic> json) {
    return OnlinePlayer(
      id: json['id'] as String,
      name: json['name'] as String,
      score: (json['score'] as num).toDouble(),
      skillHand: List<String>.from((json['skillHand'] as List?) ?? const []),
      usedSkills: List<String>.from(
        (json['usedSkills'] as List?) ?? const [],
      ).toSet(),
      doubleActive: (json['doubleActive'] as bool?) ?? false,
      mirrorActive: (json['mirrorActive'] as bool?) ?? false,
      taxActive: (json['taxActive'] as bool?) ?? false,
      insuranceActive: (json['insuranceActive'] as bool?) ?? false,
      insuranceUses: (json['insuranceUses'] as int?) ?? 0,
      insuranceBonus: (json['insuranceBonus'] as int?) ?? 0,
      anchorActive: (json['anchorActive'] as bool?) ?? false,
      lastWordActive: (json['lastWordActive'] as bool?) ?? false,
      lastWordAttemptedThisRound:
          (json['lastWordAttemptedThisRound'] as bool?) ?? false,
      ambushTargetId: json['ambushTargetId'] as String?,
      ambushNumber: json['ambushNumber'] as int?,
      ambushBonus: (json['ambushBonus'] as int?) ?? 0,
      snipeTargetId: json['snipeTargetId'] as String?,
      snipeNumber: json['snipeNumber'] as int?,
      loanDebtRounds: (json['loanDebtRounds'] as int?) ?? 0,
      loanStartRound: (json['loanStartRound'] as int?) ?? 0,
      lossStreak: (json['lossStreak'] as int?) ?? 0,
      skillRefreshTokens: (json['skillRefreshTokens'] as int?) ?? 0,
      usedCards: ((json['usedCards'] as List<dynamic>?) ?? [])
          .map((item) => item as int)
          .toSet(),
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
    List<String>? turnOrder,
    this.turnPosition = 0,
    this.lastSingleWinnerId,
    this.revolutionRound = false,
    this.defenseRound = false,
    this.revolutionOwnerId,
    Map<String, int>? currentPlays,
    Map<String, int>? lockedCards,
    Map<String, String>? lockOwners,
    Set<String>? silencedPlayers,
    Map<String, String>? silenceOwners,
    Map<String, int>? chaosDeltas,
    this.chaosDelta = 0,
    this.latestResult,
  }) : currentPlays = currentPlays ?? {},
       lockedCards = lockedCards ?? {},
       lockOwners = lockOwners ?? {},
       silencedPlayers = silencedPlayers ?? {},
       silenceOwners = silenceOwners ?? {},
       chaosDeltas = chaosDeltas ?? {},
       turnOrder = turnOrder ?? players.map((player) => player.id).toList();

  OnlinePhase phase;
  int playerCount;
  int round;
  int currentPlayerIndex;
  List<String> turnOrder;
  int turnPosition;
  String? lastSingleWinnerId;
  bool revolutionRound;
  bool defenseRound;
  String? revolutionOwnerId;
  List<OnlinePlayer> players;
  Map<String, int> currentPlays;
  Map<String, int> lockedCards;
  Map<String, String> lockOwners;
  Set<String> silencedPlayers;
  Map<String, String> silenceOwners;
  Map<String, int> chaosDeltas;
  int chaosDelta;
  OnlineRoundResult? latestResult;

  String? get activePlayerId {
    if (turnOrder.isEmpty) return null;
    final position = turnPosition.clamp(0, turnOrder.length - 1).toInt();
    return turnOrder[position];
  }

  void syncCurrentPlayerIndex() {
    final id = activePlayerId;
    currentPlayerIndex = id == null
        ? 0
        : players.indexWhere((player) => player.id == id);
    if (currentPlayerIndex < 0) currentPlayerIndex = 0;
  }

  Map<String, dynamic> toJson() => {
    'phase': phase.name,
    'playerCount': playerCount,
    'round': round,
    'currentPlayerIndex': currentPlayerIndex,
    'turnOrder': turnOrder,
    'turnPosition': turnPosition,
    'lastSingleWinnerId': lastSingleWinnerId,
    'revolutionRound': revolutionRound,
    'defenseRound': defenseRound,
    'revolutionOwnerId': revolutionOwnerId,
    'players': players.map((player) => player.toJson()).toList(),
    'currentPlays': currentPlays,
    'lockedCards': lockedCards,
    'lockOwners': lockOwners,
    'silencedPlayers': silencedPlayers.toList(),
    'silenceOwners': silenceOwners,
    'chaosDeltas': chaosDeltas,
    'chaosDelta': chaosDelta,
    'latestResult': latestResult?.toJson(),
  };

  factory OnlineRoomState.fromJson(Map<String, dynamic> json) {
    final players = (json['players'] as List<dynamic>)
        .map(
          (item) =>
              OnlinePlayer.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final playerIds = players.map((player) => player.id).toSet();
    final savedTurnOrder = List<String>.from(
      (json['turnOrder'] as List?) ?? const [],
    ).where(playerIds.contains).toList();
    final turnOrder = savedTurnOrder.length == players.length
        ? savedTurnOrder
        : players.map((player) => player.id).toList();
    final fallbackPosition =
        (json['turnPosition'] as int?) ??
        (json['currentPlayerIndex'] as int?) ??
        0;
    final maxPosition = turnOrder.isEmpty ? 0 : turnOrder.length - 1;
    final turnPosition = fallbackPosition.clamp(0, maxPosition).toInt();

    return OnlineRoomState(
      phase: OnlinePhase.values.byName(json['phase'] as String),
      playerCount: json['playerCount'] as int,
      round: json['round'] as int,
      currentPlayerIndex: (json['currentPlayerIndex'] as int?) ?? turnPosition,
      turnOrder: turnOrder,
      turnPosition: turnPosition,
      lastSingleWinnerId: json['lastSingleWinnerId'] as String?,
      revolutionRound: (json['revolutionRound'] as bool?) ?? false,
      defenseRound: (json['defenseRound'] as bool?) ?? false,
      revolutionOwnerId: json['revolutionOwnerId'] as String?,
      players: players,
      currentPlays: Map<String, int>.from(json['currentPlays'] as Map),
      lockedCards: Map<String, int>.from((json['lockedCards'] as Map?) ?? {}),
      lockOwners: Map<String, String>.from((json['lockOwners'] as Map?) ?? {}),
      silencedPlayers: List<String>.from(
        (json['silencedPlayers'] as List?) ?? const [],
      ).toSet(),
      silenceOwners: Map<String, String>.from(
        (json['silenceOwners'] as Map?) ?? {},
      ),
      chaosDeltas: Map<String, int>.from((json['chaosDeltas'] as Map?) ?? {}),
      chaosDelta: (json['chaosDelta'] as int?) ?? 0,
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
              const Text(
                '创建房间人数',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 2, label: Text('2人')),
                  ButtonSegment(value: 3, label: Text('3人')),
                  ButtonSegment(value: 4, label: Text('4人')),
                  ButtonSegment(value: 5, label: Text('5人')),
                ],
                selected: {playerCount},
                onSelectionChanged: (value) =>
                    setState(() => playerCount = value.first),
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
      room?.phase == OnlinePhase.choosing && room?.activePlayerId == playerId;

  void resetOnlineTurnOrder() {
    if (room == null) return;
    final orderIndexes = makeFairTurnOrder(
      count: room!.players.length,
      avoidsFirst: (index) => room!.players[index].shouldAvoidFirst,
      avoidsLast: (index) => room!.players[index].shouldAvoidLast,
    );
    room!.turnOrder = orderIndexes
        .map((index) => room!.players[index].id)
        .toList();
    room!.turnPosition = 0;
    room!.syncCurrentPlayerIndex();
  }

  OnlinePlayer? getOnlineActivePlayer() {
    final id = room?.activePlayerId;
    if (room == null || id == null) return null;
    final index = room!.players.indexWhere((player) => player.id == id);
    return index == -1 ? null : room!.players[index];
  }

  String onlineTurnOrderText() {
    if (room == null || room!.turnOrder.isEmpty) return '';
    return room!.turnOrder.map(playerNameById).join(' → ');
  }

  @override
  void initState() {
    super.initState();
    playerId =
        '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(999999)}';
    channel = Supabase.instance.client.channel(
      'number-battle:${widget.roomCode}',
      opts: const RealtimeChannelConfig(self: false, ack: true),
    );

    channel
        .onBroadcast(event: 'join', callback: handleJoin)
        .onBroadcast(event: 'state', callback: handleState)
        .onBroadcast(event: 'submit_card', callback: handleSubmitCard)
        .onBroadcast(event: 'skill', callback: handleSkill)
        .onBroadcast(event: 'skill_refresh', callback: handleSkillRefresh)
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
                  OnlinePlayer(
                    id: playerId,
                    name: widget.playerName,
                    skillHand: drawSkillHand(Random()),
                  ),
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
      room!.players.add(
        OnlinePlayer(id: id, name: name, skillHand: drawSkillHand(Random())),
      );
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
    if (playerIndex == -1 || id != room!.activePlayerId) return;

    final player = room!.players[playerIndex];
    if (player.usedCards.contains(card)) return;
    if (room!.lockedCards[player.id] == card) return;

    player.usedCards.add(card);
    room!.currentPlays[player.id] = card;

    if (room!.turnPosition < room!.turnOrder.length - 1) {
      room!.turnPosition++;
      room!.syncCurrentPlayerIndex();
    } else {
      finishOnlineRound();
    }

    setState(() {});
    broadcastState();
  }

  void handleSkill(Map<String, dynamic> payload) {
    if (!isHost || room == null || room!.phase != OnlinePhase.choosing) return;

    final id = payload['id'] as String?;
    final type = payload['type'] as String?;
    if (id == null || type == null) return;

    final playerIndex = room!.players.indexWhere((player) => player.id == id);
    if (playerIndex == -1 || id != room!.activePlayerId) return;

    final player = room!.players[playerIndex];
    if (!player.skillHand.contains(type) || player.usedSkills.contains(type)) {
      return;
    }
    if (room!.defenseRound) return;

    switch (type) {
      case 'revolution':
        if (room!.revolutionRound) return;
        player.usedSkills.add(type);
        room!.revolutionRound = true;
        room!.revolutionOwnerId = id;
        break;
      case 'double':
        if (player.doubleActive) return;
        player.usedSkills.add(type);
        player.doubleActive = true;
        break;
      case 'lock':
        final targetId = payload['targetId'] as String?;
        final card = payload['card'] as int?;
        if (targetId == null || card == null) return;
        if (targetId == id || card < 1 || card > 9) return;
        if (room!.currentPlays.containsKey(targetId)) return;
        final targetIndex = room!.players.indexWhere(
          (item) => item.id == targetId,
        );
        if (targetIndex == -1 ||
            room!.players[targetIndex].usedCards.contains(card)) {
          return;
        }
        player.usedSkills.add(type);
        room!.lockedCards[targetId] = card;
        room!.lockOwners[targetId] = id;
        break;
      case 'peek':
        final targetId = payload['targetId'] as String?;
        if (targetId == null) return;
        if (!room!.currentPlays.containsKey(targetId)) return;
        player.usedSkills.add(type);
        break;
      case 'ambush':
        final targetId = payload['targetId'] as String?;
        final number = payload['number'] as int?;
        if (targetId == null || targetId == id) return;
        if (!room!.players.any((item) => item.id == targetId)) return;
        if (room!.round >= 9) return;
        if (number == null || number < 1 || number > 9) return;
        player.usedSkills.add(type);
        player.ambushTargetId = targetId;
        player.ambushNumber = number;
        player.ambushBonus = ambushBonusForRound(room!.round);
        break;
      case 'mirror':
        if (player.mirrorActive) return;
        player.usedSkills.add(type);
        player.mirrorActive = true;
        break;
      case 'tax':
        if (player.taxActive) return;
        player.usedSkills.add(type);
        player.taxActive = true;
        break;
      case 'insurance':
        if (player.insuranceActive) return;
        player.insuranceUses++;
        player.insuranceBonus = insuranceBonusForUse(player.insuranceUses);
        if (player.insuranceUses >= 3) {
          player.usedSkills.add(type);
        }
        player.insuranceActive = true;
        break;
      case 'silence':
        player.usedSkills.add(type);
        clearAllOnlineSkillEffects();
        room!.defenseRound = true;
        break;
      case 'chaos':
        player.usedSkills.add(type);
        room!.chaosDeltas[id] = 1;
        room!.chaosDelta = room!.chaosDeltas.length;
        break;
      case 'snipe':
        final targetId = payload['targetId'] as String?;
        final number = payload['number'] as int?;
        if (targetId == null || number == null || targetId == id) return;
        if (number < 1 || number > 9) return;
        if (!room!.players.any((item) => item.id == targetId)) return;
        player.usedSkills.add(type);
        player.snipeTargetId = targetId;
        player.snipeNumber = number;
        break;
      case 'last_word':
        if (player.lastWordActive) return;
        player.usedSkills.add(type);
        player.lastWordActive = true;
        player.lastWordAttemptedThisRound = true;
        break;
      default:
        return;
    }

    setState(() {});
    broadcastState();
  }

  void handleSkillRefresh(Map<String, dynamic> payload) {
    if (!isHost || room == null || room!.phase != OnlinePhase.choosing) return;

    final id = payload['id'] as String?;
    final skillId = payload['skillId'] as String?;
    if (id == null || skillId == null) return;
    if (id != room!.activePlayerId) return;

    final playerIndex = room!.players.indexWhere((player) => player.id == id);
    if (playerIndex == -1) return;
    final player = room!.players[playerIndex];
    if (player.skillRefreshTokens <= 0) return;
    if (!player.skillHand.contains(skillId) ||
        !player.usedSkills.contains(skillId) ||
        !skillDefinitions.containsKey(skillId)) {
      return;
    }

    player.usedSkills.remove(skillId);
    if (skillId == 'insurance') {
      player.insuranceUses = min(player.insuranceUses, 2);
    }
    player.skillRefreshTokens--;
    setState(() {});
    broadcastState();
  }

  void clearAllOnlineSkillEffects() {
    room!.revolutionRound = false;
    room!.revolutionOwnerId = null;
    room!.lockedCards.clear();
    room!.lockOwners.clear();
    room!.silencedPlayers.clear();
    room!.silenceOwners.clear();
    room!.chaosDeltas.clear();
    room!.chaosDelta = 0;
    for (final player in room!.players) {
      clearOnlineRoundSkills(player);
    }
  }

  void silenceOnlinePlayer({
    required String targetId,
    required String sourceId,
  }) {
    final target = room!.players.firstWhere((player) => player.id == targetId);

    if (room!.revolutionOwnerId == targetId) {
      room!.revolutionRound = false;
      room!.revolutionOwnerId = null;
    }

    room!.lockedCards.removeWhere(
      (lockedPlayer, _) => room!.lockOwners[lockedPlayer] == targetId,
    );
    room!.lockOwners.removeWhere((_, owner) => owner == targetId);

    room!.silencedPlayers.removeWhere(
      (silencedPlayer) => room!.silenceOwners[silencedPlayer] == targetId,
    );
    room!.silenceOwners.removeWhere((_, owner) => owner == targetId);

    room!.chaosDeltas.remove(targetId);
    room!.chaosDelta = room!.chaosDeltas.length;

    clearOnlineRoundSkills(target);
    room!.silencedPlayers.add(targetId);
    room!.silenceOwners[targetId] = sourceId;
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
      final random = Random();
      for (final player in room!.players) {
        player.resetForNewGame(random);
      }
      room!.phase = OnlinePhase.choosing;
      room!.round = 1;
      resetOnlineTurnOrder();
      room!.currentPlays.clear();
      room!.lockedCards.clear();
      room!.lockOwners.clear();
      room!.silencedPlayers.clear();
      room!.silenceOwners.clear();
      room!.chaosDeltas.clear();
      room!.chaosDelta = 0;
      room!.latestResult = null;
      room!.lastSingleWinnerId = null;
      room!.revolutionRound = false;
      room!.defenseRound = false;
      room!.revolutionOwnerId = null;
    });
    broadcastState();
  }

  bool onlineSkillEnabled(String skillId) {
    final me = myIndex >= 0 ? room!.players[myIndex] : null;
    if (!isMyTurn || me == null) return false;
    if (!me.skillHand.contains(skillId) || me.usedSkills.contains(skillId)) {
      return false;
    }
    if (room!.defenseRound) {
      return false;
    }
    return switch (skillId) {
      'revolution' => !room!.revolutionRound,
      'double' => !me.doubleActive,
      'lock' => room!.round < 9,
      'peek' => room!.currentPlays.isNotEmpty,
      'ambush' => room!.round < 9,
      'mirror' => !me.mirrorActive,
      'tax' => !me.taxActive,
      'insurance' => !me.insuranceActive && me.insuranceUses < 3,
      'silence' => true,
      'chaos' => true,
      'snipe' => true,
      'last_word' => !me.lastWordActive,
      _ => false,
    };
  }

  bool onlineSkillActive(String skillId) {
    final me = myIndex >= 0 ? room!.players[myIndex] : null;
    if (me == null) return false;
    return switch (skillId) {
      'revolution' => room!.revolutionRound,
      'double' => me.doubleActive,
      'mirror' => me.mirrorActive,
      'tax' => me.taxActive,
      'insurance' => me.insuranceActive,
      'silence' => room!.defenseRound,
      'last_word' => me.lastWordActive,
      'ambush' => me.ambushNumber != null,
      'snipe' => me.snipeNumber != null,
      'chaos' => room!.chaosDeltas.isNotEmpty,
      'lock' => room!.lockedCards.isNotEmpty,
      _ => false,
    };
  }

  Future<void> sendSkill(Map<String, dynamic> payload) async {
    if (isHost) {
      handleSkill(payload);
    } else {
      await send('skill', payload);
    }
  }

  Future<void> sendSkillRefresh(String skillId) async {
    final payload = {'id': playerId, 'skillId': skillId};
    if (isHost) {
      handleSkillRefresh(payload);
    } else {
      await send('skill_refresh', payload);
    }
  }

  bool canRefreshOnlineSkill(OnlinePlayer player) {
    return isMyTurn &&
        player.skillRefreshTokens > 0 &&
        player.skillHand.any(
          (skillId) =>
              player.usedSkills.contains(skillId) &&
              skillDefinitions.containsKey(skillId),
        );
  }

  Future<void> refreshOnlineSkill(OnlinePlayer player) async {
    final choices = [
      for (final skillId in player.skillHand)
        if (player.usedSkills.contains(skillId) &&
            skillDefinitions.containsKey(skillId))
          skillId,
    ];
    if (choices.isEmpty || player.skillRefreshTokens <= 0) return;

    var selectedSkill = choices.first;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('连输奖励'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedSkill,
            decoration: const InputDecoration(labelText: '恢复一张已用技能'),
            items: [
              for (final skillId in choices)
                DropdownMenuItem(
                  value: skillId,
                  child: Text(skillDefinitions[skillId]!.name),
                ),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => selectedSkill = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selectedSkill),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await sendSkillRefresh(result);
  }

  Future<void> useOnlineSkill(String skillId) async {
    if (!onlineSkillEnabled(skillId)) return;

    switch (skillId) {
      case 'revolution':
      case 'double':
      case 'mirror':
      case 'tax':
      case 'insurance':
      case 'silence':
      case 'last_word':
        await sendSkill({'id': playerId, 'type': skillId});
        break;
      case 'chaos':
        await sendSkill({'id': playerId, 'type': skillId});
        break;
      case 'lock':
        await activateOnlineLock();
        break;
      case 'peek':
        await activateOnlinePeek();
        break;
      case 'ambush':
        await activateOnlineAmbush();
        break;
      case 'snipe':
        await activateOnlineSnipe();
        break;
    }
  }

  Future<int?> chooseOnlineNumberDialog(String title, String label) async {
    var number = 5;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: DropdownButtonFormField<int>(
            initialValue: number,
            decoration: InputDecoration(labelText: label),
            items: [
              for (int i = 1; i <= 9; i++)
                DropdownMenuItem(value: i, child: Text('$i')),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => number = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(number),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> activateOnlineLock() async {
    final me = myIndex >= 0 ? room!.players[myIndex] : null;
    if (!isMyTurn || me == null) return;

    final targets = [
      for (final player in room!.players)
        if (player.id != playerId && !room!.currentPlays.containsKey(player.id))
          player,
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
                    DropdownMenuItem(
                      value: player.id,
                      child: Text(player.name),
                    ),
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
    await sendSkill(payload);
  }

  Future<void> activateOnlinePeek() async {
    final me = myIndex >= 0 ? room!.players[myIndex] : null;
    if (!isMyTurn || me == null) return;

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
    await sendSkill(payload);
  }

  Future<void> activateOnlineAmbush() async {
    final targets = [
      for (final player in room!.players)
        if (player.id != playerId) player,
    ];
    if (targets.isEmpty) return;

    var targetId = targets.first.id;
    var number = 5;
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ambush'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: targetId,
                decoration: const InputDecoration(labelText: '猜谁'),
                items: [
                  for (final player in targets)
                    DropdownMenuItem(
                      value: player.id,
                      child: Text(player.name),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => targetId = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: number,
                decoration: const InputDecoration(labelText: '猜数字'),
                items: [
                  for (int i = 1; i <= 9; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => number = value);
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
              onPressed: () => Navigator.of(context).pop((targetId, number)),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    await sendSkill({
      'id': playerId,
      'type': 'ambush',
      'targetId': result.$1,
      'number': result.$2,
    });
  }

  Future<void> activateOnlineSnipe() async {
    final targets = [
      for (final player in room!.players)
        if (player.id != playerId) player,
    ];
    if (targets.isEmpty) return;

    var targetId = targets.first.id;
    var number = 5;
    final result = await showDialog<(String, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('snipe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: targetId,
                decoration: const InputDecoration(labelText: '猜谁'),
                items: [
                  for (final player in targets)
                    DropdownMenuItem(
                      value: player.id,
                      child: Text(player.name),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => targetId = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: number,
                decoration: const InputDecoration(labelText: '猜数字'),
                items: [
                  for (int i = 1; i <= 9; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => number = value);
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
              onPressed: () => Navigator.of(context).pop((targetId, number)),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    await sendSkill({
      'id': playerId,
      'type': 'snipe',
      'targetId': result.$1,
      'number': result.$2,
    });
  }

  Future<void> activateOnlineSilence() async {
    final targets = [
      for (final player in room!.players)
        if (player.id != playerId) player,
    ];
    if (targets.isEmpty) {
      showOnlineMessage('没有可以禁技的玩家');
      return;
    }

    var targetId = targets.first.id;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('silence'),
          content: DropdownButtonFormField<String>(
            initialValue: targetId,
            decoration: const InputDecoration(labelText: '禁技玩家'),
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
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    await sendSkill({'id': playerId, 'type': 'silence', 'targetId': result});
  }

  void showOnlineMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final notes = <String>[];
    final effectivePlays = <String, int>{};
    for (final entry in currentRoom.currentPlays.entries) {
      final player = currentRoom.players.firstWhere(
        (item) => item.id == entry.key,
      );
      final value = player.mirrorActive ? 10 - entry.value : entry.value;
      effectivePlays[entry.key] = value;
      if (player.mirrorActive) {
        notes.add('mirror：${player.name} 的 ${entry.value} 变成 $value');
      }
    }

    if (currentRoom.chaosDeltas.isNotEmpty) {
      final random = Random();
      final chaosNotes = <String>[];
      for (final playerId in effectivePlays.keys.toList()) {
        final player = currentRoom.players.firstWhere(
          (item) => item.id == playerId,
        );
        final oldValue = effectivePlays[playerId]!;
        final delta = random.nextInt(3) - 1;
        final newValue = (oldValue + delta).clamp(1, 9).toInt();
        effectivePlays[playerId] = newValue;
        chaosNotes.add('${player.name} $oldValue→$newValue');
      }
      notes.add('chaos：${chaosNotes.join('、')}');
    }

    final rawPool = effectivePlays.values.fold<int>(
      0,
      (sum, card) => sum + card,
    );
    final pool = max(0, rawPool);

    final values = effectivePlays.values.toList();
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

    final candidates = effectivePlays.entries
        .where((entry) => entry.value == targetNumber)
        .map((entry) => entry.key)
        .toList();
    if (candidates.length > 1) {
      for (final id in candidates) {
        final player = currentRoom.players.firstWhere((item) => item.id == id);
        if (player.lastWordAttemptedThisRound) {
          player.usedSkills.remove('last_word');
        }
      }
    }

    List<String> winnerIds;
    final lastWordCandidates = candidates
        .where(
          (id) => currentRoom.players
              .firstWhere((player) => player.id == id)
              .lastWordActive,
        )
        .toList();
    if (lastWordCandidates.isNotEmpty) {
      winnerIds = [lastWordCandidates.first];
      reason = '$reason；last word：${playerNameById(winnerIds.first)} 并列优先';
      currentRoom.players
          .firstWhere((player) => player.id == winnerIds.first)
          .usedSkills
          .remove('last_word');
    } else if (candidates.length == 1) {
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
    for (final winnerId in winnerIds) {
      final winner = currentRoom.players.firstWhere(
        (player) => player.id == winnerId,
      );
      final multiplier = winner.doubleActive ? 2 : 1;
      winner.score += gain * multiplier;
      if (multiplier == 2) {
        notes.add('double：${winner.name} 得分翻倍');
      }
    }

    for (final player in currentRoom.players) {
      if (player.ambushNumber != null &&
          player.ambushTargetId != null &&
          currentRoom.currentPlays[player.ambushTargetId] ==
              player.ambushNumber) {
        final target = currentRoom.players.firstWhere(
          (item) => item.id == player.ambushTargetId,
        );
        final steal = min(
          player.ambushBonus.toDouble(),
          max(0.0, target.score),
        );
        target.score -= steal;
        player.score += steal;
        notes.add(
          'ambush：${player.name} 从 ${target.name} 抢 ${formatScore(steal)} 分',
        );
      }

      if (player.snipeTargetId != null &&
          player.snipeNumber != null &&
          currentRoom.currentPlays[player.snipeTargetId] ==
              player.snipeNumber) {
        player.score += 5;
        notes.add('snipe：${player.name} +5');
      }

      if (player.insuranceActive && !winnerIds.contains(player.id)) {
        player.score += player.insuranceBonus;
        notes.add('insurance：${player.name} +${player.insuranceBonus}');
      }
    }

    for (final player in currentRoom.players) {
      if (!player.taxActive) continue;
      final taxAmount = taxAmountForPlayerCount(currentRoom.players.length);
      for (final winnerId in winnerIds) {
        if (winnerId == player.id) continue;
        final winner = currentRoom.players.firstWhere(
          (item) => item.id == winnerId,
        );
        winner.score -= taxAmount;
        player.score += taxAmount;
        notes.add('tax：${player.name} 从 ${winner.name} 拿 $taxAmount 分');
      }
    }

    final compensation = <String>[];
    for (final player in currentRoom.players) {
      if (winnerIds.contains(player.id)) {
        player.lossStreak = 0;
      } else {
        player.lossStreak++;
        if (player.lossStreak % 4 == 0) {
          player.skillRefreshTokens++;
          notes.add('连输奖励：${player.name} 可以恢复 1 张已用技能');
        }
        if (player.lossStreak >= 2) {
          player.score += 2;
          compensation.add('${player.name} +2');
        }
      }
      clearOnlineRoundSkills(player);
      player.lastWordAttemptedThisRound = false;
    }
    if (compensation.isNotEmpty) {
      notes.add('连输补偿：${compensation.join('、')}');
    }

    currentRoom.lastSingleWinnerId = winnerIds.length == 1
        ? winnerIds.first
        : null;
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
    currentRoom.lockOwners.clear();
    currentRoom.silencedPlayers.clear();
    currentRoom.silenceOwners.clear();
    currentRoom.chaosDeltas.clear();
    currentRoom.chaosDelta = 0;
    currentRoom.phase = currentRoom.round == 9
        ? OnlinePhase.finished
        : OnlinePhase.reveal;
  }

  void clearOnlineRoundSkills(OnlinePlayer player) {
    player.doubleActive = false;
    player.mirrorActive = false;
    player.taxActive = false;
    player.insuranceActive = false;
    player.insuranceBonus = 0;
    player.anchorActive = false;
    player.lastWordActive = false;
    player.ambushTargetId = null;
    player.ambushNumber = null;
    player.ambushBonus = 0;
    player.snipeTargetId = null;
    player.snipeNumber = null;
  }

  void startNextOnlineRound() {
    setState(() {
      room!.round++;
      resetOnlineTurnOrder();
      room!.phase = OnlinePhase.choosing;
      room!.revolutionRound = false;
      room!.defenseRound = false;
      room!.revolutionOwnerId = null;
      room!.lockedCards.clear();
      room!.lockOwners.clear();
      room!.silencedPlayers.clear();
      room!.silenceOwners.clear();
      room!.chaosDeltas.clear();
      room!.chaosDelta = 0;
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
        Text(
          '玩家 ${room!.players.length} / ${room!.playerCount}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final player in room!.players)
          ListTile(
            leading: Icon(
              player.id == playerId ? Icons.person_pin : Icons.person,
            ),
            title: Text(player.name),
          ),
        const SizedBox(height: 18),
        if (isHost)
          FilledButton(
            onPressed: room!.players.length == room!.playerCount
                ? startOnlineGame
                : null,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text('开始线上游戏', style: TextStyle(fontSize: 18)),
            ),
          )
        else
          const Text('等待房主开始游戏', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 18),
        buildSkillCatalogPanel(),
      ],
    );
  }

  Widget buildOnlineChoosing() {
    final activePlayer = getOnlineActivePlayer();
    final me = myIndex >= 0 ? room!.players[myIndex] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '第 ${room!.round} / 9 轮',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '本轮顺序：${onlineTurnOrderText()}',
          style: const TextStyle(fontSize: 15, color: Color(0xFF55524A)),
        ),
        const SizedBox(height: 8),
        Text(
          isMyTurn ? '轮到你出牌' : '等待 ${activePlayer?.name ?? '下一位玩家'} 出牌',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        buildSkillHandPanel(
          cards: [
            if (me != null)
              for (final skillId in me.skillHand)
                if (skillDefinitions[skillId] != null)
                  SkillButtonData(
                    definition: skillDefinitions[skillId]!,
                    active: onlineSkillActive(skillId),
                    used: me.usedSkills.contains(skillId),
                    enabled: onlineSkillEnabled(skillId),
                    onPressed: () => useOnlineSkill(skillId),
                  ),
          ],
          statusText: me == null ? '' : onlineSkillStatusText(me),
        ),
        if (me != null && canRefreshOnlineSkill(me)) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => refreshOnlineSkill(me),
            icon: const Icon(Icons.replay),
            label: const Text('连输奖励：恢复一张已用技能'),
          ),
        ],
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
                  child: Text(
                    '$card',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              buildCardMemoryBoard(
                onlineCardMemoryLines(includeCurrentRound: false),
              ),
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
            onPressed: isMyTurn && selectedCard != null
                ? submitSelectedCard
                : null,
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
    final sorted = [...room!.players]
      ..sort((a, b) => b.score.compareTo(a.score));
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
                    trailing: Text(
                      '${result.plays[player.id]}',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                const Divider(),
                Text(
                  '本轮分数池：${result.pool}',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(result.reason, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  '获胜：${result.winnerIds.map(playerNameById).join('、')}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
          const Text(
            '最终排名',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final player in sorted)
            ListTile(
              leading: Icon(
                player.score == topScore ? Icons.emoji_events : Icons.person,
              ),
              title: Text(player.name),
              trailing: Text(
                formatScore(player.score),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          const SizedBox(height: 12),
          if (isHost)
            FilledButton(onPressed: startOnlineGame, child: const Text('重开新一把'))
          else
            const Text('等待房主重开新一把', style: TextStyle(fontSize: 18)),
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

  List<CardMemoryLine> onlineCardMemoryLines({
    required bool includeCurrentRound,
  }) {
    return [
      for (final player in room!.players)
        CardMemoryLine(
          player.name,
          (player.usedCards
              .where(
                (card) =>
                    includeCurrentRound ||
                    room!.currentPlays[player.id] != card,
              )
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

  String onlineSkillStatusText(OnlinePlayer player) {
    final items = [
      if (room!.revolutionRound) 'revolution：本轮比小',
      if (player.doubleActive) 'double：赢了得分翻倍',
      if (player.mirrorActive) 'mirror：点数变成 10-x',
      if (player.taxActive)
        'tax：从赢家拿 ${taxAmountForPlayerCount(room!.players.length)} 分',
      if (player.insuranceActive) 'insurance：没赢 +${player.insuranceBonus}',
      if (room!.defenseRound) 'silence：本轮全部技能失效',
      if (player.lastWordActive) 'last word：并列优先',
      if (player.ambushTargetId != null && player.ambushNumber != null)
        'ambush：猜 ${playerNameById(player.ambushTargetId!)} 出 ${player.ambushNumber}，抢 ${player.ambushBonus} 分',
      if (player.snipeTargetId != null && player.snipeNumber != null)
        'snipe：猜 ${playerNameById(player.snipeTargetId!)} 出 ${player.snipeNumber}',
      if (room!.chaosDeltas.isNotEmpty) 'chaos：本轮每张牌随机 -1/0/+1',
      if (onlineLockText().isNotEmpty) onlineLockText(),
    ];
    return items.join('；');
  }
}

String makeRoomCode() {
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random();
  return List.generate(
    5,
    (_) => letters[random.nextInt(letters.length)],
  ).join();
}
