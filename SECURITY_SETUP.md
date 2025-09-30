# 🔐 Security Setup Instructions

This project contains template files for sensitive configuration. Follow these steps to set up your development environment securely:

## 📋 Required Setup Steps

### 1. Copy Template Files

Copy all `.template` files and remove the `.template` extension:

```bash
# Environment file
cp agenda.env.template agenda.env

# Configuration file
cp lib/config.dart.template lib/config.dart

# Firebase configuration
cp android/app/google-services.json.template android/app/google-services.json
cp lib/firebase_options.dart.template lib/firebase_options.dart

# Local properties
cp android/local.properties.template android/local.properties
```

### 2. Update Configuration Files

#### `agenda.env`

- Replace `YOUR_MAPBOX_ACCESS_TOKEN_HERE` with your actual Mapbox token
- Get token from: https://account.mapbox.com/access-tokens/

#### `lib/config.dart`

- Replace `YOUR_MAPBOX_ACCESS_TOKEN_HERE` with your Mapbox token
- Replace `YOUR_OPENROUTESERVICE_API_KEY_HERE` with your OpenRouteService API key
- Get OpenRouteService key from: https://openrouteservice.org/dev/#/signup

#### Firebase Files

- Download `google-services.json` from Firebase Console → Project Settings → General → Your apps
- Run `flutterfire configure` to generate `firebase_options.dart`
- Or manually update the template with your Firebase project values

#### `android/local.properties`

- Update paths to match your local Android SDK and Flutter installation
- Windows example: `C:\\Users\\YourUsername\\AppData\\Local\\Android\\sdk`
- macOS/Linux example: `/Users/YourUsername/Library/Android/sdk`

## ⚠️ Important Security Notes

- **NEVER** commit the actual configuration files (without `.template` extension)
- All sensitive files are already added to `.gitignore`
- Template files are safe to commit and share
- Keep your API keys and tokens secure and private

## 🚫 Files to NEVER Commit

The following files contain sensitive data and should never be pushed to version control:

- `agenda.env`
- `lib/config.dart`
- `android/app/google-services.json`
- `lib/firebase_options.dart`
- `android/local.properties`

These files are automatically ignored by `.gitignore`.

## 🔄 For New Team Members

1. Clone the repository
2. Follow the setup steps above
3. Ask team lead for actual API keys and configuration values
4. Copy template files and update with real values

## 📱 API Keys Required

- **Mapbox Access Token**: For map functionality
- **OpenRouteService API Key**: For routing services
- **Firebase Configuration**: For authentication and database
- **Local SDK Paths**: For Android development
