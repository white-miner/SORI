/// 공공 API 실패 분류. 키·URL·원문 본문을 담지 않는다.
enum MarketApiFailure {
  none,
  networkOffline,
  timeout,
  rateLimited,
  unauthorizedOrInvalidKey,
  invalidRequest,
  upstreamUnavailable,
  malformedResponse,
  noResults,
  cancelled,
  unknown,
}

abstract final class MarketApiFailureX {
  static String userMessage(MarketApiFailure kind) => switch (kind) {
        MarketApiFailure.none => '',
        MarketApiFailure.networkOffline =>
          '네트워크 연결을 확인한 뒤 다시 시도하세요.',
        MarketApiFailure.timeout =>
          '응답이 지연되고 있습니다. 잠시 후 다시 시도하세요.',
        MarketApiFailure.rateLimited =>
          '요청이 많아 잠시 후 다시 시도하세요.',
        MarketApiFailure.unauthorizedOrInvalidKey =>
          '공공데이터 연결이 준비되지 않았습니다. 설정 후 다시 시도하세요.',
        MarketApiFailure.invalidRequest =>
          '위치·반경·업종을 확인한 뒤 다시 조회하세요.',
        MarketApiFailure.upstreamUnavailable =>
          '공공데이터 서버가 잠시 불안정합니다. 다시 시도하세요.',
        MarketApiFailure.malformedResponse =>
          '응답을 읽지 못했습니다. 다시 시도하세요.',
        MarketApiFailure.noResults =>
          '이 반경·업종에서 업소가 없습니다. 반경을 넓혀 보세요.',
        MarketApiFailure.cancelled => '이전 조회를 취소하고 새 조건으로 불러옵니다.',
        MarketApiFailure.unknown => '상권 데이터를 불러오지 못했습니다. 다시 시도하세요.',
      };

  static MarketApiFailure fromHttp({
    required int status,
    String? errorCode,
    bool emptyItems = false,
  }) {
    final code = (errorCode ?? '').toLowerCase();
    if (code.contains('cancel')) return MarketApiFailure.cancelled;
    if (code.contains('timeout')) return MarketApiFailure.timeout;
    if (code.contains('offline') || code == 'network_error') {
      return MarketApiFailure.networkOffline;
    }
    if (status == 429 || code.contains('rate')) {
      return MarketApiFailure.rateLimited;
    }
    if (status == 401 ||
        status == 403 ||
        code.contains('xml_') ||
        code.contains('unauthorized') ||
        code.contains('missing_service_key')) {
      return MarketApiFailure.unauthorizedOrInvalidKey;
    }
    if (status >= 400 && status < 500) return MarketApiFailure.invalidRequest;
    if (status >= 500) return MarketApiFailure.upstreamUnavailable;
    if (code.contains('json') ||
        code.contains('malformed') ||
        code.contains('empty_body') ||
        code.contains('missing_body') ||
        code.contains('result_not_ok') ||
        code.contains('invalid_total') ||
        code.contains('positive_total') ||
        code.contains('cmm')) {
      return MarketApiFailure.malformedResponse;
    }
    if (emptyItems) return MarketApiFailure.noResults;
    if (status == 0) return MarketApiFailure.unknown;
    return MarketApiFailure.none;
  }
}

class MarketRequestToken {
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  void cancel() => _cancelled = true;
}
