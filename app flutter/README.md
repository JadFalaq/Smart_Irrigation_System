# Irrigation App Flutter

Application Flutter pour controler un systeme d'irrigation intelligent avec Firebase Realtime Database.

## Prerequis
- Flutter 3.16+
- Compte Firebase

## Configuration
1. Creer un projet Firebase et activer Realtime Database.
2. Remplacer les valeurs Firebase dans `lib/main.dart` par vos propres identifiants.
3. Lancer :

```bash
flutter pub get
flutter run
```

## Structure
- `lib/providers/irrigation_provider.dart` : logique Firebase temps reel
- `lib/screens` : ecrans principaux
- `lib/widgets` : composants reutilisables

## Notes
- Les clefs API doivent etre chargees via un mecanisme securise (dotenv/Remote Config).
- Les statistiques et plannings sont des bases a etendre.
