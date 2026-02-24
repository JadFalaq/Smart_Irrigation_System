# Smart Farm Irrigation System 🌾💧

Un système intelligent de contrôle d'irrigation pour les fermes, développé avec Flutter, Arduino, et Firebase.

## 📋 Description

Ce projet est une application complète d'irrigation intelligente qui permet de :
- **Contrôler l'irrigation** en temps réel à partir d'une application mobile Flutter
- **Monitorer l'utilisation de l'eau** avec des statistiques détaillées
- **Planifier l'arrosage** selon des horaires définis
- **Gérer plusieurs zones** d'irrigation
- **Recevoir des notifications** en temps réel

## 🛠 Travail réalisé

- Mise en place d'une architecture complète Flutter + ESP32 + Arduino Mega
- Implémentation des logiques de contrôle et de sécurité (une seule zone active, validation des commandes, machine à états côté Arduino)
- Intégration de Firebase Authentication et Realtime Database pour la gestion des utilisateurs et des commandes d'irrigation
- Création et amélioration des écrans principaux (Accueil, Bassin, Planning, Statistiques, Paramètres)
- Gestion des plannings d'arrosage (horaires par zone) et de l'historique
- Mise en place de la communication série entre l’ESP32 et l’Arduino Mega pour piloter les relais

## 🧰 Outils utilisés

- **Langages** : Dart (Flutter), C/C++ (ESP32, Arduino)
- **Frameworks & SDK** : Flutter, Firebase (Auth + Realtime Database), PlatformIO, Arduino
- **Outils de développement** : Git, VS Code / IDE équivalent, émulateur/simulateur matériel (ex. Wokwi)
- **Plateformes cibles** : Android, iOS, Web, microcontrôleurs ESP32 et Arduino Mega

## 🏗️ Architecture

Le projet est composé de trois parties principales :

### 1. **Application Flutter** (`app flutter/`)
Application mobile multi-plateforme (iOS, Android, Web) pour l'interface utilisateur
- **Framework** : Flutter 3.2.0+
- **Base de données** : Firebase Realtime Database
- **Authentification** : Firebase Auth + Google Sign-In
- **Graphiques** : FL Chart pour les statistiques
- **Gestion d'état** : Provider

#### Fonctionnalités principales :
- Authentification utilisateur
- Tableau de bord avec contrôle en temps réel
- Historique des arrosages
- Planification des tâches
- Statistiques de consommation d'eau
- Configuration des zones

### 2. **Contrôleur ESP32** (`esp_32/`)
Microcontrôleur pour la gestion des capteurs et actionneurs
- **Plateforme** : PlatformIO (ESP32)
- **Communication** : Firebase Realtime Database
- **Capteurs** : Humidité du sol, température
- **Actionneurs** : Pompes/électrovannes d'irrigation

### 3. **Arduino Mega** (`arduino_mega/`)
Contrôleur auxiliaire pour les capteurs avancés
- Support des capteurs supplémentaires
- Intégration avec l'ESP32

## 🚀 Installation

### Prérequis
- Flutter SDK 3.2.0+
- PlatformIO CLI
- Arduino IDE (optionnel)
- Firebase Project configuré

### Configuration Firebase
1. Créez un projet Firebase sur [Firebase Console](https://console.firebase.google.com)
2. Activez Authentication et Realtime Database
3. Téléchargez `google-services.json` et placez-le dans `app flutter/android/app/`
4. Configurez les règles Realtime Database

### Installation de l'application Flutter
```bash
cd "app flutter"
flutter pub get
flutter run
```

### Installation du firmware ESP32
```bash
platformio run -e esp32dev --target upload
```

## 📱 Utilisation

### Première utilisation
1. Créez un compte via Google Sign-In
2. Configurez vos zones d'irrigation
3. Connectez l'ESP32 à votre réseau WiFi
4. Commencez à contrôler votre irrigation !

### Interface utilisateur
- **Accueil** : Vue d'ensemble et contrôle en temps réel
- **Historique** : Consultez l'historique des arrosages
- **Planification** : Créez des horaires d'irrigation
- **Statistiques** : Analysez la consommation d'eau
- **Paramètres** : Configurez vos zones et préférences

## 🔧 Structure du projet

```
Farm_irrigation-main/
├── app flutter/          # Application Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/       # Modèles de données
│   │   ├── providers/    # Gestion d'état
│   │   ├── screens/      # Écrans de l'app
│   │   ├── widgets/      # Composants réutilisables
│   │   └── core/         # Constants et thèmes
│   ├── android/          # Configuration Android
│   ├── ios/              # Configuration iOS
│   └── pubspec.yaml      # Dépendances Flutter
├── esp_32/               # Code ESP32
│   └── main.cpp
├── arduino_mega/         # Code Arduino Mega
│   └── arduino_mega_esp32__1_.ino
└── platformio.ini        # Configuration PlatformIO
```

## 📦 Dépendances principales

### Flutter
- **firebase_core** : Initialisation Firebase
- **firebase_database** : Base de données en temps réel
- **firebase_auth** : Authentification
- **google_sign_in** : Connexion Google
- **provider** : Gestion d'état
- **fl_chart** : Graphiques et statistiques
- **table_calendar** : Calendrier pour la planification

### ESP32
- Firebase-ESP-Client

## 🔐 Sécurité

- Authentification requise pour toutes les opérations
- Règles Firebase Realtime Database configurées pour la sécurité
- Communication chiffrée avec Firebase
- Tokens d'authentification temporaires

## 📊 Base de données

Structure Firebase Realtime Database :
```
├── users/
│   └── {uid}/
│       ├── profile
│       ├── zones/
│       └── history/
├── zones/
│   └── {zoneId}/
│       ├── name
│       ├── status
│       └── settings/
└── logs/
    └── {timestamp}/
        └── activity
```

## 🐛 Dépannage

### Problèmes de connexion Firebase
- Vérifiez que `google-services.json` est correctement placé
- Vérifiez les règles Realtime Database
- Vérifiez votre connexion Internet

### Problèmes d'ESP32
- Vérifiez le port COM utilisé dans `platformio.ini`
- Assurez-vous que l'ESP32 est en mode bootloader
- Vérifiez les logs série à 115200 bauds

## 📝 Contribution

Les contributions sont les bienvenues ! Veuillez :
1. Fork le projet
2. Créer une branche pour votre fonctionnalité
3. Commiter vos changements
4. Pousser vers la branche
5. Créer une Pull Request

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.

## 📞 Support

Pour toute question ou problème, veuillez ouvrir une issue sur GitHub.

---

**Développé avec ❤️ pour l'agriculture intelligente**
