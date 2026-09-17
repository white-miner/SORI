import 'package:flutter/material.dart';

import '../models/post_engagement_bindings.dart';
import '../models/session_user.dart';
import '../theme/sori_tokens.dart';
import '../utils/post_navigation.dart';
import '../widgets/community_comments_section.dart';
import '../widgets/post/post_view_data.dart';
import 'sori_store.dart';

/// Feed engagement facade — DB-backed likes/bookmarks/comments with disabled UX.
class EngagementService {
  EngagementService({
    required this.context,
    required this.store,
    this.onStateChanged,
    this.onBuyBoost,
    this.onBuyFanBoost,
    this.onMentoringRequest,
    this.onManageMentoring,
  });

  final BuildContext context;
  final SoriStore store;
  final VoidCallback? onStateChanged;
  final void Function(PostViewData data)? onBuyBoost;
  final void Function(PostViewData data)? onBuyFanBoost;
  final void Function(PostViewData data)? onMentoringRequest;
  final void Function(PostViewData data)? onManageMentoring;

  static const _preparing = '준비 중입니다';
  static const _noPermission = '권한이 없습니다';

  void _snack(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _notify() => onStateChanged?.call();

  PostEngagementBindings bindingsFor(PostViewData data) {
    final chartId = _chartId(data);
    final postId = store.resolveEngagementPostId(data);
    final session = store.session;
    final isDirector = session?.activeMode == UserRole.director;
    final isAuthor = chartId != null
        ? store.communityCaseForChart(chartId)?.isAuthoredBy(session?.id) ??
            false
        : false;

    final likeEnabled = chartId != null;
    final commentEnabled = postId != null;
    final bookmarkEnabled = chartId != null;
    final mentoringEnabled =
        data.hasActiveMentoring || (isDirector && chartId != null && !isAuthor);
    final boostEnabled = chartId != null;

    final liked = chartId != null && store.isChartLiked(chartId);
    final likeCount = chartId != null
        ? store.chartLikeCount(chartId, fallback: data.likeCount)
        : data.likeCount;
    final bookmarked =
        chartId != null ? store.isChartBookmarked(chartId) : false;

    return PostEngagementBindings(
      liked: liked,
      bookmarked: bookmarked,
      likeCount: likeCount,
      commentCount: data.commentCount,
      likeEnabled: likeEnabled,
      commentEnabled: commentEnabled,
      bookmarkEnabled: bookmarkEnabled,
      mentoringEnabled: mentoringEnabled,
      boostEnabled: boostEnabled,
      likeDisabledReason: likeEnabled ? null : _preparing,
      commentDisabledReason: commentEnabled ? null : _preparing,
      bookmarkDisabledReason: bookmarkEnabled ? null : _preparing,
      mentoringDisabledReason:
          mentoringEnabled ? null : (isDirector ? _preparing : _noPermission),
      boostDisabledReason: boostEnabled ? null : _preparing,
      onLike: () => _handleLike(enabled: likeEnabled, chartId: chartId),
      onComment: () =>
          _handleComment(enabled: commentEnabled, postId: postId),
      onBookmark: () =>
          _handleBookmark(enabled: bookmarkEnabled, chartId: chartId),
      onMentoring: () => _handleMentoring(
        data,
        enabled: mentoringEnabled,
        isAuthor: isAuthor,
        isDirector: isDirector,
      ),
      onBoost: () => _handleBoost(
        enabled: boostEnabled,
        isAuthor: isAuthor,
      ),
    );
  }

  String? _chartId(PostViewData data) {
    final fromCase = data.caseItem?.chart.id.trim();
    if (fromCase != null && fromCase.isNotEmpty) return fromCase;
    final linked = data.linkedChartId?.trim();
    if (linked != null && linked.isNotEmpty) return linked;
    final fromPost = data.post?.sourceChartId?.trim();
    if (fromPost != null && fromPost.isNotEmpty) return fromPost;
    return null;
  }

  Future<void> _handleLike({
    required bool enabled,
    String? chartId,
  }) async {
    if (!enabled || chartId == null) {
      _snack(_preparing);
      return;
    }
    if (store.session == null) {
      _snack(_noPermission);
      return;
    }
    final ok = await store.toggleChartLike(chartId);
    if (!context.mounted) return;
    if (!ok) {
      _snack('좋아요 처리에 실패했습니다.');
      return;
    }
    _notify();
  }

  Future<void> _handleBookmark({
    required bool enabled,
    String? chartId,
  }) async {
    if (!enabled || chartId == null) {
      _snack(_preparing);
      return;
    }
    try {
      await store.toggleCaseBookmark(chartId);
      _notify();
    } catch (_) {
      if (!context.mounted) return;
      _snack('보관함 저장에 실패했습니다.');
    }
  }

  void _handleComment({
    required bool enabled,
    String? postId,
  }) {
    if (!enabled || postId == null) {
      _snack(_preparing);
      return;
    }
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) {
      if (store.activeCommentPostId == postId) {
        store.closeCommentPanel();
      } else {
        store.openCommentPanel(postId);
      }
      _notify();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: SoriTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.72,
          child: CommunityCommentsSection(
            store: store,
            postId: postId,
          ),
        ),
      ),
    );
  }

  void _handleMentoring(
    PostViewData data, {
    required bool enabled,
    required bool isAuthor,
    required bool isDirector,
  }) {
    if (!enabled) {
      _snack(isDirector ? _preparing : _noPermission);
      return;
    }
    if (data.hasActiveMentoring && isAuthor) {
      onManageMentoring?.call(data);
      return;
    }
    if (isDirector && !isAuthor) {
      onMentoringRequest?.call(data);
      return;
    }
    openPostOriginal(context, data: data, store: store);
  }

  void _handleBoost({
    required bool enabled,
    required bool isAuthor,
  }) {
    if (!enabled) {
      _snack(_preparing);
      return;
    }
    // Boost handlers wired by parent with PostViewData context.
    _snack(_preparing);
  }

  PostEngagementBindings bindingsForWithBoost(
    PostViewData data, {
    required void Function() onBoostTap,
  }) {
    final base = bindingsFor(data);
    return PostEngagementBindings(
      liked: base.liked,
      bookmarked: base.bookmarked,
      likeCount: base.likeCount,
      commentCount: base.commentCount,
      onLike: base.onLike,
      onComment: base.onComment,
      onBookmark: base.onBookmark,
      onMentoring: base.onMentoring,
      onBoost: base.boostEnabled
          ? onBoostTap
          : () => _snack(base.boostDisabledReason ?? _preparing),
      likeEnabled: base.likeEnabled,
      commentEnabled: base.commentEnabled,
      bookmarkEnabled: base.bookmarkEnabled,
      mentoringEnabled: base.mentoringEnabled,
      boostEnabled: base.boostEnabled,
      likeDisabledReason: base.likeDisabledReason,
      commentDisabledReason: base.commentDisabledReason,
      bookmarkDisabledReason: base.bookmarkDisabledReason,
      mentoringDisabledReason: base.mentoringDisabledReason,
      boostDisabledReason: base.boostDisabledReason,
    );
  }
}
