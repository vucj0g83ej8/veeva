import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'veeva_models.dart';

const defaultVeevaSurveyUrl =
    'https://privacyportal.onetrust.com/webform/3d676ed2-16b1-4c48-97f8-a911923a3adf/0dad5f26-4fad-41d6-a15d-836c329695e1';

abstract class VeevaRepository {
  Future<VeevaBootstrap> loadBootstrap();

  Future<VeevaMember?> loadMember(String memberId);

  Future<VeevaAdminUser?> loadActiveAdminUserByLineUserId(String lineUserId);

  Future<VeevaMember> upsertLineMember({
    required String lineUserId,
    required String displayName,
    String? avatarUrl,
    String? email,
    String? statusMessage,
    String? lineIdToken,
  });

  Future<void> submitReview(VeevaMember member);

  Future<void> approveReview(VeevaReview review);

  Future<void> saveReviewRewardDecision({
    required VeevaMember member,
    required String rewardIssueStatus,
    String? reason,
  });

  Future<void> rejectActivityCompletion(VeevaActivityRecord record);

  Future<void> resetActivityCompletion(VeevaActivityRecord record);

  Future<VeevaActivityRecord> forceCompleteSurvey({
    required VeevaMember member,
    required VeevaActivity activity,
  });

  Future<void> saveReward(VeevaReward reward);

  Future<int> importRewardVoucherLinks({
    required VeevaReward reward,
    required List<String> links,
    required Map<String, String> verificationCodesByLink,
    required String fileName,
  });

  Future<void> deleteReward(String rewardId);

  Future<void> saveActivity(VeevaActivity activity);

  Future<void> saveNews(VeevaNews news);

  Future<void> saveClientSettings(VeevaClientSettings settings);

  Future<void> saveAdminUser(VeevaAdminUser adminUser);

  Future<void> saveMemberSettings({
    required VeevaMember member,
    VeevaAdminUser? adminUser,
  });

  Future<void> deleteMember(VeevaMember member);

  Future<void> saveEmployeeStatus({
    required VeevaMember member,
    required bool enabled,
  });

  Future<VeevaEmployeeActivityLink> createEmployeeActivityLink({
    required VeevaMember employee,
    required VeevaActivity activity,
  });

  Future<void> grantRewardToMember({
    required VeevaMember member,
    required VeevaReward reward,
    required int quantity,
    String? note,
    VeevaActivity? activity,
    VeevaMember? sourceMember,
    String source = 'manualAdmin',
    bool preventDuplicate = false,
    bool sendLineMessage = true,
    String lineMessageType = 'system',
    String? lineMessageTemplateId,
    Map<String, Object?>? lineMessageSnapshot,
  });

  Future<void> sendLineMessageTest({
    required VeevaMember member,
    required String messageType,
    required Map<String, Object?> messageSnapshot,
  });

  Stream<List<VeevaLineChatMessage>> watchLineConversation(
    String lineUserId,
  );

  Stream<List<VeevaLineConversationSummary>> watchLineConversationSummaries();

  Future<void> markLineConversationRead(String lineUserId);

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
  CollectionReference<Map<String, dynamic>> get _admins =>
      firestore.collection('adminUsers');
  CollectionReference<Map<String, dynamic>> get _referrals =>
      firestore.collection('referrals');
  CollectionReference<Map<String, dynamic>> get _memberRewards =>
      firestore.collection('memberRewards');
  CollectionReference<Map<String, dynamic>> get _memberRewardClaims =>
      firestore.collection('memberRewardClaims');
  CollectionReference<Map<String, dynamic>> get _memberNotifications =>
      firestore.collection('memberNotifications');
  CollectionReference<Map<String, dynamic>> get _lineMessageTests =>
      firestore.collection('lineMessageTests');
  CollectionReference<Map<String, dynamic>> get _lineConversations =>
      firestore.collection('lineConversations');
  CollectionReference<Map<String, dynamic>> get _systemSettings =>
      firestore.collection('systemSettings');
  CollectionReference<Map<String, dynamic>> get _rewardVouchers =>
      firestore.collection('rewardVouchers');
  CollectionReference<Map<String, dynamic>> get _activityRegistrations =>
      firestore.collection('activityRegistrations');
  CollectionReference<Map<String, dynamic>> get _activityCompletions =>
      firestore.collection('activityCompletions');
  CollectionReference<Map<String, dynamic>> get _employeeActivityLinks =>
      firestore.collection('employeeActivityLinks');
  CollectionReference<Map<String, dynamic>> get _employeeQrVisits =>
      firestore.collection('employeeQrVisits');
  CollectionReference<Map<String, dynamic>> get _memberEmployeeAttributions =>
      firestore.collection('memberEmployeeAttributions');
  CollectionReference<Map<String, dynamic>> get _newsHelpfulVotes =>
      firestore.collection('newsHelpfulVotes');

  @override
  Future<VeevaBootstrap> loadBootstrap() async {
    final clientSettingsFuture = _systemSettings.doc('clientApp').get();
    final results = await Future.wait([
      _activities.orderBy('active', descending: true).limit(20).get(),
      _news.limit(30).get(),
      _rewards.limit(50).get(),
      _reviews.limit(500).get(),
      _members.get(),
      _admins.limit(100).get(),
      _activityRegistrations.limit(300).get(),
      _activityCompletions.limit(300).get(),
      _memberRewards.limit(500).get(),
      _employeeActivityLinks.limit(500).get(),
      _memberEmployeeAttributions.limit(800).get(),
    ]);
    final clientSettingsDoc = await clientSettingsFuture;

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
      members: results[4]
          .docs
          .map((doc) => VeevaMember.fromMap(doc.id, doc.data()))
          .toList(),
      adminUsers: results[5]
          .docs
          .map((doc) => VeevaAdminUser.fromMap(doc.id, doc.data()))
          .toList(),
      activityRecords: [
        ...results[6].docs.map(
              (doc) => VeevaActivityRecord.fromMap(
                doc.id,
                doc.data(),
                fallbackStatus: 'registered',
              ),
            ),
        ...results[7].docs.map(
              (doc) => VeevaActivityRecord.fromMap(
                doc.id,
                doc.data(),
                fallbackStatus: 'completed',
              ),
            ),
      ],
      memberRewards: results[8]
          .docs
          .map((doc) => VeevaMemberReward.fromMap(doc.id, doc.data()))
          .toList(),
      employeeLinks: results[9]
          .docs
          .map((doc) => VeevaEmployeeActivityLink.fromMap(doc.id, doc.data()))
          .toList(),
      employeeAttributions: results[10]
          .docs
          .map((doc) =>
              VeevaMemberEmployeeAttribution.fromMap(doc.id, doc.data()))
          .toList(),
      clientSettings:
          VeevaClientSettings.fromMap(clientSettingsDoc.data() ?? const {}),
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
  Future<VeevaAdminUser?> loadActiveAdminUserByLineUserId(
    String lineUserId,
  ) async {
    final candidates = <VeevaAdminUser>[];
    final seen = <String>{};

    Future<void> addDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,
    ) async {
      final data = doc.data();
      if (!doc.exists || data == null || !seen.add(doc.id)) {
        return;
      }
      candidates.add(VeevaAdminUser.fromMap(doc.id, data));
    }

    await addDoc(await _admins.doc(lineUserId).get());
    final query =
        await _admins.where('lineUserId', isEqualTo: lineUserId).limit(5).get();
    for (final doc in query.docs) {
      await addDoc(doc);
    }

    for (final admin in candidates) {
      if (admin.status == VeevaAdminStatus.active &&
          admin.lineUserId == lineUserId) {
        return admin;
      }
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
      phoneNumber: existing?.phoneNumber,
      phoneVerified: existing?.phoneVerified ?? false,
      phoneVerifiedAt: existing?.phoneVerifiedAt,
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
      referralRewardGrantedActivityId:
          existing?.referralRewardGrantedActivityId,
      referralRewardGrantedRewardId: existing?.referralRewardGrantedRewardId,
      referralRewardGrantedReferrerId:
          existing?.referralRewardGrantedReferrerId,
      referralRewardGrantedAt: existing?.referralRewardGrantedAt,
      isAdmin: existing?.isAdmin ?? false,
      adminRole: existing?.adminRole,
      isEmployee: existing?.isEmployee ?? false,
      employeeStatus: existing?.employeeStatus,
      employeeCode: existing?.employeeCode,
      employeeCreatedAt: existing?.employeeCreatedAt,
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
    return member;
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
        'rewardIssueStatus': review.rewardIssueStatus ?? 'pending',
        'approvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      _members.doc(review.memberId).set({
        'status': VeevaMemberStatus.verified.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    ]);
  }

  @override
  Future<void> saveReviewRewardDecision({
    required VeevaMember member,
    required String rewardIssueStatus,
    String? reason,
  }) async {
    final trimmedReason = reason?.trim();
    final payload = <String, Object?>{
      'memberId': member.id,
      'lineUserId': member.lineUserId,
      'name': member.name,
      'hospital': member.hospital,
      'department': member.department,
      'status': VeevaReviewStatus.approved.name,
      'completedAt': FieldValue.serverTimestamp(),
      'rewardIssueStatus': rewardIssueStatus,
      'rewardIssueReason': rewardIssueStatus == 'notIssued' &&
              trimmedReason != null &&
              trimmedReason.isNotEmpty
          ? trimmedReason
          : FieldValue.delete(),
      'rewardIssueUpdatedAt': FieldValue.serverTimestamp(),
      'rewardIssuedAt': rewardIssueStatus == 'issued'
          ? FieldValue.serverTimestamp()
          : FieldValue.delete(),
      'rewardNotIssuedAt': rewardIssueStatus == 'notIssued'
          ? FieldValue.serverTimestamp()
          : FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _reviews.doc(member.id).set(payload, SetOptions(merge: true));
  }

  @override
  Future<void> rejectActivityCompletion(VeevaActivityRecord record) async {
    final pendingRewards = await _memberRewards
        .where('activityId', isEqualTo: record.activityId)
        .limit(200)
        .get();
    final batch = firestore.batch();
    final notificationRef = _memberNotifications.doc(
      _memberNotificationDocumentId(
        memberId: record.memberId,
        eventId: '${record.activityId}-activity-rejected',
      ),
    );

    batch.set(
      _activityCompletions.doc(record.id),
      {
        'status': 'rejected',
        'completedAt': FieldValue.delete(),
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      notificationRef,
      {
        'memberId': record.memberId,
        'memberName': record.memberName,
        'memberLineUserId': record.memberLineUserId ?? record.memberId,
        'type': 'system',
        'title': '活動審核未通過',
        'body': _activityRejectedNotificationBody(record),
        'activityId': record.activityId,
        'activityTitle': record.activityTitle,
        'actionPath': '/activities/${record.activityId}',
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    for (final doc in pendingRewards.docs) {
      final data = doc.data();
      if (data['status']?.toString() != 'pending') {
        continue;
      }
      final source = data['source']?.toString();
      final isParticipantReward = source == 'activityCompletion' &&
          data['memberId']?.toString() == record.memberId;
      final isReferrerReward = source == 'referralActivityCompletion' &&
          data['sourceMemberId']?.toString() == record.memberId;
      if (isParticipantReward || isReferrerReward) {
        batch.set(
          doc.reference,
          {
            'status': 'rejected',
            'rejectedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    }

    await batch.commit();
  }

  @override
  Future<void> resetActivityCompletion(VeevaActivityRecord record) async {
    final pendingRewards = await _memberRewards
        .where('activityId', isEqualTo: record.activityId)
        .limit(200)
        .get();
    final batch = firestore.batch();
    final completionId = _activityCompletionDocumentId(
      memberId: record.memberId,
      activityId: record.activityId,
    );
    final registrationId = [record.activityId, record.memberId]
        .map(_firestoreDocumentSegment)
        .join('_');
    final completedNotificationId = _memberNotificationDocumentId(
      memberId: record.memberId,
      eventId: '${record.activityId}-activity-completed',
    );
    final rejectedNotificationId = _memberNotificationDocumentId(
      memberId: record.memberId,
      eventId: '${record.activityId}-activity-rejected',
    );

    batch.delete(_activityCompletions.doc(record.id));
    if (completionId != record.id) {
      batch.delete(_activityCompletions.doc(completionId));
    }
    batch.delete(_activityRegistrations.doc(record.id));
    if (registrationId != record.id) {
      batch.delete(_activityRegistrations.doc(registrationId));
    }
    batch.delete(_memberNotifications.doc(completedNotificationId));
    batch.delete(_memberNotifications.doc(rejectedNotificationId));

    for (final doc in pendingRewards.docs) {
      final data = doc.data();
      if (data['status']?.toString() != 'pending') {
        continue;
      }
      final source = data['source']?.toString();
      final isParticipantReward = source == 'activityCompletion' &&
          data['memberId']?.toString() == record.memberId;
      final isReferrerReward = source == 'referralActivityCompletion' &&
          data['sourceMemberId']?.toString() == record.memberId;
      if (isParticipantReward || isReferrerReward) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
  }

  @override
  Future<VeevaActivityRecord> forceCompleteSurvey({
    required VeevaMember member,
    required VeevaActivity activity,
  }) async {
    final now = DateTime.now();
    final recordId = _activityCompletionDocumentId(
      memberId: member.id,
      activityId: activity.id,
    );
    await _activityCompletions.doc(recordId).set({
      'activityId': activity.id,
      'activityTitle': activity.title,
      'activityType': activity.type.name,
      'memberId': member.id,
      'memberName': member.name,
      'memberAvatarUrl': member.avatarUrl,
      'memberLineUserId': member.lineUserId,
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'approvedAt': FieldValue.serverTimestamp(),
      'forcedCompletedByAdmin': true,
      'forcedCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return VeevaActivityRecord(
      id: recordId,
      activityId: activity.id,
      activityTitle: activity.title,
      activityType: activity.type.name,
      memberId: member.id,
      memberName: member.name,
      memberAvatarUrl: member.avatarUrl,
      memberLineUserId: member.lineUserId,
      status: 'completed',
      completedAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> saveReward(VeevaReward reward) {
    return _rewards.doc(reward.id).set(reward.toMap(), SetOptions(merge: true));
  }

  @override
  Future<int> importRewardVoucherLinks({
    required VeevaReward reward,
    required List<String> links,
    required Map<String, String> verificationCodesByLink,
    required String fileName,
  }) async {
    final cleanLinks = _dedupeVoucherLinks(links);
    if (cleanLinks.isEmpty) {
      return 0;
    }

    var added = 0;
    for (var start = 0; start < cleanLinks.length; start += 350) {
      final chunk = cleanLinks.skip(start).take(350).toList();
      final refs = [
        for (final link in chunk)
          _rewardVouchers.doc(_voucherDocumentId(reward.id, link)),
      ];
      final snapshots = await Future.wait(refs.map((ref) => ref.get()));
      final batch = firestore.batch();
      var batchHasWrites = false;
      for (var index = 0; index < chunk.length; index += 1) {
        final link = chunk[index];
        final verificationCode = verificationCodesByLink[link]?.trim();
        if (snapshots[index].exists) {
          final currentCode =
              snapshots[index].data()?['verificationCode']?.toString().trim();
          if (verificationCode != null &&
              verificationCode.isNotEmpty &&
              verificationCode != currentCode) {
            batchHasWrites = true;
            batch.set(
              refs[index],
              {
                'verificationCode': verificationCode,
                'sourceFileName': fileName,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }
          continue;
        }
        added += 1;
        batchHasWrites = true;
        batch.set(refs[index], {
          'rewardId': reward.id,
          'rewardName': reward.name,
          'url': link,
          'verificationCode': verificationCode,
          'status': 'available',
          'sourceFileName': fileName,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (batchHasWrites) {
        await batch.commit();
      }
    }

    if (added > 0) {
      await _rewards.doc(reward.id).set({
        'voucherTotal': FieldValue.increment(added),
        'voucherAvailable': FieldValue.increment(added),
        'lastVoucherImportFileName': fileName,
        'lastVoucherImportCount': added,
        'lastVoucherImportAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return added;
  }

  @override
  Future<void> deleteReward(String rewardId) {
    return _rewards.doc(rewardId).delete();
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
  Future<void> saveClientSettings(VeevaClientSettings settings) {
    return _systemSettings
        .doc('clientApp')
        .set(settings.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> saveAdminUser(VeevaAdminUser adminUser) async {
    final isActive = adminUser.status == VeevaAdminStatus.active;
    await Future.wait([
      _admins.doc(adminUser.id).set(adminUser.toMap(), SetOptions(merge: true)),
      _members.doc(adminUser.memberId).set({
        'isAdmin': isActive,
        'adminRole': isActive ? adminUser.role.name : null,
        'adminPermissions': isActive ? adminUser.permissions : <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    ]);
  }

  @override
  Future<void> saveMemberSettings({
    required VeevaMember member,
    VeevaAdminUser? adminUser,
  }) async {
    final isActiveAdmin = adminUser?.status == VeevaAdminStatus.active;
    final memberPayload = <String, Object?>{
      'status': member.status.name,
      'accountStatus': member.accountStatus.name,
      'isAdmin': isActiveAdmin,
      'adminRole': isActiveAdmin ? adminUser!.role.name : null,
      'adminPermissions': isActiveAdmin ? adminUser!.permissions : <String>[],
      'updatedAt': FieldValue.serverTimestamp(),
      'disabledAt': member.accountStatus == VeevaMemberAccountStatus.disabled
          ? FieldValue.serverTimestamp()
          : null,
    };
    final writes = <Future<void>>[
      _members.doc(member.id).set(memberPayload, SetOptions(merge: true)),
    ];
    if (isActiveAdmin) {
      writes.add(
        _admins
            .doc(adminUser!.id)
            .set(adminUser.toMap(), SetOptions(merge: true)),
      );
    } else {
      final deleteIds = {
        member.id,
        if (member.lineUserId != null) member.lineUserId!,
        if (adminUser != null) adminUser.id,
      };
      for (final id in deleteIds) {
        writes.add(_admins.doc(id).delete());
      }
    }
    await Future.wait(writes);
  }

  @override
  Future<void> deleteMember(VeevaMember member) async {
    final memberIds = {
      member.id,
      if (member.lineUserId != null && member.lineUserId!.trim().isNotEmpty)
        member.lineUserId!.trim(),
    };
    final shareCode = member.shareCode.trim();

    final docsToDelete = <DocumentReference<Map<String, dynamic>>>{};
    final docsToSet = <_BatchSetOperation>[];
    final linkedMemberUpdates = <String, Map<String, Object?>>{};
    final deleteQueries = <Future<void>>[];

    void addDelete(DocumentReference<Map<String, dynamic>> ref) {
      docsToDelete.add(ref);
    }

    void addSet(
      DocumentReference<Map<String, dynamic>> ref,
      Map<String, Object?> data,
    ) {
      docsToSet.add(_BatchSetOperation(ref, data));
    }

    for (final id in memberIds) {
      addDelete(_members.doc(id));
      addDelete(_reviews.doc(id));
      addDelete(_admins.doc(id));
    }

    for (final id in memberIds) {
      deleteQueries.addAll([
        _collectDeletes(docsToDelete, _admins.where('memberId', isEqualTo: id)),
        _collectDeletes(
          docsToDelete,
          _admins.where('lineUserId', isEqualTo: id),
        ),
        _collectDeletes(
            docsToDelete, _reviews.where('memberId', isEqualTo: id)),
        _collectDeletes(
          docsToDelete,
          _reviews.where('lineUserId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _activityRegistrations.where('memberId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _activityCompletions.where('memberId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _memberNotifications.where('memberId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _memberRewardClaims.where('memberId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _referrals.where('memberId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _referrals.where('inviteeMemberId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _referrals.where('inviterMemberId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _referrals.where('referrerMemberId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _memberEmployeeAttributions.where('memberId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _employeeQrVisits.where('memberId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _employeeActivityLinks.where('employeeMemberId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _employeeQrVisits.where('employeeMemberId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _memberEmployeeAttributions.where('employeeMemberId', isEqualTo: id),
        ),
        _collectDeletes(
          docsToDelete,
          _newsHelpfulVotes.where('memberId', isEqualTo: id),
        ),
      ]);
    }

    if (shareCode.isNotEmpty) {
      deleteQueries.addAll([
        _collectDeletes(
          docsToDelete,
          _referrals.where('referralCode', isEqualTo: shareCode),
        ),
        _collectDeletes(
          docsToDelete,
          _referrals.where('referrerShareCode', isEqualTo: shareCode),
        ),
        _collectDeletes(
          docsToDelete,
          _referrals.where('inviterShareCode', isEqualTo: shareCode),
        ),
      ]);
    }

    await Future.wait(deleteQueries).timeout(const Duration(seconds: 12));

    final memberRewardDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final id in memberIds) {
      memberRewardDocs.addAll(
        (await _memberRewards.where('memberId', isEqualTo: id).get()).docs,
      );
      memberRewardDocs.addAll(
        (await _memberRewards.where('sourceMemberId', isEqualTo: id).get())
            .docs,
      );
    }
    final seenRewardDocIds = <String>{};
    for (final doc in memberRewardDocs) {
      if (!seenRewardDocIds.add(doc.id)) continue;
      addDelete(doc.reference);
      final data = doc.data();
      final rewardId = data['rewardId']?.toString();
      final status = data['status']?.toString();
      final voucherId = data['voucherId']?.toString();
      if (rewardId == null || rewardId.isEmpty) {
        continue;
      }
      if (status == 'issued' || status == 'pending') {
        addSet(_rewards.doc(rewardId), {
          'stock': FieldValue.increment(1),
          'issued': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
          if (voucherId != null && voucherId.isNotEmpty)
            'voucherAvailable': FieldValue.increment(1),
        });
        if (voucherId != null && voucherId.isNotEmpty) {
          addSet(_rewardVouchers.doc(voucherId), {
            'status': 'available',
            'memberId': FieldValue.delete(),
            'memberName': FieldValue.delete(),
            'memberLineUserId': FieldValue.delete(),
            'issuedAt': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else if (status == 'redeemed') {
        addSet(_rewards.doc(rewardId), {
          'issued': FieldValue.increment(-1),
          'redeemed': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    for (final id in memberIds) {
      final vouchers =
          await _rewardVouchers.where('memberId', isEqualTo: id).get();
      for (final doc in vouchers.docs) {
        final data = doc.data();
        if (data['status']?.toString() == 'issued') {
          addSet(doc.reference, {
            'status': 'available',
            'memberId': FieldValue.delete(),
            'memberName': FieldValue.delete(),
            'memberLineUserId': FieldValue.delete(),
            'issuedAt': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    final employeeAttributions =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final id in memberIds) {
      employeeAttributions.addAll(
        (await _memberEmployeeAttributions
                .where('memberId', isEqualTo: id)
                .get())
            .docs,
      );
    }
    final seenAttributionIds = <String>{};
    for (final doc in employeeAttributions) {
      if (!seenAttributionIds.add(doc.id)) continue;
      final data = doc.data();
      final linkId =
          data['employeeLinkId']?.toString() ?? data['linkId']?.toString();
      if (linkId == null || linkId.isEmpty) continue;
      addSet(_employeeActivityLinks.doc(linkId), {
        'registeredCount': FieldValue.increment(-1),
        if (data['phoneVerifiedAt'] != null)
          'phoneVerifiedCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final employeeVisits = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final id in memberIds) {
      employeeVisits.addAll(
        (await _employeeQrVisits.where('memberId', isEqualTo: id).get()).docs,
      );
    }
    final seenVisitIds = <String>{};
    for (final doc in employeeVisits) {
      if (!seenVisitIds.add(doc.id)) continue;
      final data = doc.data();
      final linkId = data['linkId']?.toString() ?? data['code']?.toString();
      if (linkId == null || linkId.isEmpty) continue;
      addSet(_employeeActivityLinks.doc(linkId), {
        'visitCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final helpfulVotes = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final id in memberIds) {
      helpfulVotes.addAll(
        (await _newsHelpfulVotes.where('memberId', isEqualTo: id).get()).docs,
      );
    }
    final seenVoteIds = <String>{};
    for (final doc in helpfulVotes) {
      if (!seenVoteIds.add(doc.id)) continue;
      final newsId = doc.data()['newsId']?.toString();
      if (newsId == null || newsId.isEmpty) continue;
      addSet(_news.doc(newsId), {
        'helpfulCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (member.referredByMemberId != null &&
        member.referredByMemberId!.isNotEmpty) {
      addSet(_members.doc(member.referredByMemberId!), {
        'invitedCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    for (final id in memberIds) {
      final referredMembers =
          await _members.where('referredByMemberId', isEqualTo: id).get();
      for (final doc in referredMembers.docs) {
        if (memberIds.contains(doc.id)) continue;
        linkedMemberUpdates[doc.id] = {
          'referredByMemberId': FieldValue.delete(),
          'referredByShareCode': FieldValue.delete(),
          'referredAt': FieldValue.delete(),
          'referralRewardGrantedActivityId': FieldValue.delete(),
          'referralRewardGrantedRewardId': FieldValue.delete(),
          'referralRewardGrantedReferrerId': FieldValue.delete(),
          'referralRewardGrantedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }
    }
    if (shareCode.isNotEmpty) {
      final referredMembers = await _members
          .where('referredByShareCode', isEqualTo: shareCode)
          .get();
      for (final doc in referredMembers.docs) {
        if (memberIds.contains(doc.id)) continue;
        linkedMemberUpdates[doc.id] = {
          'referredByMemberId': FieldValue.delete(),
          'referredByShareCode': FieldValue.delete(),
          'referredAt': FieldValue.delete(),
          'referralRewardGrantedActivityId': FieldValue.delete(),
          'referralRewardGrantedRewardId': FieldValue.delete(),
          'referralRewardGrantedReferrerId': FieldValue.delete(),
          'referralRewardGrantedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }
    }

    for (final entry in linkedMemberUpdates.entries) {
      addSet(_members.doc(entry.key), entry.value);
    }

    await _commitBatchedWrites(
      deletes: docsToDelete,
      sets: docsToSet,
    );
  }

  @override
  Future<void> saveEmployeeStatus({
    required VeevaMember member,
    required bool enabled,
  }) {
    final employeeCode = enabled
        ? (member.employeeCode?.trim().isNotEmpty == true
            ? member.employeeCode!.trim()
            : _employeeCodeFromId(member.id))
        : member.employeeCode;
    return _members.doc(member.id).set({
      'isEmployee': enabled,
      'employeeStatus': enabled ? 'active' : 'disabled',
      'employeeCode': employeeCode,
      if (enabled && member.employeeCreatedAt == null)
        'employeeCreatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<VeevaEmployeeActivityLink> createEmployeeActivityLink({
    required VeevaMember employee,
    required VeevaActivity activity,
  }) async {
    final code = _employeeActivityLinkCode(
      employeeId: employee.id,
      activityId: activity.id,
      employeeCode: employee.employeeCode,
    );
    final linkRef = _employeeActivityLinks.doc(code);
    final url = _employeeLiffUrlForCode(code);
    final existingLink = await linkRef.get();
    await linkRef.set({
      'code': code,
      'employeeMemberId': employee.id,
      'employeeLineUserId': employee.lineUserId ?? employee.id,
      'employeeName': employee.name,
      'employeeAvatarUrl': employee.avatarUrl,
      'activityId': activity.id,
      'activityTitle': activity.title,
      'activityType': activity.type.name,
      'url': url,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existingLink.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final snapshot = await linkRef.get();
    return VeevaEmployeeActivityLink.fromMap(
      snapshot.id,
      snapshot.data() ?? const {},
    );
  }

  @override
  Future<void> grantRewardToMember({
    required VeevaMember member,
    required VeevaReward reward,
    required int quantity,
    String? note,
    VeevaActivity? activity,
    VeevaMember? sourceMember,
    String source = 'manualAdmin',
    bool preventDuplicate = false,
    bool sendLineMessage = true,
    String lineMessageType = 'system',
    String? lineMessageTemplateId,
    Map<String, Object?>? lineMessageSnapshot,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity', 'must be positive');
    }

    final rewardRef = _rewards.doc(reward.id);
    final memberRef = _members.doc(member.id);
    final cleanNote = note?.trim();
    final issuedBatchId = DateTime.now().millisecondsSinceEpoch;
    final normalizedSource = source.trim().isEmpty ? 'manualAdmin' : source;
    final liveRewardData = (await rewardRef.get()).data();
    final voucherPoolTotal = _readIntLike(liveRewardData?['voucherTotal']);
    final liveRequiresVerificationCode = liveRewardData == null
        ? reward.requiresVerificationCode
        : liveRewardData['requiresVerificationCode'] == true;
    DocumentReference<Map<String, dynamic>>? voucherRef;
    if (voucherPoolTotal > 0) {
      if (quantity != 1) {
        throw StateError('voucher link rewards must be issued one at a time');
      }
      voucherRef = await _findAvailableVoucherRef(
        reward.id,
        requiresVerificationCode: liveRequiresVerificationCode,
      );
      if (voucherRef == null) {
        throw StateError('no available voucher link');
      }
    }
    final shouldMarkReferralReward =
        normalizedSource == 'referralActivityCompletion' &&
            sourceMember != null &&
            activity != null;
    final sourceMemberRef =
        shouldMarkReferralReward ? _members.doc(sourceMember.id) : null;
    final deterministicGrantId = activity == null
        ? null
        : _rewardGrantDocumentId(
            memberId: member.id,
            rewardId: reward.id,
            activityId: activity.id,
            source: normalizedSource,
            sourceMemberId: sourceMember?.id,
          );

    await firestore.runTransaction((transaction) async {
      final rewardSnapshot = await transaction.get(rewardRef);
      final rewardData = rewardSnapshot.data();
      final voucherSnapshot =
          voucherRef == null ? null : await transaction.get(voucherRef);
      final voucherData = voucherSnapshot?.data();
      if (voucherRef != null &&
          (voucherSnapshot?.exists != true ||
              voucherData?['status']?.toString() != 'available')) {
        throw StateError('voucher link is not available');
      }
      final existingGrantSnapshot =
          preventDuplicate && deterministicGrantId != null
              ? await transaction.get(_memberRewards.doc(deterministicGrantId))
              : null;
      if (existingGrantSnapshot?.exists == true) {
        final existingStatus =
            existingGrantSnapshot?.data()?['status']?.toString();
        if (existingStatus != 'pending') {
          throw StateError('reward already issued');
        }
      }
      final sourceMemberSnapshot = sourceMemberRef == null
          ? null
          : await transaction.get(sourceMemberRef);
      final sourceMemberData = sourceMemberSnapshot?.data();
      if (sourceMemberData?['referralRewardGrantedAt'] != null ||
          sourceMemberData?['referralRewardGrantedActivityId'] != null) {
        throw StateError('referral reward already granted');
      }
      final liveStock =
          rewardData == null ? reward.stock : _readIntLike(rewardData['stock']);
      final liveStatus =
          rewardData?['status']?.toString() ?? reward.status.name;
      final requiresVerificationCode = rewardData == null
          ? reward.requiresVerificationCode
          : rewardData['requiresVerificationCode'] == true;
      final verificationCode =
          voucherData?['verificationCode']?.toString().trim();

      if (liveStatus != VeevaRewardStatus.active.name) {
        throw StateError('reward is not active');
      }
      if (liveStock < quantity) {
        throw StateError('insufficient reward stock');
      }
      if (requiresVerificationCode &&
          (verificationCode == null || verificationCode.isEmpty)) {
        throw StateError('voucher verification code is missing');
      }

      for (var index = 0; index < quantity; index += 1) {
        final grantRef = _memberRewards.doc(
          deterministicGrantId != null && quantity == 1
              ? deterministicGrantId
              : '${member.id}-${reward.id}-$issuedBatchId-$index',
        );
        final notificationRef = _memberNotifications.doc(
          _memberNotificationDocumentId(
            memberId: member.id,
            eventId: '${grantRef.id}-issued',
          ),
        );
        transaction.set(grantRef, {
          'memberId': member.id,
          'memberName': member.name,
          'memberLineUserId': member.lineUserId,
          'rewardId': reward.id,
          'rewardName': reward.name,
          'rewardCategory': reward.category,
          'rewardImageUrl': reward.imageUrl,
          'requiresVerificationCode': requiresVerificationCode,
          'verificationCode':
              requiresVerificationCode ? verificationCode : null,
          'redemptionUrl': voucherData?['url']?.toString(),
          'voucherId': voucherRef?.id,
          'status': 'issued',
          'source': normalizedSource,
          'activityId': activity?.id,
          'activityTitle': activity?.title,
          'sourceMemberId': sourceMember?.id,
          'sourceMemberName': sourceMember?.name,
          'note': cleanNote == null || cleanNote.isEmpty ? null : cleanNote,
          'issuedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(reward.expiresAt),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(
            notificationRef,
            {
              'memberId': member.id,
              'memberName': member.name,
              'memberLineUserId': member.lineUserId ?? member.id,
              'type': 'rewardIssued',
              'title': '收到兌換券',
              'body': _rewardIssuedNotificationBody(
                reward: reward,
                activity: activity,
                source: normalizedSource,
              ),
              'rewardId': reward.id,
              'rewardName': reward.name,
              'rewardImageUrl': reward.imageUrl,
              'memberRewardId': grantRef.id,
              'activityId': activity?.id,
              'activityTitle': activity?.title,
              'actionPath': '/coupons?reward=${grantRef.id}',
              'lineMessageType': lineMessageType,
              'lineMessageTemplateId': lineMessageTemplateId,
              'lineMessageSnapshot': lineMessageSnapshot,
              'linePushStatus': !sendLineMessage
                  ? 'disabled'
                  : member.lineUserId == null ||
                          member.lineUserId!.trim().isEmpty
                      ? 'skipped'
                      : 'pending',
              'linePushError': null,
              'linePushedAt': null,
              'readAt': null,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }

      transaction.set(
          memberRef,
          {
            'earnedCoupons': FieldValue.increment(quantity),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      transaction.set(
          rewardRef,
          {
            'stock': FieldValue.increment(-quantity),
            'issued': FieldValue.increment(quantity),
            if (voucherRef != null)
              'voucherAvailable': FieldValue.increment(-1),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      if (voucherRef != null) {
        transaction.set(
            voucherRef,
            {
              'status': 'issued',
              'memberId': member.id,
              'memberName': member.name,
              'memberLineUserId': member.lineUserId,
              'issuedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }
      if (sourceMemberRef != null) {
        transaction.set(
            sourceMemberRef,
            {
              'referralRewardGrantedActivityId': activity!.id,
              'referralRewardGrantedRewardId': reward.id,
              'referralRewardGrantedReferrerId': member.id,
              'referralRewardGrantedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }
      if (normalizedSource == 'activityCompletion' && activity != null) {
        transaction.set(
            _activityCompletions.doc(_activityCompletionDocumentId(
              memberId: member.id,
              activityId: activity.id,
            )),
            {
              'activityId': activity.id,
              'activityTitle': activity.title,
              'activityType': activity.type.name,
              'memberId': member.id,
              'memberName': member.name,
              'memberAvatarUrl': member.avatarUrl,
              'memberLineUserId': member.lineUserId,
              'status': 'completed',
              'approvedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }
    });
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

  @override
  Future<void> sendLineMessageTest({
    required VeevaMember member,
    required String messageType,
    required Map<String, Object?> messageSnapshot,
  }) async {
    final lineUserId = member.lineUserId?.trim();
    if (lineUserId == null || lineUserId.isEmpty) {
      throw StateError('此會員沒有可使用的 LINE 帳號識別碼。');
    }

    final request = _lineMessageTests.doc();
    await request.set({
      'memberId': member.id,
      'memberName': member.name,
      'memberLineUserId': lineUserId,
      'messageType': messageType,
      'messageSnapshot': messageSnapshot,
      'status': 'pending',
      'error': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (var attempt = 0; attempt < 30; attempt += 1) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final snapshot = await request.get();
      final data = snapshot.data();
      final status = data?['status']?.toString();
      if (status == 'sent') return;
      if (status == 'failed' || status == 'skipped') {
        final error = data?['error']?.toString().trim();
        throw StateError(
          error == null || error.isEmpty ? 'LINE 測試訊息發送失敗。' : error,
        );
      }
    }
    throw StateError('LINE 測試訊息等待逾時，請稍後再試。');
  }

  @override
  Stream<List<VeevaLineChatMessage>> watchLineConversation(
    String lineUserId,
  ) {
    final normalizedId = lineUserId.trim();
    if (normalizedId.isEmpty) {
      return Stream.value(const <VeevaLineChatMessage>[]);
    }
    return _lineConversations
        .doc(normalizedId)
        .collection('messages')
        .orderBy('sentAt')
        .limitToLast(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => VeevaLineChatMessage.fromMap(doc.id, doc.data()),
              )
              .toList(growable: false),
        );
  }

  @override
  Stream<List<VeevaLineConversationSummary>> watchLineConversationSummaries() {
    return _lineConversations
        .orderBy('lastMessageAt', descending: true)
        .limit(500)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => VeevaLineConversationSummary.fromMap(
                  doc.id,
                  doc.data(),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> markLineConversationRead(String lineUserId) async {
    final normalizedId = lineUserId.trim();
    if (normalizedId.isEmpty) return;
    await _lineConversations.doc(normalizedId).set({
      'unreadCount': 0,
      'lastReadAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<DocumentReference<Map<String, dynamic>>?> _findAvailableVoucherRef(
    String rewardId, {
    required bool requiresVerificationCode,
  }) async {
    final snapshot = await _rewardVouchers
        .where('rewardId', isEqualTo: rewardId)
        .where('status', isEqualTo: 'available')
        .limit(requiresVerificationCode ? 50 : 1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    for (final voucher in snapshot.docs) {
      final url = voucher.data()['url']?.toString().trim();
      final code = voucher.data()['verificationCode']?.toString().trim();
      final hasUrl = url != null && url.isNotEmpty;
      final hasRequiredCode =
          !requiresVerificationCode || (code != null && code.isNotEmpty);
      if (hasUrl && hasRequiredCode) {
        return voucher.reference;
      }
    }
    return null;
  }
}

class _BatchSetOperation {
  const _BatchSetOperation(this.ref, this.data);

  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, Object?> data;
}

Future<void> _collectDeletes(
  Set<DocumentReference<Map<String, dynamic>>> refs,
  Query<Map<String, dynamic>> query,
) async {
  final snapshot = await query.limit(500).get();
  for (final doc in snapshot.docs) {
    refs.add(doc.reference);
  }
}

Future<void> _commitBatchedWrites({
  required Iterable<DocumentReference<Map<String, dynamic>>> deletes,
  required Iterable<_BatchSetOperation> sets,
}) async {
  final operations = <void Function(WriteBatch)>[
    for (final item in sets)
      (batch) => batch.set(item.ref, item.data, SetOptions(merge: true)),
    for (final ref in deletes) (batch) => batch.delete(ref),
  ];

  for (var index = 0; index < operations.length; index += 450) {
    final batch = FirebaseFirestore.instance.batch();
    for (final operation in operations.skip(index).take(450)) {
      operation(batch);
    }
    await batch.commit();
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
      members: [],
      adminUsers: [],
      activityRecords: [],
      memberRewards: [],
      employeeLinks: [],
      employeeAttributions: [],
      clientSettings: VeevaClientSettings(),
    );
  }

  @override
  Future<VeevaMember?> loadMember(String memberId) async => null;

  @override
  Future<VeevaAdminUser?> loadActiveAdminUserByLineUserId(
    String lineUserId,
  ) async {
    if (lineUserId != 'line-demo-wang') {
      return null;
    }
    return const VeevaAdminUser(
      id: 'line-demo-wang',
      memberId: 'line-demo-wang',
      lineUserId: 'line-demo-wang',
      name: '王小明',
      email: 'wang@example.com',
      role: VeevaAdminRole.owner,
      status: VeevaAdminStatus.active,
      permissions: ['members', 'activities', 'news', 'rewards', 'settings'],
    );
  }

  @override
  Future<VeevaMember> upsertLineMember({
    required String lineUserId,
    required String displayName,
    String? avatarUrl,
    String? email,
    String? statusMessage,
    String? lineIdToken,
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
      phoneNumber: null,
      lineStatusMessage: statusMessage,
      lineIdToken: lineIdToken,
      lineIdTokenUpdatedAt: lineIdToken == null ? null : DateTime.now(),
      createdAt: DateTime.now(),
      lastLineLoginAt: DateTime.now(),
    );
  }

  @override
  Future<void> submitReview(VeevaMember member) async {}

  @override
  Future<void> approveReview(VeevaReview review) async {}

  @override
  Future<void> saveReviewRewardDecision({
    required VeevaMember member,
    required String rewardIssueStatus,
    String? reason,
  }) async {}

  @override
  Future<void> rejectActivityCompletion(VeevaActivityRecord record) async {}

  @override
  Future<void> resetActivityCompletion(VeevaActivityRecord record) async {}

  @override
  Future<VeevaActivityRecord> forceCompleteSurvey({
    required VeevaMember member,
    required VeevaActivity activity,
  }) async {
    final now = DateTime.now();
    return VeevaActivityRecord(
      id: _activityCompletionDocumentId(
        memberId: member.id,
        activityId: activity.id,
      ),
      activityId: activity.id,
      activityTitle: activity.title,
      activityType: activity.type.name,
      memberId: member.id,
      memberName: member.name,
      memberAvatarUrl: member.avatarUrl,
      memberLineUserId: member.lineUserId,
      status: 'completed',
      completedAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> saveReward(VeevaReward reward) async {}

  @override
  Future<int> importRewardVoucherLinks({
    required VeevaReward reward,
    required List<String> links,
    required Map<String, String> verificationCodesByLink,
    required String fileName,
  }) async {
    return links.length;
  }

  @override
  Future<void> deleteReward(String rewardId) async {}

  @override
  Future<void> saveActivity(VeevaActivity activity) async {}

  @override
  Future<void> saveNews(VeevaNews news) async {}

  @override
  Future<void> saveClientSettings(VeevaClientSettings settings) async {}

  @override
  Future<void> saveAdminUser(VeevaAdminUser adminUser) async {}

  @override
  Future<void> saveMemberSettings({
    required VeevaMember member,
    VeevaAdminUser? adminUser,
  }) async {}

  @override
  Future<void> deleteMember(VeevaMember member) async {}

  @override
  Future<void> saveEmployeeStatus({
    required VeevaMember member,
    required bool enabled,
  }) async {}

  @override
  Future<VeevaEmployeeActivityLink> createEmployeeActivityLink({
    required VeevaMember employee,
    required VeevaActivity activity,
  }) async {
    final code = _employeeActivityLinkCode(
      employeeId: employee.id,
      activityId: activity.id,
      employeeCode: employee.employeeCode,
    );
    return VeevaEmployeeActivityLink(
      id: code,
      code: code,
      employeeMemberId: employee.id,
      employeeName: employee.name,
      employeeAvatarUrl: employee.avatarUrl,
      activityId: activity.id,
      activityTitle: activity.title,
      url: _employeeLiffUrlForCode(code),
    );
  }

  @override
  Future<void> grantRewardToMember({
    required VeevaMember member,
    required VeevaReward reward,
    required int quantity,
    String? note,
    VeevaActivity? activity,
    VeevaMember? sourceMember,
    String source = 'manualAdmin',
    bool preventDuplicate = false,
    bool sendLineMessage = true,
    String lineMessageType = 'system',
    String? lineMessageTemplateId,
    Map<String, Object?>? lineMessageSnapshot,
  }) async {}

  @override
  Future<void> sendLineMessageTest({
    required VeevaMember member,
    required String messageType,
    required Map<String, Object?> messageSnapshot,
  }) async {}

  @override
  Stream<List<VeevaLineChatMessage>> watchLineConversation(
    String lineUserId,
  ) {
    return Stream.value(const <VeevaLineChatMessage>[]);
  }

  @override
  Stream<List<VeevaLineConversationSummary>> watchLineConversationSummaries() {
    return Stream.value(const <VeevaLineConversationSummary>[]);
  }

  @override
  Future<void> markLineConversationRead(String lineUserId) async {}

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

String _shareCodeFromId(String id) {
  final compact = id.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toUpperCase();
  if (compact.length >= 5) {
    return compact.substring(compact.length - 5);
  }
  return compact.padRight(5, 'X');
}

String _employeeCodeFromId(String id) {
  final compact = id.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toUpperCase();
  if (compact.length >= 6) {
    return 'EMP${compact.substring(compact.length - 6)}';
  }
  return 'EMP${compact.padRight(6, 'X')}';
}

String _employeeActivityLinkCode({
  required String employeeId,
  required String activityId,
  String? employeeCode,
}) {
  final prefix = (employeeCode?.trim().isNotEmpty == true
          ? employeeCode!.trim()
          : _employeeCodeFromId(employeeId))
      .replaceAll(RegExp('[^a-zA-Z0-9]'), '')
      .toUpperCase();
  final hash = _stableLinkHash('$employeeId|$activityId').toUpperCase();
  return '$prefix${hash.substring(0, 6)}';
}

String _employeeLiffUrlForCode(String code) {
  const memberLiffId = String.fromEnvironment(
    'MEMBER_LIFF_ID',
    defaultValue: '2010298394-7PwRtpTY',
  );
  return 'https://liff.line.me/$memberLiffId/e/$code';
}

int _readIntLike(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _dedupeVoucherLinks(Iterable<String> links) {
  final seen = <String>{};
  final results = <String>[];
  for (final rawLink in links) {
    final link = rawLink.trim();
    if (link.isEmpty || !seen.add(link)) {
      continue;
    }
    results.add(link);
  }
  return results;
}

String _voucherDocumentId(String rewardId, String link) {
  return '${_firestoreDocumentSegment(rewardId)}-${_stableLinkHash(link)}';
}

String _stableLinkHash(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _rewardGrantDocumentId({
  required String memberId,
  required String rewardId,
  required String activityId,
  required String source,
  String? sourceMemberId,
}) {
  return [
    memberId,
    rewardId,
    activityId,
    source,
    sourceMemberId ?? 'self',
  ].map(_firestoreDocumentSegment).join('_');
}

String _activityCompletionDocumentId({
  required String memberId,
  required String activityId,
}) {
  return [memberId, activityId].map(_firestoreDocumentSegment).join('_');
}

String _memberNotificationDocumentId({
  required String memberId,
  required String eventId,
}) {
  return [memberId, eventId].map(_firestoreDocumentSegment).join('_');
}

String _rewardIssuedNotificationBody({
  required VeevaReward reward,
  VeevaActivity? activity,
  required String source,
}) {
  if (source == 'referralActivityCompletion' && activity != null) {
    return '你的邀請獎勵已確認，已收到「${reward.name}」兌換券。';
  }
  if (activity != null) {
    return '「${activity.title}」已確認完成，已收到「${reward.name}」兌換券。';
  }
  return '你已收到「${reward.name}」兌換券。';
}

String _activityRejectedNotificationBody(VeevaActivityRecord record) {
  if (record.activityType == VeevaActivityType.survey.name ||
      record.activityTitle.contains('問卷')) {
    return '「${record.activityTitle}」未通過確認，請重新填寫問卷後再送出。';
  }
  return '「${record.activityTitle}」未通過確認，請重新完成活動後再送出。';
}

String _firestoreDocumentSegment(String value) {
  final segment = value.trim().replaceAll(RegExp(r'[/#?\[\]]'), '_');
  return segment.isEmpty ? 'unknown' : segment;
}

final defaultActivities = <VeevaActivity>[
  const VeevaActivity(
    id: 'survey-coffee',
    type: VeevaActivityType.survey,
    label: '限時活動',
    title: '填問卷，拿咖啡券',
    description: '完成問卷並通過資格確認後，即可獲得咖啡兌換券。分享給朋友，朋友完成後你再得 1 張。',
    reward: '咖啡兌換券',
    completionRewardId: 'COFFEE-8X2L',
    referrerRewardId: 'COFFEE-8X2L',
    surveyUrl: defaultVeevaSurveyUrl,
    status: VeevaContentStatus.published,
    active: true,
    periodText: '2026/05/01 - 2026/06/30',
    note: '完成問卷後發放兌換券',
    noticeItems: [
      '完成問卷後，系統會依活動規則確認紀錄。',
      '若活動包含兌換券，將於人工確認後發放。',
      '如有任何問題，請聯繫主辦單位。',
    ],
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
    noticeItems: [
      '本活動名額有限，請盡早完成報名。',
      '完成報名後，活動前一週將寄發行前通知。',
      '如有任何問題，請聯繫主辦單位。',
    ],
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
    noticeItems: [
      '請依活動說明完成指定流程。',
      '活動紀錄將以系統實際完成狀態為準。',
      '如有任何問題，請聯繫主辦單位。',
    ],
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
