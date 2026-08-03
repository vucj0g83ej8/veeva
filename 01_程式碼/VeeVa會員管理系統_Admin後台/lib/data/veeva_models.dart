import 'package:cloud_firestore/cloud_firestore.dart';

enum VeevaMemberStatus { guest, loggedIn, pendingReview, verified }

enum VeevaMemberAccountStatus { active, disabled }

enum VeevaReviewStatus { pending, approved, rejected }

enum VeevaRewardStatus { active, paused, expired }

enum VeevaContentStatus { draft, scheduled, published, archived }

enum VeevaActivityType {
  survey,
  registration,
  referral,
  task,
  checkin,
  external
}

enum VeevaAdminRole { owner, manager, editor, viewer }

enum VeevaAdminStatus { active, disabled }

enum VeevaLineChatDirection { incoming, outgoing }

class VeevaLineConversationSummary {
  const VeevaLineConversationSummary({
    required this.lineUserId,
    required this.unreadCount,
    this.lastMessage,
    this.lastDirection,
    this.lastMessageAt,
  });

  factory VeevaLineConversationSummary.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return VeevaLineConversationSummary(
      lineUserId: data['lineUserId']?.toString() ?? id,
      unreadCount: _readInt(data['unreadCount']),
      lastMessage: data['lastMessage']?.toString(),
      lastDirection: data['lastDirection']?.toString(),
      lastMessageAt: _readDate(data['lastMessageAt']),
    );
  }

  final String lineUserId;
  final int unreadCount;
  final String? lastMessage;
  final String? lastDirection;
  final DateTime? lastMessageAt;
}

class VeevaLineChatMessage {
  const VeevaLineChatMessage({
    required this.id,
    required this.lineUserId,
    required this.direction,
    required this.type,
    required this.text,
    required this.sentAt,
    this.memberId,
    this.memberName,
    this.messageSnapshot,
  });

  factory VeevaLineChatMessage.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return VeevaLineChatMessage(
      id: id,
      lineUserId: data['lineUserId']?.toString() ?? '',
      direction: _readEnum(
        VeevaLineChatDirection.values,
        data['direction'],
        VeevaLineChatDirection.incoming,
      ),
      type: data['type']?.toString() ?? 'text',
      text: data['text']?.toString() ?? '',
      sentAt: _readDate(data['sentAt']) ??
          _readDate(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      memberId: data['memberId']?.toString(),
      memberName: data['memberName']?.toString(),
      messageSnapshot: data['messageSnapshot'] is Map
          ? Map<String, Object?>.from(data['messageSnapshot'] as Map)
          : null,
    );
  }

  final String id;
  final String lineUserId;
  final VeevaLineChatDirection direction;
  final String type;
  final String text;
  final DateTime sentAt;
  final String? memberId;
  final String? memberName;
  final Map<String, Object?>? messageSnapshot;

  bool get isIncoming => direction == VeevaLineChatDirection.incoming;
}

DateTime? _readDate(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

int _readInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _readBool(Object? value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

T _readEnum<T extends Enum>(
  List<T> values,
  Object? value,
  T fallback,
) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return values.firstWhere(
    (item) => item.name == text,
    orElse: () => fallback,
  );
}

VeevaActivityType _readActivityType(
  Object? value, {
  required String id,
  required String title,
  required String label,
}) {
  final explicit =
      _readEnum(VeevaActivityType.values, value, VeevaActivityType.survey);
  if (value != null && value.toString().trim().isNotEmpty) {
    return explicit;
  }
  final text = '$id $title $label'.toLowerCase();
  if (text.contains('survey') || text.contains('問卷')) {
    return VeevaActivityType.survey;
  }
  if (text.contains('referral') || text.contains('邀請')) {
    return VeevaActivityType.referral;
  }
  if (text.contains('checkin') || text.contains('簽到')) {
    return VeevaActivityType.checkin;
  }
  if (text.contains('task') || text.contains('任務')) {
    return VeevaActivityType.task;
  }
  if (text.contains('external') || text.contains('外部')) {
    return VeevaActivityType.external;
  }
  return VeevaActivityType.registration;
}

List<String> _readStringList(Object? value) {
  if (value is Iterable) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}

String? _readFirstString(Map<String, Object?> data, List<String> keys) {
  for (final key in keys) {
    final text = data[key]?.toString().trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

class VeevaBootstrap {
  const VeevaBootstrap({
    required this.activities,
    required this.news,
    required this.rewards,
    required this.reviews,
    required this.members,
    required this.adminUsers,
    required this.activityRecords,
    required this.memberRewards,
    required this.employeeLinks,
    this.employeeAttributions = const [],
    required this.clientSettings,
  });

  final List<VeevaActivity> activities;
  final List<VeevaNews> news;
  final List<VeevaReward> rewards;
  final List<VeevaReview> reviews;
  final List<VeevaMember> members;
  final List<VeevaAdminUser> adminUsers;
  final List<VeevaActivityRecord> activityRecords;
  final List<VeevaMemberReward> memberRewards;
  final List<VeevaEmployeeActivityLink> employeeLinks;
  final List<VeevaMemberEmployeeAttribution> employeeAttributions;
  final VeevaClientSettings clientSettings;
}

class VeevaLineRichMessage {
  const VeevaLineRichMessage({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.targetUrl,
    required this.altText,
  });

  factory VeevaLineRichMessage.fromMap(Map<String, Object?> data) {
    return VeevaLineRichMessage(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '未命名圖文訊息',
      imageUrl: data['imageUrl']?.toString() ?? '',
      targetUrl: data['targetUrl']?.toString() ?? '',
      altText: data['altText']?.toString() ?? '',
    );
  }

  final String id;
  final String title;
  final String imageUrl;
  final String targetUrl;
  final String altText;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'imageUrl': imageUrl,
        'targetUrl': targetUrl,
        'altText': altText,
      };
}

class VeevaLineCarouselCard {
  const VeevaLineCarouselCard({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.actionLabel,
    required this.actionUrl,
  });

  factory VeevaLineCarouselCard.fromMap(Map<String, Object?> data) {
    return VeevaLineCarouselCard(
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      actionLabel: data['actionLabel']?.toString() ?? '立即查看',
      actionUrl: data['actionUrl']?.toString() ?? '',
    );
  }

  final String title;
  final String description;
  final String imageUrl;
  final String actionLabel;
  final String actionUrl;

  Map<String, Object?> toMap() => {
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'actionLabel': actionLabel,
        'actionUrl': actionUrl,
      };
}

class VeevaLineCarouselMessage {
  const VeevaLineCarouselMessage({
    required this.id,
    required this.title,
    required this.templateId,
    required this.altText,
    required this.cards,
  });

  factory VeevaLineCarouselMessage.fromMap(Map<String, Object?> data) {
    final rawCards = data['cards'];
    return VeevaLineCarouselMessage(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '未命名多頁訊息',
      templateId: data['templateId']?.toString() ?? 'standard',
      altText: data['altText']?.toString() ?? '',
      cards: rawCards is Iterable
          ? rawCards
              .whereType<Map>()
              .map((item) => VeevaLineCarouselCard.fromMap(
                    Map<String, Object?>.from(item),
                  ))
              .toList()
          : const [],
    );
  }

  final String id;
  final String title;
  final String templateId;
  final String altText;
  final List<VeevaLineCarouselCard> cards;

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'templateId': templateId,
        'altText': altText,
        'cards': cards.map((item) => item.toMap()).toList(),
      };
}

class VeevaClientSettings {
  const VeevaClientSettings({
    this.newsEnabled = true,
    this.lineRichMessages = const [],
    this.lineCarouselMessages = const [],
  });

  factory VeevaClientSettings.fromMap(Map<String, Object?> data) {
    List<T> readItems<T>(
        Object? value, T Function(Map<String, Object?>) fromMap) {
      if (value is! Iterable) return const [];
      return value
          .whereType<Map>()
          .map((item) => fromMap(Map<String, Object?>.from(item)))
          .toList();
    }

    return VeevaClientSettings(
      newsEnabled: data['newsEnabled'] != false,
      lineRichMessages: readItems(
        data['lineRichMessages'],
        VeevaLineRichMessage.fromMap,
      ),
      lineCarouselMessages: readItems(
        data['lineCarouselMessages'],
        VeevaLineCarouselMessage.fromMap,
      ),
    );
  }

  final bool newsEnabled;
  final List<VeevaLineRichMessage> lineRichMessages;
  final List<VeevaLineCarouselMessage> lineCarouselMessages;

  VeevaClientSettings copyWith({
    bool? newsEnabled,
    List<VeevaLineRichMessage>? lineRichMessages,
    List<VeevaLineCarouselMessage>? lineCarouselMessages,
  }) {
    return VeevaClientSettings(
      newsEnabled: newsEnabled ?? this.newsEnabled,
      lineRichMessages: lineRichMessages ?? this.lineRichMessages,
      lineCarouselMessages: lineCarouselMessages ?? this.lineCarouselMessages,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'newsEnabled': newsEnabled,
      'lineRichMessages': lineRichMessages.map((item) => item.toMap()).toList(),
      'lineCarouselMessages':
          lineCarouselMessages.map((item) => item.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class VeevaMember {
  const VeevaMember({
    required this.id,
    required this.name,
    required this.hospital,
    required this.department,
    required this.status,
    this.accountStatus = VeevaMemberAccountStatus.active,
    required this.earnedCoupons,
    required this.invitedCount,
    required this.shareCode,
    this.lineUserId,
    this.avatarUrl,
    this.email,
    this.phoneNumber,
    this.phoneVerified = false,
    this.phoneVerifiedAt,
    this.lineStatusMessage,
    this.lineIdToken,
    this.lineIdTokenUpdatedAt,
    this.createdAt,
    this.lastLineLoginAt,
    this.referredByMemberId,
    this.referredByShareCode,
    this.referredAt,
    this.referralRewardGrantedActivityId,
    this.referralRewardGrantedRewardId,
    this.referralRewardGrantedReferrerId,
    this.referralRewardGrantedAt,
    this.isAdmin = false,
    this.adminRole,
    this.isEmployee = false,
    this.employeeStatus,
    this.employeeCode,
    this.employeeCreatedAt,
    this.updatedAt,
  });

  factory VeevaMember.fromMap(String id, Map<String, Object?> data) {
    return VeevaMember(
      id: id,
      name: data['name']?.toString() ?? 'LINE 會員',
      hospital: data['hospital']?.toString() ?? '',
      department: data['department']?.toString() ?? '',
      status: _readEnum(
        VeevaMemberStatus.values,
        data['status'],
        VeevaMemberStatus.loggedIn,
      ),
      accountStatus: _readEnum(
        VeevaMemberAccountStatus.values,
        data['accountStatus'],
        VeevaMemberAccountStatus.active,
      ),
      earnedCoupons: _readInt(data['earnedCoupons']),
      invitedCount: _readInt(data['invitedCount']),
      shareCode: data['shareCode']?.toString() ?? id.substring(0, 5),
      lineUserId: data['lineUserId']?.toString(),
      avatarUrl: data['avatarUrl']?.toString(),
      email: data['email']?.toString(),
      phoneNumber: _readFirstString(data, const [
        'phoneNumber',
        'phone',
        'mobile',
        'mobileNumber',
        'tel',
        'verifiedPhoneNumber',
        'verifiedPhone',
        'verifiedPhoneE164',
        'phoneVerifiedNumber',
        'phoneE164',
        'phoneE164Number',
        'phoneAuthNumber',
        'authPhoneNumber',
        'firebasePhoneNumber',
        'smsPhoneNumber',
      ]),
      phoneVerified: _readBool(data['phoneVerified']) ||
          _readDate(data['phoneVerifiedAt']) != null,
      phoneVerifiedAt: _readDate(data['phoneVerifiedAt']),
      lineStatusMessage: data['lineStatusMessage']?.toString(),
      lineIdToken: data['lineIdToken']?.toString(),
      lineIdTokenUpdatedAt: _readDate(data['lineIdTokenUpdatedAt']),
      createdAt: _readDate(data['createdAt']),
      lastLineLoginAt: _readDate(data['lastLineLoginAt']),
      referredByMemberId: data['referredByMemberId']?.toString(),
      referredByShareCode: data['referredByShareCode']?.toString(),
      referredAt: _readDate(data['referredAt']),
      referralRewardGrantedActivityId:
          data['referralRewardGrantedActivityId']?.toString(),
      referralRewardGrantedRewardId:
          data['referralRewardGrantedRewardId']?.toString(),
      referralRewardGrantedReferrerId:
          data['referralRewardGrantedReferrerId']?.toString(),
      referralRewardGrantedAt: _readDate(data['referralRewardGrantedAt']),
      isAdmin: data['isAdmin'] == true,
      adminRole: data['adminRole']?.toString(),
      isEmployee: data['isEmployee'] == true,
      employeeStatus: data['employeeStatus']?.toString(),
      employeeCode: data['employeeCode']?.toString(),
      employeeCreatedAt: _readDate(data['employeeCreatedAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  final String id;
  final String name;
  final String hospital;
  final String department;
  final VeevaMemberStatus status;
  final VeevaMemberAccountStatus accountStatus;
  final int earnedCoupons;
  final int invitedCount;
  final String shareCode;
  final String? lineUserId;
  final String? avatarUrl;
  final String? email;
  final String? phoneNumber;
  final bool phoneVerified;
  final DateTime? phoneVerifiedAt;
  final String? lineStatusMessage;
  final String? lineIdToken;
  final DateTime? lineIdTokenUpdatedAt;
  final DateTime? createdAt;
  final DateTime? lastLineLoginAt;
  final String? referredByMemberId;
  final String? referredByShareCode;
  final DateTime? referredAt;
  final String? referralRewardGrantedActivityId;
  final String? referralRewardGrantedRewardId;
  final String? referralRewardGrantedReferrerId;
  final DateTime? referralRewardGrantedAt;
  final bool isAdmin;
  final String? adminRole;
  final bool isEmployee;
  final String? employeeStatus;
  final String? employeeCode;
  final DateTime? employeeCreatedAt;
  final DateTime? updatedAt;

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'hospital': hospital,
      'department': department,
      'status': status.name,
      'accountStatus': accountStatus.name,
      'earnedCoupons': earnedCoupons,
      'invitedCount': invitedCount,
      'shareCode': shareCode,
      'lineUserId': lineUserId,
      'avatarUrl': avatarUrl,
      'email': email,
      'phoneNumber': phoneNumber,
      'phoneVerified': phoneVerified,
      'phoneVerifiedAt':
          phoneVerifiedAt == null ? null : Timestamp.fromDate(phoneVerifiedAt!),
      'lineStatusMessage': lineStatusMessage,
      'lineIdToken': lineIdToken,
      'lineIdTokenUpdatedAt': lineIdTokenUpdatedAt == null
          ? null
          : Timestamp.fromDate(lineIdTokenUpdatedAt!),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'lastLineLoginAt':
          lastLineLoginAt == null ? null : Timestamp.fromDate(lastLineLoginAt!),
      'referredByMemberId': referredByMemberId,
      'referredByShareCode': referredByShareCode,
      'referredAt': referredAt == null ? null : Timestamp.fromDate(referredAt!),
      'referralRewardGrantedActivityId': referralRewardGrantedActivityId,
      'referralRewardGrantedRewardId': referralRewardGrantedRewardId,
      'referralRewardGrantedReferrerId': referralRewardGrantedReferrerId,
      'referralRewardGrantedAt': referralRewardGrantedAt == null
          ? null
          : Timestamp.fromDate(referralRewardGrantedAt!),
      'isAdmin': isAdmin,
      'adminRole': adminRole,
      'isEmployee': isEmployee,
      'employeeStatus': employeeStatus,
      'employeeCode': employeeCode,
      'employeeCreatedAt': employeeCreatedAt == null
          ? null
          : Timestamp.fromDate(employeeCreatedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class VeevaEmployeeActivityLink {
  const VeevaEmployeeActivityLink({
    required this.id,
    required this.code,
    required this.employeeMemberId,
    required this.employeeName,
    required this.activityId,
    required this.activityTitle,
    required this.url,
    this.employeeAvatarUrl,
    this.status = 'active',
    this.visitCount = 0,
    this.registeredCount = 0,
    this.phoneVerifiedCount = 0,
    this.lastVisitedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory VeevaEmployeeActivityLink.fromMap(
    String id,
    Map<String, Object?> data,
  ) {
    return VeevaEmployeeActivityLink(
      id: id,
      code: data['code']?.toString() ?? id,
      employeeMemberId: data['employeeMemberId']?.toString() ?? '',
      employeeName: data['employeeName']?.toString() ?? '員工',
      employeeAvatarUrl: data['employeeAvatarUrl']?.toString(),
      activityId: data['activityId']?.toString() ?? '',
      activityTitle: data['activityTitle']?.toString() ?? '活動',
      url: data['url']?.toString() ?? '',
      status: data['status']?.toString() ?? 'active',
      visitCount: _readInt(data['visitCount']),
      registeredCount: _readInt(data['registeredCount']),
      phoneVerifiedCount: _readInt(data['phoneVerifiedCount']),
      lastVisitedAt: _readDate(data['lastVisitedAt']),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  final String id;
  final String code;
  final String employeeMemberId;
  final String employeeName;
  final String? employeeAvatarUrl;
  final String activityId;
  final String activityTitle;
  final String url;
  final String status;
  final int visitCount;
  final int registeredCount;
  final int phoneVerifiedCount;
  final DateTime? lastVisitedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class VeevaActivityRecord {
  const VeevaActivityRecord({
    required this.id,
    required this.activityId,
    required this.activityTitle,
    required this.activityType,
    required this.memberId,
    required this.memberName,
    required this.status,
    this.memberAvatarUrl,
    this.memberLineUserId,
    this.registeredAt,
    this.completedAt,
    this.updatedAt,
  });

  factory VeevaActivityRecord.fromMap(
    String id,
    Map<String, Object?> data, {
    required String fallbackStatus,
  }) {
    return VeevaActivityRecord(
      id: id,
      activityId: data['activityId']?.toString() ?? '',
      activityTitle: data['activityTitle']?.toString() ?? '未命名活動',
      activityType: data['activityType']?.toString() ?? '',
      memberId: data['memberId']?.toString() ?? '',
      memberName: data['memberName']?.toString() ?? 'LINE 會員',
      memberAvatarUrl: data['memberAvatarUrl']?.toString(),
      memberLineUserId: data['memberLineUserId']?.toString(),
      status: data['status']?.toString() ?? fallbackStatus,
      registeredAt: _readDate(data['registeredAt']),
      completedAt: _readDate(data['completedAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  final String id;
  final String activityId;
  final String activityTitle;
  final String activityType;
  final String memberId;
  final String memberName;
  final String? memberAvatarUrl;
  final String? memberLineUserId;
  final String status;
  final DateTime? registeredAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  bool get isCompleted => status == 'completed';
}

class VeevaMemberEmployeeAttribution {
  const VeevaMemberEmployeeAttribution({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.employeeLinkId,
    required this.employeeMemberId,
    required this.employeeName,
    required this.activityId,
    required this.activityTitle,
    this.memberLineUserId,
    this.memberAvatarUrl,
    this.visitSessionId,
    this.registeredAt,
    this.phoneVerifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory VeevaMemberEmployeeAttribution.fromMap(
    String id,
    Map<String, Object?> data,
  ) {
    return VeevaMemberEmployeeAttribution(
      id: id,
      memberId: data['memberId']?.toString() ?? '',
      memberName: data['memberName']?.toString() ?? 'LINE 會員',
      memberLineUserId: data['memberLineUserId']?.toString(),
      memberAvatarUrl: data['memberAvatarUrl']?.toString(),
      employeeLinkId: data['employeeLinkId']?.toString() ?? '',
      employeeMemberId: data['employeeMemberId']?.toString() ?? '',
      employeeName: data['employeeName']?.toString() ?? '員工',
      activityId: data['activityId']?.toString() ?? '',
      activityTitle: data['activityTitle']?.toString() ?? '活動',
      visitSessionId: data['visitSessionId']?.toString(),
      registeredAt: _readDate(data['registeredAt']),
      phoneVerifiedAt: _readDate(data['phoneVerifiedAt']),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  final String id;
  final String memberId;
  final String memberName;
  final String? memberLineUserId;
  final String? memberAvatarUrl;
  final String employeeLinkId;
  final String employeeMemberId;
  final String employeeName;
  final String activityId;
  final String activityTitle;
  final String? visitSessionId;
  final DateTime? registeredAt;
  final DateTime? phoneVerifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class VeevaMemberReward {
  const VeevaMemberReward({
    required this.id,
    required this.memberId,
    required this.rewardId,
    required this.rewardName,
    required this.status,
    this.rewardImageUrl,
    this.source,
    this.activityId,
    this.activityTitle,
    this.sourceMemberId,
    this.sourceMemberName,
    this.redemptionUrl,
    this.voucherId,
    this.issuedAt,
    this.redeemedAt,
    this.expiresAt,
  });

  factory VeevaMemberReward.fromMap(String id, Map<String, Object?> data) {
    return VeevaMemberReward(
      id: id,
      memberId: data['memberId']?.toString() ?? '',
      rewardId: data['rewardId']?.toString() ?? '',
      rewardName: data['rewardName']?.toString() ?? '兌換券',
      rewardImageUrl:
          data['rewardImageUrl']?.toString() ?? data['imageUrl']?.toString(),
      status: data['status']?.toString() ?? 'issued',
      source: data['source']?.toString(),
      activityId: data['activityId']?.toString(),
      activityTitle: data['activityTitle']?.toString(),
      sourceMemberId: data['sourceMemberId']?.toString(),
      sourceMemberName: data['sourceMemberName']?.toString(),
      redemptionUrl: data['redemptionUrl']?.toString(),
      voucherId: data['voucherId']?.toString(),
      issuedAt: _readDate(data['issuedAt']),
      redeemedAt: _readDate(data['redeemedAt']),
      expiresAt: _readDate(data['expiresAt']),
    );
  }

  final String id;
  final String memberId;
  final String rewardId;
  final String rewardName;
  final String? rewardImageUrl;
  final String status;
  final String? source;
  final String? activityId;
  final String? activityTitle;
  final String? sourceMemberId;
  final String? sourceMemberName;
  final String? redemptionUrl;
  final String? voucherId;
  final DateTime? issuedAt;
  final DateTime? redeemedAt;
  final DateTime? expiresAt;
}

class VeevaAdminUser {
  const VeevaAdminUser({
    required this.id,
    required this.memberId,
    required this.lineUserId,
    required this.name,
    required this.role,
    required this.status,
    required this.permissions,
    this.email,
    this.avatarUrl,
    this.grantedAt,
    this.updatedAt,
  });

  factory VeevaAdminUser.fromMap(String id, Map<String, Object?> data) {
    return VeevaAdminUser(
      id: id,
      memberId: data['memberId']?.toString() ?? id,
      lineUserId: data['lineUserId']?.toString() ?? id,
      name: data['name']?.toString() ?? 'LINE 會員',
      email: data['email']?.toString(),
      avatarUrl: data['avatarUrl']?.toString(),
      role: _readEnum(
        VeevaAdminRole.values,
        data['role'],
        VeevaAdminRole.viewer,
      ),
      status: _readEnum(
        VeevaAdminStatus.values,
        data['status'],
        VeevaAdminStatus.active,
      ),
      permissions: _readStringList(data['permissions']),
      grantedAt: _readDate(data['grantedAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  final String id;
  final String memberId;
  final String lineUserId;
  final String name;
  final String? email;
  final String? avatarUrl;
  final VeevaAdminRole role;
  final VeevaAdminStatus status;
  final List<String> permissions;
  final DateTime? grantedAt;
  final DateTime? updatedAt;

  Map<String, Object?> toMap() {
    return {
      'memberId': memberId,
      'lineUserId': lineUserId,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'role': role.name,
      'status': status.name,
      'permissions': permissions,
      'grantedAt': grantedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(grantedAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class VeevaReview {
  const VeevaReview({
    required this.id,
    required this.memberId,
    required this.name,
    required this.hospital,
    required this.department,
    required this.status,
    required this.completedAt,
    this.rewardIssueStatus,
    this.rewardIssueReason,
    this.rewardIssueUpdatedAt,
    this.rewardIssuedAt,
    this.rewardNotIssuedAt,
  });

  factory VeevaReview.fromMap(String id, Map<String, Object?> data) {
    return VeevaReview(
      id: id,
      memberId: data['memberId']?.toString() ?? id,
      name: data['name']?.toString() ?? 'LINE 會員',
      hospital: data['hospital']?.toString() ?? '',
      department: data['department']?.toString() ?? '',
      status: _readEnum(
        VeevaReviewStatus.values,
        data['status'],
        VeevaReviewStatus.pending,
      ),
      completedAt: _readDate(data['completedAt']) ?? DateTime.now(),
      rewardIssueStatus: data['rewardIssueStatus']?.toString(),
      rewardIssueReason: data['rewardIssueReason']?.toString(),
      rewardIssueUpdatedAt: _readDate(data['rewardIssueUpdatedAt']),
      rewardIssuedAt: _readDate(data['rewardIssuedAt']),
      rewardNotIssuedAt: _readDate(data['rewardNotIssuedAt']),
    );
  }

  final String id;
  final String memberId;
  final String name;
  final String hospital;
  final String department;
  final VeevaReviewStatus status;
  final DateTime completedAt;
  final String? rewardIssueStatus;
  final String? rewardIssueReason;
  final DateTime? rewardIssueUpdatedAt;
  final DateTime? rewardIssuedAt;
  final DateTime? rewardNotIssuedAt;

  Map<String, Object?> toMap() {
    return {
      'memberId': memberId,
      'name': name,
      'hospital': hospital,
      'department': department,
      'status': status.name,
      'completedAt': Timestamp.fromDate(completedAt),
      if (rewardIssueStatus != null) 'rewardIssueStatus': rewardIssueStatus,
      if (rewardIssueReason != null) 'rewardIssueReason': rewardIssueReason,
      if (rewardIssueUpdatedAt != null)
        'rewardIssueUpdatedAt': Timestamp.fromDate(rewardIssueUpdatedAt!),
      if (rewardIssuedAt != null)
        'rewardIssuedAt': Timestamp.fromDate(rewardIssuedAt!),
      if (rewardNotIssuedAt != null)
        'rewardNotIssuedAt': Timestamp.fromDate(rewardNotIssuedAt!),
    };
  }
}

class VeevaReward {
  const VeevaReward({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    required this.issued,
    required this.redeemed,
    required this.expiresAt,
    required this.status,
    this.imageUrl,
    this.requiresVerificationCode = false,
    this.voucherTotal = 0,
    this.voucherAvailable = 0,
    this.lineNotificationEnabled = true,
    this.lineMessageType = 'system',
    this.lineMessageTemplateId,
  });

  factory VeevaReward.fromMap(String id, Map<String, Object?> data) {
    return VeevaReward(
      id: id,
      name: data['name']?.toString() ?? '',
      category: data['category']?.toString() ?? '一般',
      stock: _readInt(data['stock']),
      issued: _readInt(data['issued']),
      redeemed: _readInt(data['redeemed']),
      expiresAt: _readDate(data['expiresAt']) ?? DateTime.now(),
      status: _readEnum(
        VeevaRewardStatus.values,
        data['status'],
        VeevaRewardStatus.active,
      ),
      imageUrl: data['imageUrl']?.toString(),
      requiresVerificationCode: data['requiresVerificationCode'] == true,
      voucherTotal: _readInt(data['voucherTotal']),
      voucherAvailable: _readInt(data['voucherAvailable']),
      lineNotificationEnabled: data['lineNotificationEnabled'] != false,
      lineMessageType: data['lineMessageType']?.toString() ?? 'system',
      lineMessageTemplateId: data['lineMessageTemplateId']?.toString(),
    );
  }

  final String id;
  final String name;
  final String category;
  final int stock;
  final int issued;
  final int redeemed;
  final DateTime expiresAt;
  final VeevaRewardStatus status;
  final String? imageUrl;
  final bool requiresVerificationCode;
  final int voucherTotal;
  final int voucherAvailable;
  final bool lineNotificationEnabled;
  final String lineMessageType;
  final String? lineMessageTemplateId;

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'category': category,
      'stock': stock,
      'issued': issued,
      'redeemed': redeemed,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status.name,
      'imageUrl': imageUrl,
      'requiresVerificationCode': requiresVerificationCode,
      'verificationCode': FieldValue.delete(),
      'voucherTotal': voucherTotal,
      'voucherAvailable': voucherAvailable,
      'lineNotificationEnabled': lineNotificationEnabled,
      'lineMessageType': lineMessageType,
      'lineMessageTemplateId': lineMessageTemplateId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class VeevaActivity {
  const VeevaActivity({
    required this.id,
    required this.type,
    required this.label,
    required this.title,
    required this.description,
    required this.reward,
    required this.status,
    required this.active,
    this.rewardId,
    this.completionRewardId,
    this.referrerRewardId,
    this.surveyUrl,
    this.actionUrl,
    this.periodText,
    this.location,
    this.activityTime,
    this.organizer,
    this.note,
    this.noticeItems = const [],
    this.imageUrl,
    this.shareImageUrl,
  });

  factory VeevaActivity.fromMap(String id, Map<String, Object?> data) {
    final title = data['title']?.toString() ?? '';
    final label = data['label']?.toString() ?? '活動';
    return VeevaActivity(
      id: id,
      type: _readActivityType(data['type'], id: id, title: title, label: label),
      label: label,
      title: title,
      description: data['description']?.toString() ?? '',
      reward: data['reward']?.toString() ?? '',
      rewardId: data['rewardId']?.toString(),
      completionRewardId: data['completionRewardId']?.toString(),
      referrerRewardId: data['referrerRewardId']?.toString(),
      surveyUrl: data['surveyUrl']?.toString(),
      actionUrl: data['actionUrl']?.toString(),
      status: _readEnum(
        VeevaContentStatus.values,
        data['status'],
        VeevaContentStatus.published,
      ),
      active: data['active'] == true,
      periodText: data['periodText']?.toString(),
      location: data['location']?.toString(),
      activityTime: data['activityTime']?.toString(),
      organizer: data['organizer']?.toString(),
      note: data['note']?.toString(),
      noticeItems: _readStringList(data['noticeItems']),
      imageUrl: data['imageUrl']?.toString(),
      shareImageUrl: data['shareImageUrl']?.toString(),
    );
  }

  final String id;
  final VeevaActivityType type;
  final String label;
  final String title;
  final String description;
  final String reward;
  final String? rewardId;
  final String? completionRewardId;
  final String? referrerRewardId;
  final String? surveyUrl;
  final String? actionUrl;
  final VeevaContentStatus status;
  final bool active;
  final String? periodText;
  final String? location;
  final String? activityTime;
  final String? organizer;
  final String? note;
  final List<String> noticeItems;
  final String? imageUrl;
  final String? shareImageUrl;

  Map<String, Object?> toMap() {
    return {
      'type': type.name,
      'label': label,
      'title': title,
      'description': description,
      'reward': reward,
      'rewardId': null,
      'completionRewardId': completionRewardId,
      'referrerRewardId': referrerRewardId,
      'surveyUrl': surveyUrl,
      'actionUrl': actionUrl,
      'status': status.name,
      'active': active,
      'periodText': periodText,
      'location': location,
      'activityTime': activityTime,
      'organizer': organizer,
      'note': note,
      'noticeItems': noticeItems,
      'imageUrl': imageUrl,
      'shareImageUrl': shareImageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class VeevaNews {
  const VeevaNews({
    required this.id,
    required this.date,
    required this.source,
    required this.title,
    required this.summary,
    required this.status,
    this.category,
    this.imageUrl,
    this.content,
    this.detailContent,
    this.keyPoints = const [],
    this.externalUrl,
    this.helpfulCount = 0,
  });

  factory VeevaNews.fromMap(String id, Map<String, Object?> data) {
    return VeevaNews(
      id: id,
      date: data['date']?.toString() ?? '',
      source: data['source']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      summary: data['summary']?.toString() ?? '',
      status: _readEnum(
        VeevaContentStatus.values,
        data['status'],
        VeevaContentStatus.published,
      ),
      category: data['category']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      content: data['content']?.toString(),
      detailContent: data['detailContent']?.toString(),
      keyPoints: _readStringList(data['keyPoints']),
      externalUrl: data['externalUrl']?.toString(),
      helpfulCount: _readInt(data['helpfulCount'], 0),
    );
  }

  final String id;
  final String date;
  final String source;
  final String title;
  final String summary;
  final VeevaContentStatus status;
  final String? category;
  final String? imageUrl;
  final String? content;
  final String? detailContent;
  final List<String> keyPoints;
  final String? externalUrl;
  final int helpfulCount;

  Map<String, Object?> toMap() {
    return {
      'date': date,
      'source': source,
      'title': title,
      'summary': summary,
      'status': status.name,
      'category': category,
      'imageUrl': imageUrl,
      'content': content,
      'detailContent': detailContent,
      'keyPoints': keyPoints,
      'externalUrl': externalUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
