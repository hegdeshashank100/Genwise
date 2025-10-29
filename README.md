# 🌟 GenWise  
### _An AI-Powered Multi-Tool Mobile Application for Learning, Creativity, and Productivity_

![Flutter](https://img.shields.io/badge/Flutter-3.24-blue?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Backend-orange?logo=firebase)
![AI](https://img.shields.io/badge/Google%20Gemini%20%26%20Vertex%20AI-Powered-brightgreen)
![License](https://img.shields.io/badge/License-MIT-green)
![Platforms](https://img.shields.io/badge/Platforms-Android%20|%20iOS%20|%20Web%20|%20Desktop-blueviolet)

---

## 🧠 Project Pitch

**Tagline:**  
> “Your all-in-one AI toolkit for learning, creativity, and productivity.”

**Overview:**  
GenWise is a **cross-platform Flutter app** that unifies powerful AI features—document Q&A, code explanations, voice-based communication practice, UI design, resume and question paper generation—into one seamless mobile experience.  
It integrates **Google Gemini** for generative text, **Vertex AI Imagen 2** for image generation, and **Firebase** for secure authentication and cloud data, all wrapped in a sleek Material 3 interface.

---

## 🎯 Target Audience
- Students and Teachers  
- Developers and Designers  
- Content Creators and Professionals  
- Anyone seeking AI-driven productivity tools  

---

## 💡 Key Differentiators
- 🧩 Modular multi-tool architecture — expand or remove tools independently  
- 🎙️ Real-time speech-to-speech communication practice  
- 💻 Drag-and-drop **AI UI Designer** that converts layouts to HTML/CSS  
- 📄 Integrated **Chat with PDF** using Syncfusion PDF + Gemini context reasoning  
- 🔒 Secure Firebase authentication with role-based recommendations  

---

## 🖼️ Screenshots

| Home Page | Tool 1 | Tool 2 |
|------------|--------|--------|
| <img src="https://github.com/hegdeshashank100/Genwise/blob/main/docs/WhatsApp%20Image%202025-10-17%20at%2017.29.29_48c20df0.jpg" alt="Home Page" width="250"/> | <img src="https://github.com/hegdeshashank100/Genwise/blob/main/docs/WhatsApp%20Image%202025-10-17%20at%2017.29.28_9c735be1.jpg" alt="Tool Screenshot 1" width="250"/> | <img src="https://github.com/hegdeshashank100/Genwise/blob/main/docs/WhatsApp%20Image%202025-10-17%20at%2017.29.28_fc5f8a28.jpg" alt="Tool Screenshot 2" width="250"/> |

---

## ⚙️ Minimum Requirements
| Requirement | Version |
|--------------|----------|
| Flutter SDK | ≥ 3.24 (Stable) |
| Dart | ≥ 3.3 |
| Supported Platforms | Android, iOS, Web, Windows, macOS, Linux |

---

## 🧩 Core Features

### 🔐 Authentication & Profile
- Firebase Email/Password login & registration  
- Role-based Firestore user roles  
- Password reset, change, delete, and email verification  

### 🏠 Home & Discovery
- Searchable tools grid  
- Role-based suggestions (Student, Teacher, Creator, Developer)  
- Modern Material 3 UI with theme support  

### 📚 Chat with PDF
- Ask contextual questions from uploaded PDFs  
- Smart chunking, keyword retrieval, and Gemini-powered Q&A  

### 💻 Code Explainer
- AI breakdown of complex code  
- JSON-structured snippets and summaries  

### 🎨 AI UI Designer
- Drag-and-drop components, device templates, and live preview  
- Exports to production-ready **HTML/CSS**

### 🗣️ Communication Practice
- Real-time **speech-to-text + text-to-speech** conversations  
- Multiple modes (Interview, Business, Presentation, Casual)  

### 🎭 Creative & Educational Tools
- Resume Builder, Question Paper Generator  
- Knowledge Duel, Image-to-Story, Poster, Lyrics, Recipe Generators  

### 🖼️ Image Utilities
- Image Compression (`flutter_image_compress`)  
- AI Upscaling via ONNX Runtime and Flutter Super Resolution  

---

## 🧱 Tech Stack

| Category | Tools & Packages |
|-----------|------------------|
| Framework | Flutter (Material 3) |
| State Management | Provider |
| Backend | Firebase Authentication & Firestore |
| AI APIs | Google Gemini (Generative Language), Vertex AI Imagen 2 |
| Documents | Syncfusion PDF, file_picker |
| Speech | speech_to_text, flutter_tts |
| Image | flutter_image_compress, onnxruntime, flutter_super_resolution |
| Utilities | jose, cryptography, path_provider, printing, open_file, share_plus |

---

## 🔑 Setup & Configuration

### 1️⃣ Prerequisites
- Flutter SDK installed  
- Firebase project configured  

### 2️⃣ Firebase Setup
- Confirm `firebase_options.dart` is valid  
- Place `android/app/google-services.json` for Android  
- Place `ios/Runner/GoogleService-Info.plist` for iOS  

**Firebase Project ID:** _(confirm your Firebase project ID)_  

### 3️⃣ Run Locally
```bash
flutter pub get
flutter run

