const String kHabloDomain = 'hablotengo.com';
const int kHabloFirestoreEmulatorPort = 8082;
const int kHabloFunctionsEmulatorPort = 5003;
const String kHabloEmulatorProject = 'demo-hablotengo';

const int kOneofusFirestoreEmulatorPort = 8081;
const int kOneofusFunctionsEmulatorPort = 5002;
const String kOneofusEmulatorProject = 'one-of-us-net';

String oneofusExportUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kOneofusFunctionsEmulatorPort/$kOneofusEmulatorProject/us-central1/export'
    : 'https://export.one-of-us.net';

// TO RUN ON PROD: change to 'https://us-central1-hablotengo.cloudfunctions.net/signIn'
String habloSignInUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/signIn'
    : 'https://us-central1-hablotengo.cloudfunctions.net/signIn';
