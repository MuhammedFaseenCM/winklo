import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/clients/notification/android_notification_display.dart';

void main() {
  test('reminders and announcements have their own channels', () {
    expect(AndroidNotificationDisplay.remindersChannelId, 'winklo_reminders');
    expect(
      AndroidNotificationDisplay.announcementsChannelId,
      'winklo_announcements',
    );
    expect(AndroidNotificationDisplay.channels.map((c) => c.id), [
      AndroidNotificationDisplay.remindersChannelId,
      AndroidNotificationDisplay.announcementsChannelId,
    ]);
  });

  test('details carry the channel they are for', () {
    expect(
      AndroidNotificationDisplay.reminderDetails().android!.channelId,
      AndroidNotificationDisplay.remindersChannelId,
    );
    expect(
      AndroidNotificationDisplay.announcementDetails().android!.channelId,
      AndroidNotificationDisplay.announcementsChannelId,
    );
  });

  test('the manifest routes background FCM to the announcements channel', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final meta = RegExp(
      r'default_notification_channel_id"\s+android:value="([^"]+)"',
    ).firstMatch(manifest);
    expect(meta, isNotNull);
    expect(meta!.group(1), AndroidNotificationDisplay.announcementsChannelId);
  });

  // flutter_local_notifications 16+ leaves these to the app. Without them
  // zonedSchedule still succeeds, but the alarm's broadcast has no receiver,
  // so no scheduled reminder is ever shown.
  test('the manifest declares the scheduled-notification receivers', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    const plugin = 'com.dexterous.flutterlocalnotifications';
    expect(
      manifest,
      contains('android:name="$plugin.ScheduledNotificationReceiver"'),
    );
    final boot = RegExp(
      'android:name="$plugin\\.ScheduledNotificationBootReceiver"'
      r'[^>]*>([\s\S]*?)</receiver>',
    ).firstMatch(manifest);
    expect(boot, isNotNull);
    for (final action in [
      'android.intent.action.BOOT_COMPLETED',
      'android.intent.action.MY_PACKAGE_REPLACED',
    ]) {
      expect(boot!.group(1), contains('android:name="$action"'));
    }
  });
}
