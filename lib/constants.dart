const String kHabloDomain = 'hablotengo.com';
const int kHabloFirestoreEmulatorPort = 8082;
const int kHabloFunctionsEmulatorPort = 5003;
const String kHabloEmulatorProject = 'hablotengo';

const int kOneofusFirestoreEmulatorPort = 8081;
const int kOneofusFunctionsEmulatorPort = 5002;
const String kOneofusEmulatorProject = 'one-of-us-net';

String oneofusExportUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kOneofusFunctionsEmulatorPort/$kOneofusEmulatorProject/us-central1/export'
    : 'https://export.one-of-us.net';

String oneofusWriteUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kOneofusFunctionsEmulatorPort/$kOneofusEmulatorProject/us-central1'
    : 'https://us-central1-one-of-us-net.cloudfunctions.net';

String habloSignInUrl(bool emulator) => emulator
    ? 'http://10.0.2.2:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/signIn'
    : 'https://signin.hablotengo.com/signin';

String habloDemoSignInUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/demoSignIn'
    : 'https://hablotengo.com/demoSignIn';

String habloGetContactUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/getContact'
    : 'https://us-central1-hablotengo.cloudfunctions.net/getContact';

String habloGetBatchContactsUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/getBatchContacts'
    : 'https://us-central1-hablotengo.cloudfunctions.net/getBatchContacts';

String habloGetMyContactUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/getMyContact'
    : 'https://us-central1-hablotengo.cloudfunctions.net/getMyContact';

String habloSetMyContactUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/setMyContact'
    : 'https://us-central1-hablotengo.cloudfunctions.net/setMyContact';

String habloGetSettingsUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/getSettings'
    : 'https://us-central1-hablotengo.cloudfunctions.net/getSettings';

String habloSetSettingsUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/setSettings'
    : 'https://us-central1-hablotengo.cloudfunctions.net/setSettings';

String habloGetEquivalentStatusUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/getEquivalentStatus'
    : 'https://us-central1-hablotengo.cloudfunctions.net/getEquivalentStatus';

String habloDisableEquivalentUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/disableEquivalent'
    : 'https://us-central1-hablotengo.cloudfunctions.net/disableEquivalent';

String habloDismissEquivalentUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/dismissEquivalent'
    : 'https://us-central1-hablotengo.cloudfunctions.net/dismissEquivalent';

String habloEnableAccountUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/enableAccount'
    : 'https://us-central1-hablotengo.cloudfunctions.net/enableAccount';
