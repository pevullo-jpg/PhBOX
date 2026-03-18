
import 'web_client_id_storage_stub.dart'
    if (dart.library.html) 'web_client_id_storage_web.dart' as impl;

String loadSavedGoogleWebClientId() => impl.loadSavedGoogleWebClientId();

Future<void> saveGoogleWebClientId(String clientId) => impl.saveGoogleWebClientId(clientId);
