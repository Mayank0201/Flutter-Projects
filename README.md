# Flutter Projects 🚀

A growing collection of Flutter applications built to strengthen my understanding of cross-platform app development.  
This repository will be regularly updated with new projects as I continue learning Flutter, Dart, UI/UX, state management, and API integration.

Each project is organized in its own folder and includes screenshots, descriptions, features, and improvements made during development.

---

## 📌 Projects Included

### 1️⃣ Weather App – Realtime Weather Using OpenWeather API ⛅

**Description:**  
A clean, modern Flutter application that fetches real-time weather details from the OpenWeather API.  
The app begins with a city input screen, takes user input, and displays current temperature, weather conditions, humidity, wind speed, and more.  
It uses asynchronous API calls (`Future`, `await`), JSON decoding, and a structured model-service-UI architecture.

**Key Features**
- 🔹 City input screen (search any city)
- 🔹 Live temperature & weather description
- 🔹 API integration using `http` package
- 🔹 Clean UI using Material widgets
- 🔹 Dynamic weather info loaded from model
- 🔹 Refresh button for fetching new data
- 🔹 Forecast section (UI ready for future API integration)
- 🔹 Error handling for invalid cities
- 🔹 Custom app icon (via `flutter_launcher_icons`)

**Architecture Used**
- `weather_model.dart` → Converts JSON into Dart objects  
- `weather_service.dart` → Handles API calls  
- `weather_page.dart` → UI  
- `city_input_page.dart` → Input screen

**Tech Stack**
- Flutter  
- Dart  
- OpenWeather API  
- HTTP networking  
- JSON parsing  
- Material Design

**Future Improvements**
- 🔸 Add a 3-hour interval forecast view  
- 🔸 Add icons based on weather type  
- 🔸 Add caching for faster loads  
- 🔸 Add geolocation weather (current city)

---

## 🔧 How to Run Any Project
2
flutter pub get
flutter run

To run on a specific device:

flutter run -d chrome
flutter run -d emulator-5554
flutter run -d windows

## 📝 About This Repository

This repo documents my journey into Flutter app development, covering:

- 🎨 UI layouts and widget structure  
- 🔄 State management fundamentals  
- 🌐 API handling & JSON parsing  
- 📱 Real-device testing & debugging  
- 🧩 Android/iOS optimization techniques  
- 📦 Using and integrating external packages  
- 🏗️ Project architecture & clean code practices
  
Every project is intentionally built to learn one new concept at a time.
