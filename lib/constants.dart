const String kHabloDomain = 'hablotengo.com';
const String kHabloExportUrl = 'https://export.hablotengo.com';
const String kNerdsterUrl = 'https://nerdster.org/app';

late bool emulator;

String get nerdsterAppUrl => emulator ? 'http://localhost:8765/' : kNerdsterUrl;
const int kHabloFirestoreEmulatorPort = 8082;
const int kHabloFunctionsEmulatorPort = 5003;
const String kHabloEmulatorProject = 'hablotengo';

const int kOneofusFirestoreEmulatorPort = 8081;
const int kOneofusFunctionsEmulatorPort = 5002;
const String kOneofusEmulatorProject = 'one-of-us-net';

String get oneofusExportUrl => emulator
    ? 'http://127.0.0.1:$kOneofusFunctionsEmulatorPort/$kOneofusEmulatorProject/us-central1/export'
    : 'https://export.one-of-us.net';

String get oneofusWriteUrl => emulator
    ? 'http://127.0.0.1:$kOneofusFunctionsEmulatorPort/$kOneofusEmulatorProject/us-central1'
    : 'https://us-central1-one-of-us-net.cloudfunctions.net';

String get habloSignInUrl => emulator
    ? 'http://10.0.2.2:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/signIn'
    : 'https://signin.hablotengo.com/signin';

String get habloDemoSignInUrl => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/demoSignIn'
    : 'https://hablotengo.com/demoSignIn';

String get habloGetBatchContactsUrl => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/getBatchContacts'
    : 'https://us-central1-hablotengo.cloudfunctions.net/getBatchContacts';

String get habloDeleteAccountUrl => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/deleteAccount'
    : 'https://us-central1-hablotengo.cloudfunctions.net/deleteAccount';

String get habloFunctionsBaseUrl => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1'
    : 'https://us-central1-hablotengo.cloudfunctions.net';

String get habloExportUrl => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/export'
    : kHabloExportUrl;
