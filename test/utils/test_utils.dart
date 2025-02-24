import 'package:parse_server_sdk/parse_server_sdk.dart';

const serverUrl = 'https://example.com';

Future<void> initializeParse({
  required ParseClient client,
  String? liveQueryUrl,
}) async {
  await Parse().initialize(
    'appId',
    serverUrl,
    clientKey: 'clientKey',
    coreStore: CoreStoreMemoryImp(),
    clientCreator: ({
      required sendSessionId,
      securityContext,
    }) =>
        client,
  );
}
