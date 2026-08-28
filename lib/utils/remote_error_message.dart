import 'package:supabase_flutter/supabase_flutter.dart';

/// PostgREST / Supabase RPC 오류를 PO·현장에 노출 가능한 문자열로 변환.
String formatRemoteError(Object error) {
  if (error is PostgrestException) {
    final buf = StringBuffer();
    final message = error.message.trim();
    buf.write(message.isNotEmpty ? message : error.toString());
    final details = error.details;
    if (details != null && details.toString().trim().isNotEmpty) {
      buf.write('\ndetails: $details');
    }
    final hint = error.hint?.trim();
    if (hint != null && hint.isNotEmpty) {
      buf.write('\nhint: $hint');
    }
    final code = error.code?.trim();
    if (code != null && code.isNotEmpty) {
      buf.write('\ncode: $code');
    }
    return buf.toString();
  }
  return error.toString().replaceFirst('Exception: ', '');
}
