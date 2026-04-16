# HabloTengo

**Privacy-first contact directory built on the open identity network.**

HabloTengo lets you share your contact details only with people you trust — and discover theirs — based on the cryptographic identity graph from [ONE-OF-US.NET](https://one-of-us.net).

## How it works

1. **Sign in** with your ONE-OF-US.NET identity key
2. **Publish your contact card** — name, email, phone, messaging handles — with a visibility level (permissive / standard / strict)
3. **Browse your trust network** — see contact cards from people who trust you (or are trusted by people you trust), filtered by how closely they're connected to you
4. **Reverse trust** — your card is only shown to someone if they're reachable from you within their stated visibility radius

Contact cards are signed cryptographic statements stored in Firestore. No central authority decides who sees what — the trust graph does.

## Architecture

- **Flutter web** app (also runs on mobile)
- **Firebase** (Firestore + Hosting)
- **ONE-OF-US.NET** identity layer — delegate keys, trust statements, BFS graph traversal
- Two independent statement streams: `hablotengo_contact` (what to show) and `hablotengo_privacy` (who can see it)

See [design.md](design.md) for the full design and [DEVELOPMENT.md](DEVELOPMENT.md) for local dev setup.

## Development

```bash
# Prerequisites: Flutter, Firebase CLI, Node.js
# Start emulators (both hablotengo + oneofus)
firebase emulators:start

# In a separate terminal:
flutter run -d chrome --web-port 5000
```

See [DEVELOPMENT.md](DEVELOPMENT.md) for full instructions.

## License

MIT — see [LICENSE](LICENSE)

## Author

[Yotam Aviv](https://github.com/YotamAviv)
