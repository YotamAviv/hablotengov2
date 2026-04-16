enum FireChoice {
  fake,
  emulator,
  prod;
}

FireChoice fireChoice = const String.fromEnvironment('fire') == 'emulator'
    ? FireChoice.emulator
    : FireChoice.prod;
