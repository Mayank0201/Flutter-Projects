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
```bash 
flutter pub get
flutter run
```

To run on a specific device:
```bash
flutter run -d chrome
flutter run -d emulator-5554
flutter run -d windows
```


### 2️⃣ CineTracker – Movie Search & Wishlist App (OMDb API)

**Description:**  
CineTracker is a Flutter-based movie discovery application that allows users to search for movies, view detailed information, and manage a personal wishlist.  
The app follows a multi-screen flow with search, results, and details pages, using real-time data fetched from the OMDb API.  
It is designed with scalability in mind, with plans to integrate local database storage for wishlist persistence.

**Key Features**
- 🔹 Movie search with multiple results (search-based API)
- 🔹 Dedicated results screen displaying all matching movies
- 🔹 Detailed movie page with plot, genre, cast, runtime, release date, and IMDb rating
- 🔹 Clean UI with poster previews and readable layouts
- 🔹 Error handling for invalid searches and API failures
- 🔹 Environment-based API key management using `.env`
- 🔹 Modular architecture (model, service, UI separation)
- 🔹 Wishlist feature planned with local database integration
- 🔹 Bottom navigation structure (Home, Search, Wishlist)

**Architecture Used**
- `movie_model.dart` → Represents movie data (search + detailed views)  
- `movie_service.dart` → Handles OMDb API calls  
- `movie_search_page.dart` → Search input screen  
- `search_results_page.dart` → Displays multiple search results  
- `movie_details_page.dart` → Full movie details view  
- `wishlist_page.dart` → Planned database-backed wishlist screen  

**Tech Stack**
- Flutter  
- Dart  
- OMDb API  
- HTTP networking  
- JSON parsing  
- Material Design  
- dotenv for secure API keys  

**Planned Database Integration**
- Local storage using Hive / SQLite (to be added)
- Persist wishlist movies across app restarts
- Ability to add/remove movies from wishlist
- Store recently viewed or searched movies

**Future Improvements**
- 🔸 Wishlist persistence using local database  
- 🔸 Trending & popular movies section (Home tab)  
- 🔸 Grid-based movie layout (Netflix-style)  
- 🔸 Poster Hero animations  
- 🔸 Genre-based recommendations  
- 🔸 Migration to TMDB API for richer metadata  



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
