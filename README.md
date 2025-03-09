# Quiz App

A modern quiz application built with Flutter and Firebase. This app allows users to take quizzes on various programming topics and tracks their progress.

## Features

- User Authentication
  - Email/Password login and registration
  - Google Sign-in
  - Admin authentication

- Quiz Features
  - Multiple programming topics (TypeScript, Angular, Firebase, etc.)
  - Text and image-based questions
  - Multiple choice answers
  - Progress tracking
  - Detailed explanations for answers
  - Quiz history and statistics
  - Social sharing of results

- Admin Panel
  - Manage questions (Create, Read, Update, Delete)
  - Manage categories
  - Tag-based question organization
  - Question difficulty levels
  - Search and filter questions

## Getting Started

### Prerequisites

- Flutter SDK (latest version)
- Firebase account
- Android Studio / VS Code with Flutter extensions

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd quiz_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Create a new Firebase project
   - Enable Authentication (Email/Password and Google Sign-in)
   - Create a Cloud Firestore database
   - Download and add the `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files
   - Update Firebase configuration in the project

4. Run the app:
   ```bash
   flutter run
   ```

### Firebase Structure

The app uses the following Firestore collections:

- `questions`: Stores quiz questions
  ```json
  {
    "text": "Question text",
    "options": ["Option 1", "Option 2", "Option 3", "Option 4"],
    "correctOptionIndex": 0,
    "imageUrl": "optional_image_url",
    "explanation": "Answer explanation",
    "tags": ["tag1", "tag2"],
    "category": "category_name",
    "difficulty": 1
  }
  ```

- `categories`: Stores quiz categories
  ```json
  {
    "name": "Category name",
    "description": "Category description"
  }
  ```

- `results`: Stores quiz results
  ```json
  {
    "userId": "user_id",
    "category": "category_name",
    "score": 8,
    "totalQuestions": 10,
    "timeTaken": 300,
    "timestamp": "timestamp"
  }
  ```

## Development

### Project Structure

```
lib/
├── models/
│   └── question.dart
├── screens/
│   ├── auth/
│   │   └── auth_screen.dart
│   ├── quiz/
│   │   └── quiz_screen.dart
│   └── admin/
│       └── admin_panel_screen.dart
├── services/
│   └── quiz_service.dart
└── main.dart
```

## Updating and Deploying

### Local Development Updates

1. Make your code changes in the Flutter project
2. Test your changes locally:
   ```bash
   flutter run
   ```
3. For hot reload during development, press `r` in the terminal
4. For hot restart (when state needs to be reset), press `R` in the terminal

### Updating the Web Version

To update the web version of the app:

1. Build the web version:
   ```bash
   flutter build web
   ```
   This will generate updated files in the `build/web` directory.

2. Test the web build locally (optional):
   ```bash
   cd build/web
   python -m http.server 8000
   ```
   Then open http://localhost:8000 in your browser.

### Deploying to Firebase Hosting

1. Ensure you have Firebase CLI installed:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase (first time only):
   ```bash
   firebase login
   ```

3. Initialize Firebase in your project (first time only):
   ```bash
   firebase init hosting
   ```
   - Select your Firebase project
   - Specify `build/web` as your public directory
   - Configure as a single-page app (Yes)
   - Set up automatic builds and deploys with GitHub (optional)

4. Deploy to Firebase Hosting:
   ```bash
   firebase deploy --only hosting
   ```

5. Your updated app will be available at your Firebase Hosting URL:
   https://quiz-app-1741473333.web.app

### Updating Firebase Configuration

If you need to update Firebase services (Authentication, Firestore, etc.):

1. Make changes in the Firebase Console
2. If you've updated Firebase configuration files:
   - Replace `google-services.json` for Android
   - Replace `GoogleService-Info.plist` for iOS
   - Update web configuration in `index.html` if needed

### Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.