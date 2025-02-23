import 'package:flutter_test/flutter_test.dart';
import 'package:parse_sync/src/data_source/sync_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Initialize platform interface before tests
  TestWidgetsFlutterBinding.ensureInitialized();

  SharedPreferences? prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('SyncPreferences', () {
    test('initial lastSync is epoch when no data exists', () async {
      final syncPrefs = SyncPreferences(
        prefs: prefs!,
        collectionName: 'users',
      );

      expect(syncPrefs.lastSync, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('setLastSync stores and retrieves correct timestamp', () async {
      final syncPrefs = SyncPreferences(
        prefs: prefs!,
        collectionName: 'posts',
      );

      final testTime = DateTime(2023, 1, 1, 12, 30);
      await syncPrefs.setLastSync(testTime);

      expect(syncPrefs.lastSync, testTime);
      expect(prefs!.getInt('lastSync_posts'), testTime.millisecondsSinceEpoch);
    });

    test('prefs key uses correct naming convention', () async {
      const collection = 'products';
      final syncPrefs = SyncPreferences(
        prefs: prefs!,
        collectionName: collection,
      );

      final testTime = DateTime.now();
      await syncPrefs.setLastSync(testTime);

      expect(prefs!.containsKey('lastSync_$collection'), true);
      expect(
        prefs!.getInt('lastSync_$collection'),
        testTime.millisecondsSinceEpoch,
      );
    });

    test('different collections maintain separate timestamps', () async {
      final usersPrefs = SyncPreferences(
        prefs: prefs!,
        collectionName: 'users',
      );

      final ordersPrefs = SyncPreferences(
        prefs: prefs!,
        collectionName: 'orders',
      );

      final testTime = DateTime(2023, 2, 1, 9, 15);
      await usersPrefs.setLastSync(testTime);

      // Verify users collection has the timestamp
      expect(usersPrefs.lastSync, testTime);
      expect(prefs!.getInt('lastSync_users'), testTime.millisecondsSinceEpoch);

      // Verify orders collection remains at epoch
      expect(ordersPrefs.lastSync, DateTime.fromMillisecondsSinceEpoch(0));
      expect(prefs!.containsKey('lastSync_orders'), false);
    });

    test('overwriting existing timestamp works correctly', () async {
      final syncPrefs = SyncPreferences(
        prefs: prefs!,
        collectionName: 'inventory',
      );

      final initialTime = DateTime(2023, 3, 1);
      await syncPrefs.setLastSync(initialTime);

      final updatedTime = DateTime(2023, 3, 2);
      await syncPrefs.setLastSync(updatedTime);

      expect(syncPrefs.lastSync, updatedTime);
      expect(
        prefs!.getInt('lastSync_inventory'),
        updatedTime.millisecondsSinceEpoch,
      );
    });
  });
}
