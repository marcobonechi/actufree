import 'package:puzzle_store/puzzle_store.dart';
import 'package:test/test.dart';

final class _Note implements SavedGame {
  const _Note(this.text);

  factory _Note.fromJson(Map<String, Object?> json) =>
      _Note(json['text']! as String);

  final String text;

  @override
  String get gameId => 'note';

  @override
  Map<String, Object?> toJson() => <String, Object?>{'text': text};
}

void main() {
  late MemoryStore backing;
  late GameStore store;

  setUp(() {
    backing = MemoryStore();
    store = GameStore(backing);
  });

  test('a saved game comes back', () async {
    await store.save(const _Note('hello'), slot: 'easy');
    final restored = await store.load('note', _Note.fromJson, slot: 'easy');
    expect(restored?.text, 'hello');
  });

  test('an empty slot reads as null', () async {
    expect(await store.load('note', _Note.fromJson, slot: 'easy'), isNull);
    expect(await store.has('note', slot: 'easy'), isFalse);
  });

  test('slots do not tread on each other', () async {
    await store.save(const _Note('easy game'), slot: 'easy');
    await store.save(const _Note('hard game'), slot: 'hard');
    expect((await store.load('note', _Note.fromJson, slot: 'easy'))?.text,
        'easy game');
    expect((await store.load('note', _Note.fromJson, slot: 'hard'))?.text,
        'hard game');
  });

  test('saving a slot twice replaces it', () async {
    await store.save(const _Note('first'), slot: 'easy');
    await store.save(const _Note('second'), slot: 'easy');
    expect((await store.load('note', _Note.fromJson, slot: 'easy'))?.text,
        'second');
    expect(backing.keys, hasLength(1));
  });

  test('clear empties a slot and leaves the others', () async {
    await store.save(const _Note('easy game'), slot: 'easy');
    await store.save(const _Note('hard game'), slot: 'hard');
    await store.clear('note', slot: 'easy');
    expect(await store.has('note', slot: 'easy'), isFalse);
    expect(await store.has('note', slot: 'hard'), isTrue);
  });

  group('a record it cannot read', () {
    // A save that cannot be restored should cost the player one game, not the
    // ability to open the app — so these return null and clear the record
    // rather than throwing.
    test('is dropped when the JSON is corrupt', () async {
      await backing.write(GameStore.keyFor('note', 'easy'), 'not json');
      expect(await store.load('note', _Note.fromJson, slot: 'easy'), isNull);
      expect(backing.keys, isEmpty);
    });

    test('is dropped when the envelope is from another version', () async {
      await backing.write(
        GameStore.keyFor('note', 'easy'),
        '{"version":99,"gameId":"note","slot":"easy","state":{"text":"x"}}',
      );
      expect(await store.load('note', _Note.fromJson, slot: 'easy'), isNull);
      expect(backing.keys, isEmpty);
    });

    test('is dropped when the decoder throws', () async {
      await backing.write(
        GameStore.keyFor('note', 'easy'),
        '{"version":1,"gameId":"note","slot":"easy","state":{"wrong":1}}',
      );
      expect(await store.load('note', _Note.fromJson, slot: 'easy'), isNull);
      expect(backing.keys, isEmpty);
    });
  });
}
