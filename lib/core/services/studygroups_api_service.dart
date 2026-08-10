import 'dart:convert';

import 'app_api_client.dart';

class StudyGroupsException implements Exception {
  const StudyGroupsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StudyGroup {
  const StudyGroup({
    required this.slug,
    required this.name,
    required this.description,
    required this.course,
    required this.isPublic,
    required this.isVerified,
    required this.memberCount,
    required this.creator,
  });
  final String slug;
  final String name;
  final String description;
  final String course;
  final bool isPublic;
  final bool isVerified;
  final int memberCount;
  final String creator;

  factory StudyGroup.fromJson(Map<String, dynamic> j) => StudyGroup(
        slug: j['slug'] as String,
        name: j['name'] as String,
        description: (j['description'] ?? '') as String,
        course: (j['course'] ?? '') as String,
        isPublic: j['is_public'] as bool,
        isVerified: j['is_verified'] as bool,
        memberCount: j['member_count'] as int,
        creator: j['creator'] as String,
      );
}

class GroupInvite {
  const GroupInvite({
    required this.id,
    required this.groupSlug,
    required this.groupName,
    required this.invitedBy,
  });
  final int id;
  final String groupSlug;
  final String groupName;
  final String invitedBy;

  factory GroupInvite.fromJson(Map<String, dynamic> j) => GroupInvite(
        id: j['id'] as int,
        groupSlug: j['group_slug'] as String,
        groupName: j['group_name'] as String,
        invitedBy: j['invited_by'] as String,
      );
}

class GroupsDirectory {
  const GroupsDirectory({
    required this.myGroups,
    required this.publicGroups,
    required this.pendingInvites,
    required this.isSubscriber,
  });
  final List<StudyGroup> myGroups;
  final List<StudyGroup> publicGroups;
  final List<GroupInvite> pendingInvites;
  final bool isSubscriber;

  factory GroupsDirectory.fromJson(Map<String, dynamic> j) => GroupsDirectory(
        myGroups:
            (j['my_groups'] as List).map((e) => StudyGroup.fromJson(e as Map<String, dynamic>)).toList(),
        publicGroups: (j['public_groups'] as List)
            .map((e) => StudyGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        pendingInvites: (j['pending_invites'] as List)
            .map((e) => GroupInvite.fromJson(e as Map<String, dynamic>))
            .toList(),
        isSubscriber: j['is_subscriber'] as bool,
      );
}

class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.author,
    required this.authorId,
    required this.body,
    required this.imageUrl,
    required this.createdAt,
  });
  final int id;
  final String author;
  final int authorId;
  final String body;
  final String imageUrl;
  final String createdAt;

  factory GroupMessage.fromJson(Map<String, dynamic> j) => GroupMessage(
        id: j['id'] as int,
        author: j['author'] as String,
        authorId: j['author_id'] as int,
        body: (j['body'] ?? '') as String,
        imageUrl: (j['image_url'] ?? '') as String,
        createdAt: j['created_at'] as String,
      );
}

class GroupMember {
  const GroupMember({required this.userId, required this.name, required this.role});
  final int userId;
  final String name;
  final String role;

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        userId: j['user_id'] as int,
        name: j['name'] as String,
        role: j['role'] as String,
      );
}

class GroupDetail {
  const GroupDetail({
    required this.group,
    required this.isMember,
    required this.isAdmin,
    required this.isSubscriber,
    required this.messages,
    required this.members,
  });
  final StudyGroup group;
  final bool isMember;
  final bool isAdmin;
  final bool isSubscriber;
  final List<GroupMessage> messages;
  final List<GroupMember> members;

  factory GroupDetail.fromJson(Map<String, dynamic> j) => GroupDetail(
        group: StudyGroup.fromJson(j['group'] as Map<String, dynamic>),
        isMember: j['is_member'] as bool,
        isAdmin: j['is_admin'] as bool,
        isSubscriber: j['is_subscriber'] as bool,
        messages: (j['messages'] as List)
            .map((e) => GroupMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        members:
            (j['members'] as List).map((e) => GroupMember.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Mirrors studygroups/views.py — text messaging only for v1 (see
/// studygroups/api_views.py for why images/forwarding aren't here yet).
class StudyGroupsApiService {
  StudyGroupsApiService._();
  static final StudyGroupsApiService instance = StudyGroupsApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppApiException catch (e) {
      throw StudyGroupsException(e.message);
    }
  }

  Future<GroupsDirectory> list({String query = ''}) => _run(() async {
        final resp = await _client.request(
            'GET', '/api/studygroups/${query.isEmpty ? '' : '?q=$query'}');
        _client.checkOk(resp);
        return GroupsDirectory.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      });

  Future<String> createGroup({
    required String name,
    required String description,
    required String course,
    required bool isPublic,
  }) =>
      _run(() async {
        final resp = await _client.request('POST', '/api/studygroups/create/', body: {
          'name': name,
          'description': description,
          'course': course,
          'is_public': isPublic,
        });
        _client.checkOk(resp,
            subscriptionMessage: 'Creating a group is for subscribers. Subscribe to unlock it.');
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['slug'] as String;
      });

  Future<GroupDetail> detail(String slug) => _run(() async {
        final resp = await _client.request('GET', '/api/studygroups/$slug/');
        _client.checkOk(resp);
        return GroupDetail.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      });

  Future<void> join(String slug) => _run(() async {
        final resp = await _client.request('POST', '/api/studygroups/$slug/join/');
        _client.checkOk(resp);
      });

  Future<void> leave(String slug) => _run(() async {
        final resp = await _client.request('POST', '/api/studygroups/$slug/leave/');
        _client.checkOk(resp);
      });

  Future<void> deleteGroup(String slug) => _run(() async {
        final resp = await _client.request('POST', '/api/studygroups/$slug/delete/');
        _client.checkOk(resp);
      });

  Future<GroupMessage> postMessage(String slug, String body) => _run(() async {
        final resp =
            await _client.request('POST', '/api/studygroups/$slug/post/', body: {'body': body});
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return GroupMessage.fromJson(data['message'] as Map<String, dynamic>);
      });

  Future<void> deleteMessage(String slug, int messageId) => _run(() async {
        final resp =
            await _client.request('POST', '/api/studygroups/$slug/message/$messageId/delete/');
        _client.checkOk(resp);
      });

  Future<void> invite(String slug, String identifier) => _run(() async {
        final resp = await _client.request('POST', '/api/studygroups/$slug/invite/',
            body: {'identifier': identifier});
        _client.checkOk(resp);
      });

  Future<String?> respondInvite(int inviteId, bool accept) => _run(() async {
        final resp = await _client.request(
            'POST', '/api/studygroups/invite/$inviteId/respond/',
            body: {'action': accept ? 'accept' : 'decline'});
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['group_slug'] as String?;
      });
}
