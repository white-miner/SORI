import 'package:flutter_test/flutter_test.dart';

import 'package:sori/features/visit/widgets/my_today_schedule_read_panel.dart';

void main() {
  test('short note uses bottom sheet · long uses fullscreen', () {
    expect(MyTodayScheduleReadPanel.useFullscreenNoteEditor('한 줄'), isFalse);
    expect(
      MyTodayScheduleReadPanel.useFullscreenNoteEditor('줄1\n줄2'),
      isFalse,
    );
    expect(
      MyTodayScheduleReadPanel.useFullscreenNoteEditor('줄1\n줄2\n줄3'),
      isTrue,
    );
    expect(
      MyTodayScheduleReadPanel.useFullscreenNoteEditor('a' * 81),
      isTrue,
    );
  });
}
