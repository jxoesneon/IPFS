// ignore_for_file: public_member_api_docs

import 'dart:math' as math;

/// Parameters for scoring a peer in a specific topic.
class TopicScoreParams {
  /// Creates topic score parameters.
  const TopicScoreParams({
    this.topicWeight = 1.0,
    this.timeInMeshWeight = 0.01,
    this.timeInMeshQuantum = 3600, // 1 hour in seconds
    this.firstMessageDeliveriesWeight = 1.0,
    this.firstMessageDeliveriesCap = 5.0,
    this.meshMessageDeliveriesWeight = 1.0,
    this.meshMessageDeliveriesThreshold = 20.0,
    this.meshMessageDeliveriesCap = 100.0,
    this.meshMessageDeliveriesWindow = 10, // heartbeats
    this.meshFailurePenaltyWeight = -1.0,
    this.meshFailurePenaltyDecay = 0.95,
    this.invalidMessageDeliveriesWeight = -10.0,
    this.decayInterval = 60, // 1 minute in seconds
    this.decay = 0.95,
    this.topicScoreCap = 100.0,
  });

  final double topicWeight;
  final double timeInMeshWeight;
  final int timeInMeshQuantum;
  final double firstMessageDeliveriesWeight;
  final double firstMessageDeliveriesCap;
  final double meshMessageDeliveriesWeight;
  final double meshMessageDeliveriesThreshold;
  final double meshMessageDeliveriesCap;
  final int meshMessageDeliveriesWindow;
  final double meshFailurePenaltyWeight;
  final double meshFailurePenaltyDecay;
  final double invalidMessageDeliveriesWeight;
  final int decayInterval;
  final double decay;
  final double topicScoreCap;
}

/// Per-topic scoring state for a peer.
class _TopicScore {
  _TopicScore(this.params);

  final TopicScoreParams params;
  double timeInMesh = 0.0;
  double firstMessageDeliveries = 0.0;
  double meshMessageDeliveries = 0.0;
  final List<double> _meshDeliveryHistory = [];
  int invalidMessageDeliveries = 0;
  DateTime? firstSeen;

  double computeScore(DateTime now) {
    firstSeen ??= now;
    final secondsInMesh = now.difference(firstSeen!).inSeconds;

    // P1: time in mesh
    final p1 =
        params.timeInMeshWeight * (secondsInMesh / params.timeInMeshQuantum);

    // P2: first message deliveries (capped)
    final p2 =
        params.firstMessageDeliveriesWeight *
        math.min(firstMessageDeliveries, params.firstMessageDeliveriesCap);

    // P3: mesh message deliveries over window
    final window =
        _meshDeliveryHistory.length >= params.meshMessageDeliveriesWindow
        ? _meshDeliveryHistory.sublist(
            _meshDeliveryHistory.length - params.meshMessageDeliveriesWindow,
          )
        : _meshDeliveryHistory;
    final windowDeliveries = window.fold<double>(0.0, (a, b) => a + b);
    final meshDeliveryScore = math.min(
      windowDeliveries,
      params.meshMessageDeliveriesCap,
    );
    var p3 = params.meshMessageDeliveriesWeight * meshDeliveryScore;
    if (windowDeliveries < params.meshMessageDeliveriesThreshold) {
      p3 +=
          params.meshFailurePenaltyWeight *
          (params.meshMessageDeliveriesThreshold - windowDeliveries);
    }

    // P4: invalid message deliveries
    final p4 =
        params.invalidMessageDeliveriesWeight *
        invalidMessageDeliveries.toDouble();

    final rawScore = p1 + p2 + p3 + p4;
    return math.min(rawScore, params.topicScoreCap);
  }

  void addFirstMessageDelivery() {
    firstMessageDeliveries += 1.0;
  }

  void addMeshMessageDelivery() {
    meshMessageDeliveries += 1.0;
  }

  void addInvalidMessageDelivery() {
    invalidMessageDeliveries += 1;
  }

  void heartbeat() {
    _meshDeliveryHistory.add(meshMessageDeliveries);
    meshMessageDeliveries = 0.0;
    while (_meshDeliveryHistory.length > params.meshMessageDeliveriesWindow) {
      _meshDeliveryHistory.removeAt(0);
    }
  }

  void decay() {
    firstMessageDeliveries *= params.decay;
    meshMessageDeliveries *= params.decay;
    invalidMessageDeliveries = (invalidMessageDeliveries * params.decay)
        .floor();
  }
}

/// Tracks and computes a per-peer score.
class PeerScore {
  /// Creates a peer score tracker with optional topic parameters.
  PeerScore({Map<String, TopicScoreParams>? topicParams})
    : _topicParams = topicParams ?? const {};

  final Map<String, TopicScoreParams> _topicParams;
  final Map<String, _TopicScore> _topicScores = {};
  double _appSpecificScore = 0.0;
  final double _ipColocationFactor = 0.0;
  double _behaviourPenalty = 0.0;

  /// Records a valid message delivery on [topic] from this peer.
  void addFirstMessageDelivery(String topic) {
    _topicFor(topic).addFirstMessageDelivery();
  }

  /// Records a message delivered over the mesh on [topic].
  void addMeshMessageDelivery(String topic) {
    _topicFor(topic).addMeshMessageDelivery();
  }

  /// Records an invalid message delivery on [topic] from this peer.
  void addInvalidMessageDelivery(String topic) {
    _topicFor(topic).addInvalidMessageDelivery();
  }

  /// Adds a behavioural penalty (e.g. for GRAFT backoff violation).
  void addBehaviourPenalty(double penalty) {
    _behaviourPenalty += penalty;
  }

  /// Sets the application-specific score.
  set appSpecificScore(double value) {
    _appSpecificScore = value;
  }

  /// Computes the total score for the peer.
  double computeScore({DateTime? now}) {
    final effectiveNow = now ?? DateTime.now().toUtc();
    var topicScore = 0.0;
    for (final entry in _topicScores.entries) {
      final weight = _topicParams[entry.key]?.topicWeight ?? 0.0;
      topicScore += entry.value.computeScore(effectiveNow) * weight;
    }
    return topicScore +
        _appSpecificScore +
        _ipColocationFactor +
        _behaviourPenalty;
  }

  /// Returns the score for a specific [topic].
  double topicScore(String topic, {DateTime? now}) {
    return _topicScores[topic]?.computeScore(now ?? DateTime.now().toUtc()) ??
        0.0;
  }

  /// Runs decay on all tracked topics.
  void decay() {
    for (final score in _topicScores.values) {
      score.decay();
    }
    _behaviourPenalty *= 0.95;
    _appSpecificScore *= 0.95;
  }

  /// Runs per-heartbeat accounting.
  void heartbeat() {
    for (final score in _topicScores.values) {
      score.heartbeat();
    }
  }

  _TopicScore _topicFor(String topic) {
    return _topicScores.putIfAbsent(
      topic,
      () => _TopicScore(_topicParams[topic] ?? const TopicScoreParams()),
    );
  }
}

/// Aggregates scores for all known peers.
class PeerScoreTable {
  /// Creates a score table with default topic parameters.
  PeerScoreTable({Map<String, TopicScoreParams>? topicParams})
    : _topicParams = topicParams ?? const {};

  final Map<String, TopicScoreParams> _topicParams;
  final Map<String, PeerScore> _scores = {};

  /// Returns the [PeerScore] for [peerId], creating it if needed.
  PeerScore scoreFor(String peerId) {
    return _scores.putIfAbsent(
      peerId,
      () => PeerScore(topicParams: _topicParams),
    );
  }

  /// Returns the score for [peerId].
  double score(String peerId) => scoreFor(peerId).computeScore();

  /// Decays all peer scores.
  void decay() {
    for (final score in _scores.values) {
      score.decay();
    }
  }

  /// Runs per-heartbeat accounting on all peer scores.
  void heartbeat() {
    for (final score in _scores.values) {
      score.heartbeat();
    }
  }
}
