# GenWise: An AI-Powered Multi-Tool Mobile Application for Learning, Creativity, and Productivity

To be formatted per IJPREMS journal template (sections below align to common IJPREMS headings). Replace placeholder fields like <Author Name> and <Affiliation> before submission.

## Title and Authors

- Title: GenWise: An AI-Powered Multi-Tool Mobile Application for Learning, Creativity, and Productivity
- Authors: <Author Name 1>, <Author Name 2>, <Author Name 3>
- Affiliations: <Department, Institution, City, Country>
- Corresponding Author: <Name, Email>

## Abstract

GenWise is a cross-platform Flutter application that bundles AI-assisted utilities into a single, cohesive experience. The app integrates Google Generative Language (Gemini) for text understanding and generation, Vertex AI Imagen 2 for prompt-based image generation, and Firebase for secure authentication and lightweight user data. GenWise targets students, teachers, creators, and developers through modular tools: Chat with PDF (document Q&A), Code Explainer, AI UI Designer (drag-and-drop design to production-ready HTML/CSS), Communication Practice (speech-to-text + TTS conversational practice), Resume Builder, Question Paper Generator, Knowledge Duel, and multiple creative/utility tools (Image-to-Story, Poster Generator, Lyrics/Recipe generators, Image Compress/Upscaler). The paper describes the system design, core algorithms for chunking and retrieval within documents, conversational flow for speech practice, and the modular architecture that allows rapid addition of new AI tools. We discuss security, limitations (e.g., online dependency, model variability), and future directions (RAG with vector stores, offline inference, analytics). GenWise demonstrates how diverse AI capabilities can be unified into a practical, production-ready mobile toolkit.

Keywords: Flutter, Firebase, Google Generative AI, Gemini, Vertex AI, Syncfusion PDF, Speech-to-Text, Text-to-Speech, ONNX Runtime, Mobile HCI, Education Technology, Productivity Tools

## 1. Introduction

Recent advances in large language models (LLMs) and cloud AI services have enabled powerful end-user applications beyond chat interfaces. However, many tools remain isolated and task-specific. GenWise addresses this gap by bundling complementary AI capabilities into a coherent multi-tool app that supports education (question paper generation, document Q&A, communication practice), development (code explainer, UI designer), and creative workflows (poster/lyrics/story generation, image tools) while maintaining a consistent, mobile-first experience.

GenWise is built with Flutter for cross-platform reach (Android, iOS, web, desktop) and uses Firebase for authentication and lightweight user data storage. Generative features are powered primarily by Google’s Gemini models and Vertex AI. The app emphasizes usability, modularity, and practical value through a curated set of tools configurable from a single home screen with search, role-based recommendations, and a common theme system.

## 2. Objectives

- Build a unified, modular AI toolkit with consistent UX for diverse tasks
- Provide on-device friendly experiences with cloud-backed AI
- Support students, educators, creators, and developers with role-based suggestions
- Implement robust, scalable integrations with Firebase and Google AI services
- Ensure extensibility to add future tools with minimal coupling

## 3. Related Work

Prior work includes single-purpose AI mobile assistants (document Q&A, code helpers, or design tools). GenWise combines several proven AI interactions into a single application with a shared design language and authentication layer. Compared to standalone tools, GenWise offers a broader scope with consistent navigation, state management (Provider), and a modular implementation that can be extended without disrupting existing features.

## 4. System Architecture

- Client: Flutter (Dart), Material 3 theming, Provider-based state via `ThemeProvider`. Cross-platform targets include Android, iOS, web, Windows, macOS, and Linux (platform folders present in the project).
- Backend/Services: Firebase Authentication and Cloud Firestore (for user roles and basic metadata). Google Generative Language API (Gemini) for text generation/explanation. Vertex AI Imagen 2 via service account for image generation.
- Data/Assets: Resume templates and preview images under `assets/`, fonts, app logo, and a Google Cloud service-account JSON.
- Security considerations: API key and service-account usage must be handled securely (see Section 9). In production, move secrets to a secure backend/proxy; avoid bundling sensitive keys in client apps.

High-level flow:

- App initialization: `main.dart` initializes Firebase via `firebase_options.dart`, sets up theme provider, and decides landing page based on `AuthService.onAuthStateChanged`.
- Home and navigation: `home_page.dart` renders a searchable grid of tools (`ToolCard`), role-based suggestions, and routes to individual tool pages. Sidebar provides profile, settings, security, and logout.
- Tools: Each tool is a self-contained page (e.g., `tool_chat_pdf.dart`, `tool_code_explainer.dart`, `tool_ui.dart`, `communication_practice_tool.dart`). Tools call `GeminiApi.callGemini(...)` as needed.

## 5. Module Overview

- Authentication and Profile

  - Files: `auth_service.dart`, `login_page.dart`, `register_page.dart`, `user_profile_page.dart`, `security_page.dart`
  - Features: Email/password auth, role storage in Firestore, password reset/change, account deletion, email verification.

- Home and Discovery

  - Files: `home_page.dart`, `tool_card.dart`
  - Features: Searchable tools grid, role-based recommendation carousel (Student/Teacher/Content Creator/General), animated UI.

- Chat with PDF (Document Q&A)

  - File: `tool_chat_pdf.dart`
  - Stack: Syncfusion PDF for text extraction, chunking with overlap, keyword index for fast retrieval, Gemini for answer synthesis, UI for chat with quick actions.

- Code Explainer

  - File: `tool_code_explainer.dart`
  - Approach: Smart deterministic chunking, JSON-structured snippet extraction via Gemini, dedupe/sort, overall summary synthesis, UI to browse code snippets with copy-to-clipboard.

- AI UI Designer

  - File: `tool_ui.dart`
  - Features: Drag-and-drop components, layers, grid/snap, precision mode, canvas lock, device templates, code generation via Gemini that outputs production-ready HTML/CSS per constraints.

- Communication Practice (Voice)

  - File: `communication_practice_tool.dart`
  - Stack: speech_to_text (ASR), flutter_tts (TTS), permission_handler, realtime conversation flow with retry/backoff, internet connectivity checks, multiple practice modes (Interview, Presentation, Casual, Business, Phone, Customer Service).

- Education and Creativity Tools

  - Files: `tool_question_paper.dart`, `tool_resume.dart`, `tool_knowledge_duel.dart`, `tool_image_story.dart`, `tool_poster.dart`, `tool_lyrics.dart`, `tool_recipe.dart`
  - Purpose: Domain-specific generators using LLM prompting and curated UX for outputs.

- Image Utilities
  - Files: `tool_image_compress.dart`, `tool_image_upscaler.dart`
  - Stack: `flutter_image_compress` for compression; `onnxruntime` and `flutter_super_resolution` for upscaling pipeline (platform permitting).

## 6. Key Algorithms and Techniques

- Document Chunking and Retrieval (Chat with PDF)

  - Paragraph/overlap chunking with adjustable size and ~200-character overlap to preserve context
  - Keyword index built from cleaned tokens (>=3 chars) to preselect candidate chunks
  - Multi-factor chunk scoring: exact/partial matches, proximity, density, positional prior, and normalization by length
  - Fallbacks when no strong match is found (keyword-based or first chunks)

- Code Explanation (Code Explainer)

  - Smart chunking by semantic boundaries (functions/classes/imports) with min/max lines and overlap
  - Strict JSON contract requested from model to return snippet list with line ranges
  - De-duplication by code+range key; global overall summary synthesized from top snippets
  - Client-side fallback segmentation if model JSON is invalid

- Conversation Flow (Communication Practice)

  - ASR input with confidence display, TTS output, and auto-restart microphone for real-time feel
  - Retry with exponential backoff for AI calls; graceful fallbacks (canned responses) on failures
  - Connection monitoring and UI indicators for network state

- UI-to-Code Generation (AI UI Designer)
  - Collects a formal specification of positioned components (type, tag, size, style, z-index, transforms)
  - Prompts the model to emit full HTML/CSS with accessibility, responsiveness, and modern CSS features

## 7. Implementation Details

- Language/Framework: Flutter (Dart), Material 3
- State Management: Provider (`theme_provider.dart`)
- Authentication/DB: Firebase Authentication and Cloud Firestore
- Generative AI: Google Generative Language API (Gemini 2.0 Flash)
- Image Generation: Vertex AI Imagen 2 (service-account flow)
- PDF and Documents: Syncfusion Flutter PDF, file_picker
- Speech/TTS: speech_to_text, flutter_tts
- Media/Files: image_picker, path_provider, open_file, printing, share_plus
- Local Storage: shared_preferences
- Image Processing: flutter_image_compress, onnxruntime, flutter_super_resolution
- Utilities/Crypto: jose, cryptography, pem, pointycastle, basic_utils
- Notable Assets: Resume DOCX templates and preview PNGs under `assets/`

Dependency versions are declared in `pubspec.yaml` (e.g., firebase_core ^4.0.0, firebase_auth ^6.0.1, cloud_firestore 6.0.0, provider ^6.1.1, etc.).

## 8. Results and Discussion

Evaluation is qualitative and feature-driven since the app integrates cloud models whose performance depends on external services. In testing, the document Q&A returns targeted answers for well-formed PDFs, code explanation produces structured snippet breakdowns for typical code files, the UI designer outputs usable HTML/CSS for moderate-size layouts, and the communication practice offers low-latency voice exchanges on stable networks. The modular design enabled adding multiple tools without affecting core flows. Known trade-offs include variability in LLM outputs, complexity of HTML/CSS fidelity for intricate designs, and PDF text extraction quality depending on source formatting.

## 9. Security, Privacy, and Ethics

- Secrets management: Avoid shipping raw API keys or service-account credentials in production builds. Use a secure backend/proxy and store tokens server-side. Rotate keys and enforce IAM least-privilege.
- Data handling: Minimize personal data; clearly disclose what is stored in Firestore. Provide account deletion and password management (implemented in `auth_service.dart`).
- Content safety: Add content filters/rulesets at the prompt layer for user-generated prompts where appropriate.
- Offline behavior: Some features require network connectivity; ensure robust error handling and clear UX feedback.

## 10. Limitations

- Network dependency for most AI features
- Model variability may affect determinism; prompt designs mitigate but do not eliminate this
- PDF quality and OCR limitations (the current approach relies on extractable text; scanned PDFs require OCR integration)
- On-device super-resolution and ONNX inference vary by platform support

## 11. Future Work

- Retrieval-Augmented Generation (RAG) with vector databases for multi-document chat
- Central proxy service for secure key management and rate limiting
- Offline/edge inference for selected models where feasible
- Advanced analytics and A/B testing of prompts and UX
- Expanded education tools (grading, rubric alignment) and creator workflows (brand kits, templates)

## 12. Conclusion

GenWise demonstrates how a single, cohesive Flutter application can integrate diverse AI capabilities to support education, productivity, and creativity. Through modular tool design, consistent UX, and robust integrations with Firebase and Google AI, GenWise is both a practical utility and a foundation for future AI features.

## Acknowledgments

We thank the open-source Flutter community and the maintainers of the packages used in this project. We also acknowledge Google Cloud/Vertex AI for the foundational model APIs leveraged in GenWise.

## References

- Flutter: https://flutter.dev/
- Firebase for Flutter: https://firebase.google.com/docs/flutter/setup
- Google Generative Language API (Gemini): https://ai.google.dev/
- Vertex AI Image Generation (Imagen 2): https://cloud.google.com/vertex-ai
- Syncfusion Flutter PDF: https://pub.dev/packages/syncfusion_flutter_pdf
- speech_to_text: https://pub.dev/packages/speech_to_text
- flutter_tts: https://pub.dev/packages/flutter_tts
- onnxruntime: https://pub.dev/packages/onnxruntime
- flutter_image_compress: https://pub.dev/packages/flutter_image_compress
- provider: https://pub.dev/packages/provider
- share_plus: https://pub.dev/packages/share_plus

## Appendix A. Build and Run (Developer Notes)

These notes help reviewers reproduce the app locally (Android target).

Prerequisites:

- Flutter SDK (stable), Android Studio/SDK, a configured emulator or device
- Firebase project configured; `firebase_options.dart` present (already in repo)

High-level steps:

1. `flutter pub get`
2. Ensure `android/app/google-services.json` and `firebase_options.dart` are valid for your Firebase project
3. Run on Android: `flutter run`

Note: For production, move API keys/service accounts to a secure backend. Replace placeholders and remove secrets from the client bundle before release.
