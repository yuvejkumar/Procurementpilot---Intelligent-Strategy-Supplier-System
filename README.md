# ProcurementPilot – Intelligent Strategy & Supplier System

ProcurementPilot is an intelligent procurement and supplier risk management system that helps organizations make better procurement decisions. The application uses Machine Learning to analyze supplier data, predict potential risks, and provide AI-powered insights.

## Local configuration

Copy `.env.example` to `.env`, fill in the Firebase and Gemini values, then run
or build with `flutter run --dart-define-from-file=.env` or
`flutter build web --dart-define-from-file=.env`. Pass the same flag to other
Flutter build commands. `.env` uses the JSON object format required by
`--dart-define-from-file` and is excluded from Git.

Firebase client configuration is public in a distributed app. Restrict its API
key in Google Cloud and enforce Firebase security rules. Do not ship a Gemini
key in a client build for production; use a backend proxy and rotate any key
that has already been committed or distributed.

## 🚀 Features

* Supplier risk prediction using Machine Learning
* AI-powered procurement insights
* Interactive analytics and data visualization
* Supplier performance analysis
* Secure Google Sign-In authentication
* Intelligent procurement decision support

## 🛠️ Tech Stack

**Frontend:** Flutter
**Authentication:** Google Sign-In
**Machine Learning:** Python, Scikit-learn
**AI:** Google Gemini AI
**Data Visualization:** FL Chart

## 📦 Installation

Clone the repository:

```bash
git clone https://github.com/yuvejkumar/Procurementpilot---Intelligent-Strategy-Supplier-System.git
```

Navigate to the project directory:

```bash
cd Procurementpilot---Intelligent-Strategy-Supplier-System
```

Install the dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

## 📱 Project Objective

The main objective of ProcurementPilot is to simplify procurement management by identifying potential supplier risks and providing intelligent insights that support better and more efficient business decisions.
