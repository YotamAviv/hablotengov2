const String kHabloDomain = 'hablotengo.com';
const int kHabloFirestoreEmulatorPort = 8082;
const int kHabloFunctionsEmulatorPort = 5003;
const String kHabloEmulatorProject = 'demo-hablotengo';

// TO RUN ON PROD: change to 'https://us-central1-hablotengo.cloudfunctions.net/signIn'
String habloSignInUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/signIn'
    : 'https://us-central1-hablotengo.cloudfunctions.net/signIn';

String habloGetContactsUrl(bool emulator) => emulator
    ? 'http://127.0.0.1:$kHabloFunctionsEmulatorPort/$kHabloEmulatorProject/us-central1/getContacts'
    : 'https://us-central1-hablotengo.cloudfunctions.net/getContacts';
