import 'package:cloud_firestore/cloud_firestore.dart';

enum VeevaMemberStatus { guest, loggedIn, pendingReview, verified }

enum VeevaReviewStatus { pending, approved, rejected }

enum VeevaRewardStatus { active, paused, expired }

enum VeevaContentStatus { draft, scheduled, published, archived }

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

class VeevaBootstrap {
  const VeevaBootstrap({
    required this.activities,
    required this.news,
    required this.rewards,
    required this.reviews,
  });

  final List<VeevaActivity> activities;
  final List<VeevaNews> news;
  final List<VeevaReward> rewards;
  final List<VeevaReview> reviews;
}

class VeevaMember {
  const VeevaMember({
    required this.id,
    required this.name,
    required this.hospital,
    required this.department,
    required this.status,
    required this.earnedCoupons,
    required this.invitedCount,
    required this.shareCode,
    this.lineUserId,
    this.avatarUrl,
    this.email,
    this.lineStatusMessage,
    this.lineIdToken,
    this.lineIdTokenUpdatedAt,
    this.lastLineLoginAt,
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
      earnedCoupons: _readInt(data['earnedCoupons']),
      invitedCount: _readInt(data['invitedCount']),
      shareCode: data['shareCode']?.toString() ?? id.substring(0, 5),
      lineUserId: data['lineUserId']?.toString(),
      avatarUrl: data['avatarUrl']?.toString(),
      email: data['email']?.toString(),
      lineStatusMessage: data['lineStatusMessage']?.toString(),
      lineIdToken: data['lineIdToken']?.toString(),
      lineIdTokenUpdatedAt: _readDate(data['lineIdTokenUpdatedAt']),
      lastLineLoginAt: _readDate(data['lastLineLoginAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  final String id;
  final String name;
  final String hospital;
  final String department;
  final VeevaMemberStatus status;
  final int earnedCoupons;
  final int invitedCount;
  final String shareCode;
  final String? lineUserId;
  final String? avatarUrl;
  final String? email;
  final String? lineStatusMessage;
  final String? lineIdToken;
  final DateTime? lineIdTokenUpdatedAt;
  final DateTime? lastLineLoginAt;
  final DateTime? updatedAt;

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'hospital': hospital,
      'department': department,
      'status': status.name,
      'earnedCoupons': earnedCoupons,
      'invitedCount': invitedCount,
      'shareCode': shareCode,
      'lineUserId': lineUserId,
      'avatarUrl': avatarUrl,
      'email': email,
      'lineStatusMessage': lineStatusMessage,
      'lineIdToken': lineIdToken,
      'lineIdTokenUpdatedAt': lineIdTokenUpdatedAt == null
          ? null
          : Timestamp.fromDate(lineIdTokenUpdatedAt!),
      'lastLineLoginAt':
          lastLineLoginAt == null ? null : Timestamp.fromDate(lastLineLoginAt!),
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
    );
  }

  final String id;
  final String memberId;
  final String name;
  final String hospital;
  final String department;
  final VeevaReviewStatus status;
  final DateTime completedAt;

  Map<String, Object?> toMap() {
    return {
      'memberId': memberId,
      'name': name,
      'hospital': hospital,
      'department': department,
      'status': status.name,
      'completedAt': Timestamp.fromDate(completedAt),
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
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class VeevaActivity {
  const VeevaActivity({
    required this.id,
    required this.label,
    required this.title,
    required this.description,
    required this.reward,
    required this.status,
    required this.active,
    this.periodText,
    this.note,
    this.imageUrl,
  });

  factory VeevaActivity.fromMap(String id, Map<String, Object?> data) {
    return VeevaActivity(
      id: id,
      label: data['label']?.toString() ?? '活動',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      reward: data['reward']?.toString() ?? '',
      status: _readEnum(
        VeevaContentStatus.values,
        data['status'],
        VeevaContentStatus.published,
      ),
      active: data['active'] == true,
      periodText: data['periodText']?.toString(),
      note: data['note']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
    );
  }

  final String id;
  final String label;
  final String title;
  final String description;
  final String reward;
  final VeevaContentStatus status;
  final bool active;
  final String? periodText;
  final String? note;
  final String? imageUrl;

  Map<String, Object?> toMap() {
    return {
      'label': label,
      'title': title,
      'description': description,
      'reward': reward,
      'status': status.name,
      'active': active,
      'periodText': periodText,
      'note': note,
      'imageUrl': imageUrl,
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

  Map<String, Object?> toMap() {
    return {
      'date': date,
      'source': source,
      'title': title,
      'summary': summary,
      'status': status.name,
      'category': category,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
