# NextLeap 🛍️

**NextLeap** is a career diagnosis web application built with Flutter Web.
It guides users through a series of questions to help them identify their strengths and discover suitable career paths.

---

## 🚀 Features

* 🧠 **Career diagnosis** via structured multiple-choice questions
* 🔒 **Google Sign-In authentication** (Firebase Authentication)
* 📂 **Result saving** to Firebase Firestore with user UID
* 📱 **Responsive UI** for desktop and mobile devices
* 🧽 **Type-based diagnosis results** (e.g., Analyzer, Creator, Leader)
* 🖨️ **PDF export** of detailed diagnosis results
* 📦 **PWA support** for installable experience

---

## 🛠️ Tech Stack

* **Flutter Web**
* **Firebase Authentication & Firestore**
* **OpenAI GPT-3.5 API**
* **pdf / printing packages**
* **Progressive Web App (PWA)** with manifest support

---

## 📸 Screenshots

| Home                | Diagnosis           | Result              |
| ------------------- | ------------------- | ------------------- |
| *Insert Screenshot* | *Insert Screenshot* | *Insert Screenshot* |

---

## 🔧 How to Run Locally

```bash
flutter pub get
flutter run -d chrome
```

---

## ⚠️ Notes & Setup

* `firebase_options.dart` is **required**. Generate it using:

  ```bash
  flutterfire configure
  ```
* The following files are excluded via `.gitignore`:

  * `.env`, `.env.*`
  * `firebase.json`, `firebase_options.dart`
  * `web/index.html` (contains Google Sign-In client ID)
* You must manually:

  * Create a Firebase project
  * Enable Authentication (Google provider)
  * Enable Firestore
  * Add the necessary fields (`uid`, `timestamp`, etc.) and indexes

---

## ✅ Required Firestore Index

For the following query:

```dart
.where('uid', isEqualTo: uid).orderBy('timestamp', descending: true)
```

You need to add a **composite index** to Firestore:

| Field       | Order      |
| ----------- | ---------- |
| `uid`       | Ascending  |
| `timestamp` | Descending |

Set this under **Firestore > Indexes > Composite > Add Index**.

---

## 🔐 Security

* All secrets (API keys, client IDs) are excluded from version control.
* Be sure not to commit `web/index.html` or `.env` files containing sensitive information.
* Firestore rules should be configured to restrict read/write access appropriately for authenticated users.

---

## 📄 License

MIT © 2025
