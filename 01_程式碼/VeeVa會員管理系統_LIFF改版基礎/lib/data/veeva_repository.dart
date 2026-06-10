import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'veeva_models.dart';

const defaultVeevaSurveyUrl =
    'https://privacyportal.onetrust.com/webform/3d676ed2-16b1-4c48-97f8-a911923a3adf/0dad5f26-4fad-41d6-a15d-836c329695e1';

abstract class VeevaRepository {
  Future<VeevaBootstrap> loadBootstrap();

  Future<VeevaMember?> loadMember(String memberId);

  Future<VeevaMember> upsertLineMember({
    required String lineUserId,
    required String displayName,
    String? avatarUrl,
    String? email,
    String? statusMessage,
    String? lineIdToken,
    String? referralCode,
  });

  Future<List<VeevaReferral>> loadReferralRecords(String inviterMemberId);

  Future<List<VeevaMemberRewardClaim>> loadMemberRewardClaims(String memberId);

  Future<VeevaMemberRewardClaim?> issueActivityReward({
    required String memberId,
    required String activityId,
  });

  Future<void> registerActivity({
    required String memberId,
    required String memberName,
    required String activityId,
  });

  Future<void> recordActivityCompletion({
    required String memberId,
    required String memberName,
    required String activityId,
    required String activityTitle,
    required String surveyUrl,
  });

  Future<void> redeemMemberRewardClaim(String claimId);

  Future<void> submitReview(VeevaMember member);

  Future<void> approveReview(VeevaReview review);

  Future<void> saveReward(VeevaReward reward);

  Future<void> saveActivity(VeevaActivity activity);

  Future<void> saveNews(VeevaNews news);

  Future<String> uploadImage({
    required String path,
    required Uint8List bytes,
    required String contentType,
  });
}

class FirestoreVeevaRepository implements VeevaRepository {
  FirestoreVeevaRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  CollectionReference<Map<String, dynamic>> get _members =>
      firestore.collection('members');
  CollectionReference<Map<String, dynamic>> get _reviews =>
      firestore.collection('reviewSubmissions');
  CollectionReference<Map<String, dynamic>> get _activities =>
      firestore.collection('activities');
  CollectionReference<Map<String, dynamic>> get _news =>
      firestore.collection('news');
  CollectionReference<Map<String, dynamic>> get _rewards =>
      firestore.collection('rewards');
  CollectionReference<Map<String, dynamic>> get _referrals =>
      firestore.collection('referrals');
  CollectionReference<Map<String, dynamic>> get _memberRewardClaims =>
      firestore.collection('memberRewardClaims');
  CollectionReference<Map<String, dynamic>> get _activityRegistrations =>
      firestore.collection('activityRegistrations');
  CollectionReference<Map<String, dynamic>> get _activityCompletions =>
      firestore.collection('activityCompletions');

  @override
  Future<VeevaBootstrap> loadBootstrap() async {
    final results = await Future.wait([
      _activities.orderBy('active', descending: true).limit(20).get(),
      _news.limit(30).get(),
      _rewards.limit(50).get(),
      _reviews.orderBy('completedAt', descending: true).limit(50).get(),
    ]);

    return VeevaBootstrap(
      activities: results[0]
          .docs
          .map((doc) => VeevaActivity.fromMap(doc.id, doc.data()))
          .toList(),
      news: results[1]
          .docs
          .map((doc) => VeevaNews.fromMap(doc.id, doc.data()))
          .toList(),
      rewards: results[2]
          .docs
          .map((doc) => VeevaReward.fromMap(doc.id, doc.data()))
          .toList(),
      reviews: results[3]
          .docs
          .map((doc) => VeevaReview.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  @override
  Future<VeevaMember?> loadMember(String memberId) async {
    final doc = await _members.doc(memberId).get();
    final data = doc.data();
    if (!doc.exists || data == null) {
      return null;
    }
    return VeevaMember.fromMap(doc.id, data);
  }

  @override
  Future<List<VeevaReferral>> loadReferralRecords(
      String inviterMemberId) async {
    final memberId = inviterMemberId.trim();
    if (memberId.isEmpty) {
      return const [];
    }
    final snapshot =
        await _referrals.where('inviterMemberId', isEqualTo: memberId).get();
    final records = snapshot.docs
        .map((doc) => VeevaReferral.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) {
        final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    return records;
  }

  @override
  Future<List<VeevaMemberRewardClaim>> loadMemberRewardClaims(
    String memberId,
  ) async {
    final normalizedMemberId = memberId.trim();
    if (normalizedMemberId.isEmpty) {
      return const [];
    }
    final snapshot = await _memberRewardClaims
        .where('memberId', isEqualTo: normalizedMemberId)
        .get();
    final claims = snapshot.docs
        .map((doc) => VeevaMemberRewardClaim.fromMap(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    return claims;
  }

  @override
  Future<VeevaMemberRewardClaim?> issueActivityReward({
    required String memberId,
    required String activityId,
  }) async {
    final normalizedMemberId = memberId.trim();
    final normalizedActivityId = activityId.trim();
    if (normalizedMemberId.isEmpty || normalizedActivityId.isEmpty) {
      return null;
    }

    final activitySnapshot = await _activities.doc(normalizedActivityId).get();
    final activityData = activitySnapshot.data();
    if (!activitySnapshot.exists || activityData == null) {
      return null;
    }
    final activity = VeevaActivity.fromMap(activitySnapshot.id, activityData);
    if (!activity.active) {
      return null;
    }

    final reward = await _rewardForActivity(activity);
    if (reward == null || reward.status != VeevaRewardStatus.active) {
      return null;
    }

    final claimRef = _memberRewardClaims.doc(
      '${normalizedMemberId}_${normalizedActivityId}_${reward.id}',
    );
    final rewardRef = _rewards.doc(reward.id);
    final now = DateTime.now();
    final code = _couponCodeForClaim(
      claimId: claimRef.id,
      rewardId: reward.id,
    );

    final result = await firestore
        .runTransaction<Map<String, Object?>?>((transaction) async {
      final existingClaim = await transaction.get(claimRef);
      if (existingClaim.exists) {
        return {'id': existingClaim.id, ...?existingClaim.data()};
      }

      final latestRewardSnapshot = await transaction.get(rewardRef);
      final latestRewardData = latestRewardSnapshot.data();
      if (!latestRewardSnapshot.exists || latestRewardData == null) {
        return null;
      }
      final latestReward =
          VeevaReward.fromMap(latestRewardSnapshot.id, latestRewardData);
      if (latestReward.status != VeevaRewardStatus.active ||
          latestReward.stock <= 0 ||
          latestReward.expiresAt.isBefore(DateTime.now())) {
        return null;
      }

      final claimData = <String, Object?>{
        'memberId': normalizedMemberId,
        'activityId': normalizedActivityId,
        'rewardId': latestReward.id,
        'rewardName': latestReward.name,
        'rewardCategory': latestReward.category,
        'status': VeevaMemberRewardClaimStatus.available.name,
        'code': code,
        'issuedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(latestReward.expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      transaction.set(claimRef, claimData);
      transaction.set(
        rewardRef,
        {
          'stock': FieldValue.increment(-1),
          'issued': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return {
        'id': claimRef.id,
        'memberId': normalizedMemberId,
        'activityId': normalizedActivityId,
        'rewardId': latestReward.id,
        'rewardName': latestReward.name,
        'rewardCategory': latestReward.category,
        'status': VeevaMemberRewardClaimStatus.available.name,
        'code': code,
        'issuedAt': now,
        'expiresAt': latestReward.expiresAt,
      };
    });

    if (result == null) {
      return null;
    }
    final id = result['id']?.toString() ?? claimRef.id;
    return VeevaMemberRewardClaim.fromMap(id, result);
  }

  @override
  Future<void> redeemMemberRewardClaim(String claimId) async {
    final normalizedClaimId = claimId.trim();
    if (normalizedClaimId.isEmpty) {
      return;
    }
    final claimRef = _memberRewardClaims.doc(normalizedClaimId);
    await firestore.runTransaction<void>((transaction) async {
      final claimSnapshot = await transaction.get(claimRef);
      final claimData = claimSnapshot.data();
      if (!claimSnapshot.exists || claimData == null) {
        return;
      }
      final claim = VeevaMemberRewardClaim.fromMap(claimSnapshot.id, claimData);
      if (claim.status != VeevaMemberRewardClaimStatus.available) {
        return;
      }
      transaction.set(
        claimRef,
        {
          'status': VeevaMemberRewardClaimStatus.used.name,
          'usedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(
        _rewards.doc(claim.rewardId),
        {
          'redeemed': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<void> registerActivity({
    required String memberId,
    required String memberName,
    required String activityId,
  }) async {
    final normalizedMemberId = memberId.trim();
    final normalizedActivityId = activityId.trim();
    if (normalizedMemberId.isEmpty || normalizedActivityId.isEmpty) {
      return;
    }
    final activitySnapshot = await _activities.doc(normalizedActivityId).get();
    final activityData = activitySnapshot.data();
    if (!activitySnapshot.exists || activityData == null) {
      return;
    }
    final activity = VeevaActivity.fromMap(activitySnapshot.id, activityData);
    if (!activity.active || activity.type != VeevaActivityType.registration) {
      return;
    }
    await _activityRegistrations
        .doc('${normalizedMemberId}_$normalizedActivityId')
        .set({
      'memberId': normalizedMemberId,
      'memberName': memberName.trim().isEmpty ? 'LINE 會員' : memberName.trim(),
      'activityId': normalizedActivityId,
      'activityTitle': activity.title,
      'status': 'registered',
      'registeredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> recordActivityCompletion({
    required String memberId,
    required String memberName,
    required String activityId,
    required String activityTitle,
    required String surveyUrl,
  }) async {
    final normalizedMemberId = memberId.trim();
    final normalizedActivityId = activityId.trim();
    if (normalizedMemberId.isEmpty || normalizedActivityId.isEmpty) {
      return;
    }

    final completionRef = _activityCompletions.doc(
      _activityCompletionDocumentId(normalizedMemberId, normalizedActivityId),
    );
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(completionRef);
      final data = <String, Object?>{
        'memberId': normalizedMemberId,
        'memberName': memberName.trim().isEmpty ? 'LINE 會員' : memberName.trim(),
        'activityId': normalizedActivityId,
        'activityTitle': activityTitle.trim(),
        'type': VeevaActivityType.survey.name,
        'status': 'completed',
        'surveyUrl': surveyUrl.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!snapshot.exists || snapshot.data()?['completedAt'] == null) {
        data['completedAt'] = FieldValue.serverTimestamp();
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      transaction.set(completionRef, data, SetOptions(merge: true));
    });
  }

  Future<VeevaReward?> _rewardForActivity(VeevaActivity activity) async {
    final directRewardId = activity.rewardId?.trim();
    if (directRewardId == null || directRewardId.isEmpty) {
      return null;
    }
    final snapshot = await _rewards.doc(directRewardId).get();
    final data = snapshot.data();
    if (snapshot.exists && data != null) {
      return VeevaReward.fromMap(snapshot.id, data);
    }
    return null;
  }

  @override
  Future<VeevaMember> upsertLineMember({
    required String lineUserId,
    required String displayName,
    String? avatarUrl,
    String? email,
    String? statusMessage,
    String? lineIdToken,
    String? referralCode,
  }) async {
    final existing = await loadMember(lineUserId);
    final token = lineIdToken?.trim();
    final member = VeevaMember(
      id: lineUserId,
      name: displayName.isEmpty ? existing?.name ?? 'LINE 會員' : displayName,
      hospital: existing?.hospital ?? '',
      department: existing?.department ?? '',
      status: existing?.status ?? VeevaMemberStatus.loggedIn,
      accountStatus: existing?.accountStatus ?? VeevaMemberAccountStatus.active,
      earnedCoupons: existing?.earnedCoupons ?? 0,
      invitedCount: existing?.invitedCount ?? 0,
      shareCode: existing?.shareCode ?? _shareCodeFromId(lineUserId),
      lineUserId: lineUserId,
      avatarUrl: avatarUrl ?? existing?.avatarUrl,
      email: email ?? existing?.email,
      lineStatusMessage: statusMessage ?? existing?.lineStatusMessage,
      lineIdToken:
          token == null || token.isEmpty ? existing?.lineIdToken : token,
      lineIdTokenUpdatedAt: token == null || token.isEmpty
          ? existing?.lineIdTokenUpdatedAt
          : DateTime.now(),
      createdAt: existing?.createdAt ?? DateTime.now(),
      lastLineLoginAt: DateTime.now(),
      referredByMemberId: existing?.referredByMemberId,
      referredByShareCode: existing?.referredByShareCode,
      referredAt: existing?.referredAt,
    );
    final payload = member.toMap()
      ..['lastLineLoginAt'] = FieldValue.serverTimestamp()
      ..['lineLoginProvider'] = 'line';
    if (existing == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    if (token == null || token.isEmpty) {
      payload.remove('lineIdTokenUpdatedAt');
      if (existing?.lineIdToken == null) {
        payload.remove('lineIdToken');
      }
    } else {
      payload['lineIdToken'] = token;
      payload['lineIdTokenUpdatedAt'] = FieldValue.serverTimestamp();
    }
    await _members.doc(lineUserId).set(payload, SetOptions(merge: true));
    final referral = await _bindReferralIfNeeded(
      member: member,
      referralCode: referralCode,
    );
    if (referral == null) {
      return member;
    }
    return VeevaMember(
      id: member.id,
      name: member.name,
      hospital: member.hospital,
      department: member.department,
      status: member.status,
      accountStatus: member.accountStatus,
      earnedCoupons: member.earnedCoupons,
      invitedCount: member.invitedCount,
      shareCode: member.shareCode,
      lineUserId: member.lineUserId,
      avatarUrl: member.avatarUrl,
      email: member.email,
      lineStatusMessage: member.lineStatusMessage,
      lineIdToken: member.lineIdToken,
      lineIdTokenUpdatedAt: member.lineIdTokenUpdatedAt,
      createdAt: member.createdAt,
      lastLineLoginAt: member.lastLineLoginAt,
      referredByMemberId: referral.inviterMemberId,
      referredByShareCode: referral.shareCode,
      referredAt: DateTime.now(),
      updatedAt: member.updatedAt,
    );
  }

  Future<_ReferralBinding?> _bindReferralIfNeeded({
    required VeevaMember member,
    String? referralCode,
  }) async {
    final shareCode = _normalizeShareCode(referralCode);
    if (shareCode == null || member.referredByMemberId != null) {
      return null;
    }
    final inviterQuery =
        await _members.where('shareCode', isEqualTo: shareCode).limit(1).get();
    if (inviterQuery.docs.isEmpty) {
      return null;
    }
    final inviter = inviterQuery.docs.first;
    if (inviter.id == member.id) {
      return null;
    }

    final inviteeRef = _members.doc(member.id);
    final inviterRef = _members.doc(inviter.id);
    final referralRef = _referrals.doc('${inviter.id}_${member.id}');
    var bound = false;

    await firestore.runTransaction((transaction) async {
      final inviteeSnapshot = await transaction.get(inviteeRef);
      final referralSnapshot = await transaction.get(referralRef);
      final inviteeData = inviteeSnapshot.data();
      final existingInviter = inviteeData?['referredByMemberId']?.toString();
      if (existingInviter != null && existingInviter.isNotEmpty) {
        return;
      }
      if (referralSnapshot.exists) {
        return;
      }

      transaction.set(
        inviteeRef,
        {
          'referredByMemberId': inviter.id,
          'referredByShareCode': shareCode,
          'referredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      transaction.set(referralRef, {
        'inviterMemberId': inviter.id,
        'inviterShareCode': shareCode,
        'inviteeMemberId': member.id,
        'inviteeLineUserId': member.lineUserId ?? member.id,
        'inviteeName': member.name,
        'status': 'linked',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        inviterRef,
        {
          'invitedCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      bound = true;
    });

    if (!bound) {
      return null;
    }
    return _ReferralBinding(
      inviterMemberId: inviter.id,
      shareCode: shareCode,
    );
  }

  @override
  Future<void> submitReview(VeevaMember member) async {
    final review = VeevaReview(
      id: member.id,
      memberId: member.id,
      name: member.name,
      hospital: member.hospital,
      department: member.department,
      status: VeevaReviewStatus.pending,
      completedAt: DateTime.now(),
    );
    await Future.wait([
      _members.doc(member.id).set({
        ...member.toMap(),
        'status': VeevaMemberStatus.pendingReview.name,
      }, SetOptions(merge: true)),
      _reviews.doc(member.id).set(review.toMap(), SetOptions(merge: true)),
    ]);
  }

  @override
  Future<void> approveReview(VeevaReview review) async {
    await Future.wait([
      _reviews.doc(review.id).set({
        'status': VeevaReviewStatus.approved.name,
        'approvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      _members.doc(review.memberId).set({
        'status': VeevaMemberStatus.verified.name,
        'earnedCoupons': FieldValue.increment(3),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    ]);
  }

  @override
  Future<void> saveReward(VeevaReward reward) {
    return _rewards.doc(reward.id).set(reward.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> saveActivity(VeevaActivity activity) {
    return _activities
        .doc(activity.id)
        .set(activity.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> saveNews(VeevaNews news) {
    return _news.doc(news.id).set(news.toMap(), SetOptions(merge: true));
  }

  @override
  Future<String> uploadImage({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final reference = storage.ref(path);
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    return reference.getDownloadURL();
  }
}

class DemoVeevaRepository implements VeevaRepository {
  @override
  Future<VeevaBootstrap> loadBootstrap() async {
    return const VeevaBootstrap(
      activities: [],
      news: [],
      rewards: [],
      reviews: [],
    );
  }

  @override
  Future<VeevaMember?> loadMember(String memberId) async => null;

  @override
  Future<List<VeevaReferral>> loadReferralRecords(
      String inviterMemberId) async {
    return const [];
  }

  @override
  Future<List<VeevaMemberRewardClaim>> loadMemberRewardClaims(
    String memberId,
  ) async {
    if (memberId.trim().isEmpty) {
      return const [];
    }
    return [
      VeevaMemberRewardClaim(
        id: '${memberId}_survey-coffee_COFFEE-8X2L',
        memberId: memberId,
        activityId: 'survey-coffee',
        rewardId: 'COFFEE-8X2L',
        rewardName: '中杯美式咖啡 1 杯',
        rewardCategory: '飲品',
        status: VeevaMemberRewardClaimStatus.available,
        issuedAt: DateTime.now(),
        expiresAt: DateTime(2026, 8, 31),
        code: 'COFFEE-8X2L',
      ),
    ];
  }

  @override
  Future<VeevaMemberRewardClaim?> issueActivityReward({
    required String memberId,
    required String activityId,
  }) async {
    final claims = await loadMemberRewardClaims(memberId);
    return claims.isEmpty ? null : claims.first;
  }

  @override
  Future<void> registerActivity({
    required String memberId,
    required String memberName,
    required String activityId,
  }) async {}

  @override
  Future<void> recordActivityCompletion({
    required String memberId,
    required String memberName,
    required String activityId,
    required String activityTitle,
    required String surveyUrl,
  }) async {}

  @override
  Future<void> redeemMemberRewardClaim(String claimId) async {}

  @override
  Future<VeevaMember> upsertLineMember({
    required String lineUserId,
    required String displayName,
    String? avatarUrl,
    String? email,
    String? statusMessage,
    String? lineIdToken,
    String? referralCode,
  }) async {
    return VeevaMember(
      id: lineUserId,
      name: displayName.isEmpty ? 'LINE 會員' : displayName,
      hospital: '',
      department: '',
      status: VeevaMemberStatus.loggedIn,
      earnedCoupons: 0,
      invitedCount: 0,
      shareCode: _shareCodeFromId(lineUserId),
      lineUserId: lineUserId,
      avatarUrl: avatarUrl,
      email: email,
      lineStatusMessage: statusMessage,
      lineIdToken: lineIdToken,
      lineIdTokenUpdatedAt: lineIdToken == null ? null : DateTime.now(),
      createdAt: DateTime.now(),
      lastLineLoginAt: DateTime.now(),
      referredByShareCode: _normalizeShareCode(referralCode),
    );
  }

  @override
  Future<void> submitReview(VeevaMember member) async {}

  @override
  Future<void> approveReview(VeevaReview review) async {}

  @override
  Future<void> saveReward(VeevaReward reward) async {}

  @override
  Future<void> saveActivity(VeevaActivity activity) async {}

  @override
  Future<void> saveNews(VeevaNews news) async {}

  @override
  Future<String> uploadImage({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    return '';
  }
}

String createVeevaId(String prefix) {
  return '$prefix-${DateTime.now().millisecondsSinceEpoch}';
}

String _activityCompletionDocumentId(String memberId, String activityId) {
  return '${_firestoreDocumentSegment(memberId)}_'
      '${_firestoreDocumentSegment(activityId)}';
}

String _firestoreDocumentSegment(String value) {
  return value.trim().replaceAll(RegExp(r'[/#?\[\]]'), '_');
}

String _shareCodeFromId(String id) {
  final compact = id.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toUpperCase();
  if (compact.length >= 5) {
    return compact.substring(compact.length - 5);
  }
  return compact.padRight(5, 'X');
}

String? _normalizeShareCode(String? value) {
  final code = value?.trim();
  if (code == null || code.isEmpty) {
    return null;
  }
  return code.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toUpperCase();
}

String _couponCodeForClaim({
  required String claimId,
  required String rewardId,
}) {
  final rewardPart = rewardId
      .replaceAll(RegExp('[^a-zA-Z0-9]'), '')
      .toUpperCase()
      .padRight(6, 'X')
      .substring(0, 6);
  final claimPart = claimId
      .replaceAll(RegExp('[^a-zA-Z0-9]'), '')
      .toUpperCase()
      .padLeft(4, '0');
  return '$rewardPart-${claimPart.substring(claimPart.length - 4)}';
}

class _ReferralBinding {
  const _ReferralBinding({
    required this.inviterMemberId,
    required this.shareCode,
  });

  final String inviterMemberId;
  final String shareCode;
}

final defaultActivities = <VeevaActivity>[
  const VeevaActivity(
    id: 'survey-coffee',
    type: VeevaActivityType.survey,
    label: '限時活動',
    title: '填問卷，拿咖啡券',
    description: '完成問卷並通過資格確認後，即可獲得咖啡兌換券。分享給朋友，朋友完成後你再得 1 張。',
    reward: '咖啡兌換券',
    rewardId: 'COFFEE-8X2L',
    surveyUrl: defaultVeevaSurveyUrl,
    status: VeevaContentStatus.published,
    active: true,
    periodText: '2026/05/01 - 2026/06/30',
    note: '完成問卷後發放兌換券',
  ),
  const VeevaActivity(
    id: 'seminar-reminder',
    type: VeevaActivityType.registration,
    label: '即將開始',
    title: '研討會報名提醒',
    description: '醫學會活動名額開放後，會員可直接收到報名提醒與活動資訊。',
    reward: '活動提醒',
    status: VeevaContentStatus.scheduled,
    active: false,
    periodText: '2026/06/15 - 2026/07/15',
    note: '醫學會活動報名通知',
  ),
  const VeevaActivity(
    id: 'hospital-mission',
    type: VeevaActivityType.registration,
    label: '籌備中',
    title: '院所限定任務',
    description: '依照院所與科別推出限定任務，完成後可獲得專屬會員獎勵。',
    reward: '專屬獎勵',
    status: VeevaContentStatus.draft,
    active: false,
    periodText: '未設定',
    note: '指定院所會員任務',
  ),
];

final defaultNews = <VeevaNews>[
  const VeevaNews(
    id: 'who-product-alert',
    date: '2026/05/07',
    source: 'WHO',
    title: 'WHO 發布醫療產品警示',
    summary: '提醒留意部分 Iohexol / Iodixanol 顯影劑產品的品質風險，臨床使用前應確認供應來源與批號資訊。',
    status: VeevaContentStatus.published,
    category: '公共衛生',
  ),
  const VeevaNews(
    id: 'who-gcp-course',
    date: '2026/05/05',
    source: 'WHO',
    title: 'WHO 推出臨床試驗良好實務線上課程',
    summary: '新課程聚焦臨床試驗品質、倫理與執行標準，可作為研究團隊訓練素材。',
    status: VeevaContentStatus.published,
    category: '臨床研究',
  ),
  const VeevaNews(
    id: 'fda-realtime-trials',
    date: '2026/04/30',
    source: 'HHS / FDA',
    title: 'FDA 推動即時臨床試驗追蹤試點',
    summary: 'FDA 宣布推進 real-time clinical trials 相關措施，目標是提升臨床試驗資訊透明度與執行效率。',
    status: VeevaContentStatus.published,
    category: '法規',
  ),
  const VeevaNews(
    id: 'fda-hearing-gene-therapy',
    date: '2026/04/23',
    source: 'HHS / FDA',
    title: 'FDA 核准遺傳性聽損基因治療',
    summary: 'FDA 核准 Otarmeni，為遺傳性聽損治療帶來新的基因治療選項。',
    status: VeevaContentStatus.published,
    category: '治療進展',
  ),
  const VeevaNews(
    id: 'nih-monthly-topics',
    date: '2026/05',
    source: 'NIH News in Health',
    title: 'NIH 更新燒傷修復、阿茲海默症預測與腎結石研究主題',
    summary: 'NIH 月刊整理多項研究進展，包含燒傷癒合、阿茲海默症風險預測與腎結石中的細菌研究。',
    status: VeevaContentStatus.published,
    category: '研究',
  ),
  const VeevaNews(
    id: 'cdc-respiratory-low',
    date: '2026/04/17',
    source: 'CDC',
    title: '美國急性呼吸道疾病就醫活動維持低水準',
    summary: 'CDC 呼吸道疾病資料顯示，急性呼吸道疾病導致就醫的整體活動量處於 very low 水準。',
    status: VeevaContentStatus.published,
    category: '公共衛生',
  ),
];

final defaultRewards = <VeevaReward>[
  VeevaReward(
    id: 'coffee-americano',
    name: '中杯美式咖啡 1 杯',
    category: '咖啡',
    stock: 120,
    issued: 80,
    redeemed: 42,
    expiresAt: DateTime(2026, 8, 31),
    status: VeevaRewardStatus.active,
  ),
  VeevaReward(
    id: 'green-tea',
    name: '無糖綠茶 1 瓶',
    category: '飲品',
    stock: 96,
    issued: 62,
    redeemed: 28,
    expiresAt: DateTime(2026, 9, 15),
    status: VeevaRewardStatus.active,
  ),
  VeevaReward(
    id: 'book-coupon',
    name: '醫學書展 100 元折抵券',
    category: '折抵',
    stock: 80,
    issued: 30,
    redeemed: 12,
    expiresAt: DateTime(2026, 10, 5),
    status: VeevaRewardStatus.active,
  ),
];

final defaultReviews = <VeevaReview>[
  VeevaReview(
    id: 'demo-review-1',
    memberId: 'demo-review-1',
    name: '張雅雯',
    hospital: '北醫附醫',
    department: '胸腔內科',
    status: VeevaReviewStatus.pending,
    completedAt: DateTime(2026, 5, 8, 9, 12),
  ),
  VeevaReview(
    id: 'demo-review-2',
    memberId: 'demo-review-2',
    name: '吳志誠',
    hospital: '高醫',
    department: '腎臟科',
    status: VeevaReviewStatus.pending,
    completedAt: DateTime(2026, 5, 8, 10, 4),
  ),
  VeevaReview(
    id: 'demo-review-3',
    memberId: 'demo-review-3',
    name: '李佩珊',
    hospital: '亞東醫院',
    department: '小兒科',
    status: VeevaReviewStatus.pending,
    completedAt: DateTime(2026, 5, 8, 11, 2),
  ),
  VeevaReview(
    id: 'demo-review-4',
    memberId: 'demo-review-4',
    name: '王小明',
    hospital: '台大醫院',
    department: '心臟內科',
    status: VeevaReviewStatus.approved,
    completedAt: DateTime(2026, 5, 7, 14, 35),
  ),
  VeevaReview(
    id: 'demo-review-5',
    memberId: 'demo-review-5',
    name: '陳怡君',
    hospital: '榮總',
    department: '家醫科',
    status: VeevaReviewStatus.approved,
    completedAt: DateTime(2026, 5, 7, 16, 18),
  ),
];
