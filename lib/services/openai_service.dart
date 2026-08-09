import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';

/// OpenAI Chat Completions — 이케아형 리뷰 문장 조립.
class OpenAiService {
  OpenAiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _endpoint =
      'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o-mini';

  /// 뷰티 현장 맞춤 시스템 프롬프트 (하드코딩).
  static const String systemPrompt = '''
당신은 한국 에스테틱·반영구 시술 전문 리뷰 라이터입니다.
고객이 고른 감성 키워드(칩)와 오늘 받은 케어 정보를 조합해,
네이버 플레이스 검색 노출(SEO)에 유리한 자연스러운 한국어 블로그 후기를 작성합니다.

[필수 역학 반영]
단순 칭찬이 아니라, 아줄렌 성분을 활용한 쿨링 진정 케어, 텐션 조절을 통한 무통증 반영구 시술, 직선으로 뻗는 상승형 눈썹 디자인 등 뷰티 실무의 물리적 디테일과 고객이 선택한 감성 키워드를 결합하라. 네이버 플레이스 검색 노출(SEO)에 유리하도록 3~4문장의 자연스러운 한국어 블로그 후기 톤으로 작성하라.

[추가 규칙]
1. 선택한 감성 키워드는 나열하지 말고 체감 문장으로 풀어 쓰세요.
2. 과장·허위·의료적 단정 금지. 1인칭 진솔한 톤.
3. 해시태그는 맨 끝 한 줄에 샵명 관련 2~3개만.
4. 출력은 후기 본문만. 따옴표·제목·설명 문구 금지.
''';

  bool get isConfigured => Env.hasOpenAiConfig;

  /// 선택된 칩 + 케어 컨텍스트로 리뷰 문장 생성.
  Future<String> composeReview({
    required List<String> selectedChips,
    required String careName,
    required String directorComment,
    required String shopName,
  }) async {
    if (!isConfigured) {
      throw OpenAiException(
        'OpenAI API 키가 설정되지 않았어요. OPENAI_API_KEY를 확인해 주세요.',
      );
    }

    final chips = selectedChips.isEmpty
        ? '편안하게 케어받을 수 있었어요'
        : selectedChips.join(', ');

    final userPrompt = '''
[케어 명칭] $careName
[원장님 코멘트] $directorComment
[고객 선택 칩] $chips
[샵 이름] $shopName

위 정보를 바탕으로 네이버 플레이스용 후기 3~4문장을 작성해 주세요.
''';

    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${Env.openaiApiKey}',
            },
            body: jsonEncode({
              'model': _model,
              'temperature': 0.8,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 429) {
        debugPrint('OpenAI HTTP 429 quota/rate limit');
        throw OpenAiException(
          'AI API 크레딧이 부족하거나 요청이 많습니다. OpenAI 결제 상태를 확인해 주세요.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('OpenAI HTTP ${response.statusCode}');
        throw OpenAiException(
          'AI 서버 응답에 문제가 있어요 (${response.statusCode}). 잠시 후 다시 시도해 주세요.',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = body['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw OpenAiException('AI가 문장을 만들지 못했어요. 다시 시도해 주세요.');
      }
      final message = (choices.first as Map)['message'] as Map?;
      final content = (message?['content'] as String?)?.trim() ?? '';
      if (content.isEmpty) {
        throw OpenAiException('AI가 빈 문장을 반환했어요. 다시 시도해 주세요.');
      }
      return content;
    } on OpenAiException {
      rethrow;
    } catch (e, st) {
      debugPrint('OpenAI compose failed: $e\n$st');
      throw OpenAiException(
        '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
      );
    }
  }

  /// API 없을 때 UI용 로컬 폴백 문장.
  static String localFallback({
    required List<String> selectedChips,
    required String careName,
    required String shopName,
  }) {
    final picks = selectedChips.isEmpty
        ? '편안하게 케어받을 수 있었어요'
        : selectedChips.join(', ');
    return '오늘은 $careName를 받았는데, 아줄렌 쿨링 진정과 텐션 조절 케어가 세심해 자극 없이 편안했어요. '
        '특히 $picks 점이 마음에 들었고, 상승형 디자인 디테일까지 꼼꼼해 다음에도 믿고 방문하고 싶습니다. '
        '#${shopName.replaceAll(' ', '')} #소통하는리뷰 #에스테틱후기';
  }

  static const String _polishSystemPrompt = '''
당신은 한국 뷰티·에스테틱 살롱의 카피라이터입니다.
원장이 대충 적은 서비스 설명을, 고객이 이해하기 쉽고 매력적인 살롱 안내 문구로 다듬습니다.

[규칙]
1. 출력은 한국어 1~2문장만. 따옴표·제목·불릿·해시태그 금지.
2. 과장·허위·의료적 단정 금지. 따뜻하고 신뢰감 있는 톤.
3. 원문의 핵심 효과·분위기·시술 포인트는 유지하세요.
''';

  /// 서비스 메뉴 고객 안내 설명을 1~2문장으로 윤문.
  Future<String> polishServiceDescription({
    required String serviceName,
    required String roughDescription,
    String shopName = '',
  }) async {
    if (!isConfigured) {
      throw OpenAiException(
        'OpenAI API 키가 설정되지 않았어요. OPENAI_API_KEY를 확인해 주세요.',
      );
    }

    final draft = roughDescription.trim().isEmpty
        ? serviceName.trim()
        : roughDescription.trim();
    if (draft.isEmpty) {
      throw OpenAiException('다듬을 설명이나 서비스명을 먼저 입력해 주세요.');
    }

    final userPrompt = '''
[샵 이름] ${shopName.trim().isEmpty ? '뷰티 살롱' : shopName.trim()}
[서비스명] ${serviceName.trim().isEmpty ? '(미정)' : serviceName.trim()}
[원장 메모]
$draft

위 내용을 고객 안내용으로 1~2문장 다듬어 주세요.
''';

    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${Env.openaiApiKey}',
            },
            body: jsonEncode({
              'model': _model,
              'temperature': 0.7,
              'messages': [
                {'role': 'system', 'content': _polishSystemPrompt},
                {'role': 'user', 'content': userPrompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 429) {
        throw OpenAiException(
          'AI API 크레딧이 부족하거나 요청이 많습니다. OpenAI 결제 상태를 확인해 주세요.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OpenAiException(
          'AI 서버 응답에 문제가 있어요 (${response.statusCode}). 잠시 후 다시 시도해 주세요.',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = body['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw OpenAiException('AI가 문장을 만들지 못했어요. 다시 시도해 주세요.');
      }
      final message = (choices.first as Map)['message'] as Map?;
      final content = (message?['content'] as String?)?.trim() ?? '';
      if (content.isEmpty) {
        throw OpenAiException('AI가 빈 문장을 반환했어요. 다시 시도해 주세요.');
      }
      return content;
    } on OpenAiException {
      rethrow;
    } catch (e, st) {
      debugPrint('OpenAI polish failed: $e\n$st');
      throw OpenAiException(
        '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
      );
    }
  }
}

class OpenAiException implements Exception {
  OpenAiException(this.message);
  final String message;

  @override
  String toString() => message;
}
